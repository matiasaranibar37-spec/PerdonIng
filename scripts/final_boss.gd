extends CharacterBody3D

@export_group("Estadisticas del Jefe")
@export var max_health: int = 50
@export var phase_2_health: int = 75
@export var run_speed: float = 4.0
@export var attack_distance: float = 3.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 1.2
@export var score_value: int = 1000

@export_group("Vision y Deteccion")
@export var detection_distance: float = 20.0
@export var detection_angle_degrees: float = 120.0

@export_group("Sonidos del Jefe")
@export var sound_screech: AudioStream
@export var sound_attack: AudioStream
@export var sound_dying: AudioStream
@export var sound_running: AudioStream

@onready var animation_player: AnimationPlayer = get_node_or_null("Zombie_Boss/AnimationPlayer")
@onready var ray_cast: RayCast3D = get_node_or_null("RayCast3D")
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")
@onready var run_audio_player: AudioStreamPlayer3D = get_node_or_null("RunAudioPlayer")

var health: int = 0
var target_node: Node3D = null
var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_player_detected: bool = false
var is_screaming: bool = false
var has_revived: bool = false
var ultimo_jugador_que_disparo: String = "1"

func _ready() -> void:
	health = max_health
	
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer")
	if ray_cast == null:
		ray_cast = get_node_or_null("RayCast3D")
	if audio_player == null:
		audio_player = get_node_or_null("AudioStreamPlayer3D")
	if run_audio_player == null:
		run_audio_player = get_node_or_null("RunAudioPlayer")
		
	target_node = get_viewport().get_camera_3d()
	play_animation("idleBoss")

func _physics_process(_delta: float) -> void:
	if is_dead or is_screaming:
		return

	if target_node == null:
		target_node = get_viewport().get_camera_3d()
		return

	var es_nivel_tres: bool = true 
	if get_node_or_null("/root/GameManager"):
		# es_nivel_tres = (GameManager.current_level == 3)
		pass

	if not es_nivel_tres:
		velocity = Vector3.ZERO
		play_animation("idleBoss")
		return

	var target_position = target_node.global_transform.origin
	var distance = global_transform.origin.distance_to(target_position)

	# 1. DETECCIÓN
	if not is_player_detected:
		if distance <= detection_distance:
			var to_player = (target_position - global_transform.origin)
			to_player.y = 0.0
			to_player = to_player.normalized()
			
			var boss_forward = -global_transform.basis.z
			boss_forward.y = 0.0
			boss_forward.normalized()
			
			var dot_prod = boss_forward.dot(to_player)
			var angle_limit = cos(deg_to_rad(detection_angle_degrees / 2.0))
			
			if dot_prod >= angle_limit:
				if ray_cast:
					ray_cast.target_position = to_target_local(target_position)
					ray_cast.force_raycast_update()
					
					if not ray_cast.is_colliding() or ray_cast.get_collider() == target_node:
						trigger_boss_screech()
				else:
					trigger_boss_screech()

	if not is_player_detected:
		velocity = Vector3.ZERO
		stop_running_sound()
		play_animation("idleBoss")
		return

	# 2. PERSECUCIÓN O ATAQUE
	if distance > attack_distance:
		is_attacking = false
		var direction = (target_position - global_transform.origin).normalized()
		direction.y = 0.0
		
		if direction.length() > 0.0:
			look_at(global_transform.origin + direction, Vector3.UP)
		
		velocity = direction * run_speed
		move_and_slide()
		play_running_sound()
		play_animation("runBoss")
	else:
		velocity = Vector3.ZERO
		stop_running_sound()
		if can_attack:
			trigger_attack()

# GRITO INICIAL Y ACTIVACIÓN DE LA BARRA EN PANTALLA
func trigger_boss_screech() -> void:
	is_screaming = true
	is_player_detected = true
	velocity = Vector3.ZERO
	stop_running_sound()
	
	# Mostrar y actualizar la barra de vida en pantalla al iniciar el combate
	mostrar_y_actualizar_barra_hud(health, max_health)
	
	play_animation("screamBoss")
	
	if sound_screech and audio_player:
		audio_player.stream = sound_screech
		audio_player.play()
		
	if animation_player and animation_player.has_animation("screamBoss"):
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(1.5).timeout
		
	is_screaming = false

