extends CharacterBody3D

@export var run_speed: float = 3.5
@export var health: int = 5
@export var score_value: int = 100
@export var attack_distance: float = 2.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.1

@export_group("Vision y Deteccion")
@export var detection_distance: float = 15.0
@export var detection_angle_degrees: float = 110.0

@export_group("Sonidos (Audio Streams)")
@export var sound_screech: AudioStream
@export var sound_attack: AudioStream
@export var sound_dying_1: AudioStream
@export var sound_dying_2: AudioStream
@export var sound_running: AudioStream

@onready var animation_player: AnimationPlayer = get_node_or_null("zombie_model/AnimationPlayer")
@onready var ray_cast: RayCast3D = get_node_or_null("RayCast3D")
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")
@onready var run_audio_player: AudioStreamPlayer3D = get_node_or_null("RunAudioPlayer") # Nodo dedicado para el sonido de correr

var target_node: Node3D = null
var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_player_detected: bool = false
var ultimo_jugador_que_disparo: String = "1"

func _ready() -> void:
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer")
		
	if ray_cast == null:
		ray_cast = get_node_or_null("RayCast3D")
		
	if audio_player == null:
		audio_player = get_node_or_null("AudioStreamPlayer3D")
		
	if run_audio_player == null:
		run_audio_player = get_node_or_null("RunAudioPlayer")
		
	target_node = get_viewport().get_camera_3d()
	play_animation("idle")
	
	# Sonido de grito inicial (solo una vez al iniciar)
	if sound_screech and audio_player:
		audio_player.stream = sound_screech
		audio_player.play()

func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	if target_node == null:
		target_node = get_viewport().get_camera_3d()
		return

	var target_position = target_node.global_transform.origin
	var distance = global_transform.origin.distance_to(target_position)

	# 1. COMPROBAR SI DETECTA AL JUGADOR
	if not is_player_detected:
		if distance <= detection_distance:
			var to_player = (target_position - global_transform.origin)
			to_player.y = 0.0
			to_player = to_player.normalized()
			
			var zombie_forward = -global_transform.basis.z
			zombie_forward.y = 0.0
			zombie_forward.normalized()
			
			var dot_prod = zombie_forward.dot(to_player)
			var angle_limit = cos(deg_to_rad(detection_angle_degrees / 2.0))
			
			if dot_prod >= angle_limit:
				if ray_cast:
					ray_cast.target_position = to_target_local(target_position)
					ray_cast.force_raycast_update()
					
					if not ray_cast.is_colliding() or ray_cast.get_collider() == target_node:
						is_player_detected = true
				else:
					is_player_detected = true

	# 2. SI NO HA SIDO DETECTADO: ESTÁTICO EN IDLE
	if not is_player_detected:
		velocity = Vector3.ZERO
		stop_running_sound()
		play_animation("idle")
		return

	# 3. SI YA FUE DETECTADO: CORRER O ATACAR
	if distance > attack_distance:
		is_attacking = false
		var direction = (target_position - global_transform.origin).normalized()
		direction.y = 0.0
		
		if direction.length() > 0.0:
			look_at(global_transform.origin + direction, Vector3.UP)
		
		velocity = direction * run_speed
		move_and_slide()
		play_running_sound()
		play_animation("run")
	else:
		velocity = Vector3.ZERO
		stop_running_sound()
		if can_attack:
			trigger_attack()

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

# MÉTODOS DE COMPATIBILIDAD Y DAÑO

func recibir_disparo(jugador_id: String) -> void:
	if jugador_id != "":
		ultimo_jugador_que_disparo = jugador_id
	recibir_dano(1)

func recibir_dano(cantidad: int) -> void:
	take_damage(cantidad)

func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	is_player_detected = true
	health -= amount
	
	if health <= 0:
		die()
	else:
		play_reaction_hit()

func play_reaction_hit() -> void:
	stop_running_sound()
	play_animation("reaction_hit")
	await get_tree().create_timer(0.3).timeout
	if not is_dead and not is_attacking:
		play_animation("run")

func trigger_attack() -> void:
	is_attacking = true
	can_attack = false
	stop_running_sound()
	play_animation("attack")
	
	# Sonido de ataque
	if sound_attack and audio_player:
		audio_player.stream = sound_attack
		audio_player.play()
	
	# Espera a que termine la animación completa antes de descontar vida
	if animation_player and animation_player.has_animation("attack"):
		await animation_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout

	if is_dead:
		return

	if get_node_or_null("/root/GameManager"):
		var gm = GameManager
		var nueva_salud_p1 = max(0, gm.p1_health - attack_damage)
		gm.update_player_health(1, nueva_salud_p1)
		if gm.player_count >= 2:
			var nueva_salud_p2 = max(0, gm.p2_health - attack_damage)
			gm.update_player_health(2, nueva_salud_p2)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	is_attacking = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	stop_running_sound()
	
	# Desactivar la colisión del zombie para que los jugadores o disparos lo atraviesen y no estorbe
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = true
		
	# Selección aleatoria entre los dos sonidos de muerte
	if audio_player:
		var elegir_dying_2 = randf() < 0.5 # 50% de probabilidad
		if elegir_dying_2 and sound_dying_2:
			audio_player.stream = sound_dying_2
			audio_player.play()
		elif sound_dying_1:
			audio_player.stream = sound_dying_1
			audio_player.play()
	
	# Sumar puntos / kills
	if get_node_or_null("/root/GameManager"):
		GameManager.add_kill(ultimo_jugador_que_disparo, score_value)
		
	# Reproducir animación de muerte y esperar a que termine
	play_animation("death")
	if animation_player and animation_player.has_animation("death"):
		await animation_player.animation_finished
		
	# para que el cuerpo se quede permanentemente tirado en el suelo sin gastar recursos de código.
	set_physics_process(false)

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