func play_running_sound() -> void:
	if sound_running and run_audio_player:
		if run_audio_player.stream != sound_running:
			run_audio_player.stream = sound_running
		if not run_audio_player.playing:
			run_audio_player.play()

func stop_running_sound() -> void:
	if run_audio_player and run_audio_player.playing:
		run_audio_player.stop()

func to_target_local(global_pos: Vector3) -> Vector3:
	return ray_cast.to_local(global_pos)

# --- SISTEMA DE DAÑO Y HUD ---

func recibir_disparo(jugador_id: String) -> void:
	if jugador_id != "":
		ultimo_jugador_que_disparo = jugador_id
	recibir_dano(1)

func recibir_dano(cantidad: int) -> void:
	if is_dead or is_screaming:
		return
		
	health -= cantidad
	mostrar_y_actualizar_barra_hud(health, phase_2_health if has_revived else max_health)
	print("¡Jefe impactado! Vida restante: ", health)
	
	if health <= 0:
		if not has_revived:
			trigger_revive_sequence()
		else:
			die()

# Función para comunicarse con el HUD dentro de ui y actualizar la barra en pantalla
func mostrar_y_actualizar_barra_hud(vida_actual: int, vida_maxima: int) -> void:
	var hud = get_tree().current_scene.get_node_or_null("ui/HUD")
	if hud:
		var boss_bar = hud.get_node_or_null("BossHealthBar")
		if boss_bar:
			boss_bar.visible = true # Lo hace visible cuando empieza la pelea o revive
			boss_bar.max_value = vida_maxima
			boss_bar.value = vida_actual

func trigger_revive_sequence() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	stop_running_sound()
	
	# Al revivir (ocultar temporalmente):
	var hud = get_tree().current_scene.get_node_or_null("ui/HUD")
	if hud and hud.has_node("BossHealthBar"):
		hud.get_node("BossHealthBar").visible = false
		
	if sound_dying and audio_player:
		audio_player.stream = sound_dying
		audio_player.play()
		
	print("¡El jefe ha caído... pero se está levantando de nuevo!")
	play_animation("deathBoss")
	
	if animation_player and animation_player.has_animation("deathBoss"):
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(2.0).timeout
		
	has_revived = true
	is_dead = false
	health = phase_2_health
	
	# ¡Vuelve a gritar (screamBoss) y muestra la barra con la nueva vida de la Fase 2!
	trigger_boss_screech()

func trigger_attack() -> void:
	is_attacking = true
	can_attack = false
	stop_running_sound()
	play_animation("attackBoss")
	
	if sound_attack and audio_player:
		audio_player.stream = sound_attack
		audio_player.play()
		
	if animation_player and animation_player.has_animation("attackBoss"):
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout

	if is_dead:
		return

	if get_node_or_null("/root/GameManager"):
		var gm = GameManager
		var nueva_salud_p1 = max(0, gm.p1_health - attack_damage)
		var nueva_salud_p2 = max(0, gm.p2_health - attack_damage)
		
		gm.update_player_health(1, nueva_salud_p1)
		gm.update_player_health(2, nueva_salud_p2)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	is_attacking = false

func die() -> void:
	if is_dead and has_revived:
		return
	is_dead = true
	velocity = Vector3.ZERO
	stop_running_sound()
	
	# Al morir definitivamente:
	var hud = get_tree().current_scene.get_node_or_null("ui/HUD")
	if hud and hud.has_node("BossHealthBar"):
		hud.get_node("BossHealthBar").visible = false
	
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = true
		
	if sound_dying and audio_player:
		audio_player.stream = sound_dying
		audio_player.play()
		
	if get_node_or_null("/root/GameManager"):
		GameManager.add_kill(ultimo_jugador_que_disparo, score_value)
		print("¡JEFE FINAL DERROTADO DEFINITIVAMENTE!")
		
	play_animation("deathBoss")
	if animation_player and animation_player.has_animation("deathBoss"):
		await animation_player.animation_finished
		
	set_physics_process(false)

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
