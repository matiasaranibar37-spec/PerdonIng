extends CharacterBody3D

@export var speed: float = 3.0
@export var health: int = 2
@export var score_value: int = 100
@export var attack_distance: float = 2.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5

@export_group("Vision y Deteccion")
@export var detection_distance: float = 10.0 # Distancia máxima a la que detecta al jugador
@export var detection_angle_degrees: float = 90.0 # Ángulo de visión frontal 

@onready var animation_player: AnimationPlayer = get_node_or_null("zombie_model/AnimationPlayer")

var target_node: Node3D = null
var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_player_detected: bool = false # Estado de alerta del zombie
var ultimo_jugador_que_disparo: String = "1" # Guarda qué jugador (P1 o P2) le disparó

func _ready() -> void:
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer")
		
	target_node = get_viewport().get_camera_3d()
	play_animation("idle")

func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	if target_node == null:
		target_node = get_viewport().get_camera_3d()
		return

	var target_position = target_node.global_transform.origin
	var distance = global_transform.origin.distance_to(target_position)

	# 1. COMPROBAR SI ESTÁ EN EL RANGO Y DELANTE DEL ZOMBIE
	if not is_player_detected:
		if distance <= detection_distance:
			var to_player = (target_position - global_transform.origin)
			to_player.y = 0.0
			to_player = to_player.normalized()
			
			var zombie_forward = -global_transform.basis.z
			zombie_forward.y = 0.0
			zombie_forward = zombie_forward.normalized()
			
			var dot_prod = zombie_forward.dot(to_player)
			var angle_limit = cos(deg_to_rad(detection_angle_degrees / 2.0))
			
			if dot_prod >= angle_limit:
				is_player_detected = true
				print("¡Jugador detectado en el campo de visión!")

	# 2. SI NO HA SIDO DETECTADO, SE QUEDA EN IDLE
	if not is_player_detected:
		velocity = Vector3.ZERO
		play_animation("idle")
		return

	# 3. SI YA FUE DETECTADO, PERSIGUE O ATACA NORMALMENTE
	if distance > attack_distance:
		is_attacking = false
		var direction = (target_position - global_transform.origin).normalized()
		direction.y = 0.0
		
		if direction.length() > 0.0:
			look_at(global_transform.origin + direction, Vector3.UP)
		
		velocity = direction * speed
		move_and_slide()
		play_animation("walk")
	else:
		velocity = Vector3.ZERO
		if can_attack:
			trigger_attack()

# MÉTODOS DE COMPATIBILIDAD CON MOBILEPLAYER Y DISPAROS

func recibir_disparo(jugador_id: String) -> void:
	if jugador_id != "":
		ultimo_jugador_que_disparo = jugador_id
	recibir_dano(1)

func recibir_dano(cantidad: int) -> void:
	take_damage(cantidad)

func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	# Si le disparan desde fuera de su campo de visión, se activa automáticamente
	is_player_detected = true
	
	health -= amount
	print("Zombie impactado. Vida restante: ", health)
	
	if health <= 0:
		die()
	else:
		play_reaction_hit()

func play_reaction_hit() -> void:
	play_animation("reaction_hit")
	await get_tree().create_timer(0.3).timeout
	if not is_dead and not is_attacking:
		play_animation("walk")

func trigger_attack() -> void:
	is_attacking = true
	can_attack = false
	play_animation("attack")
	
	# Descontamos salud a través de las funciones globales de GameManager
	if get_node_or_null("/root/GameManager"):
		var gm = GameManager
		var nueva_salud_p1 = max(0, gm.p1_health - attack_damage)
		var nueva_salud_p2 = max(0, gm.p2_health - attack_damage)
		
		# Actualiza la salud en GameManager y notifica al HUD automáticamente
		gm.update_player_health(1, nueva_salud_p1)
		gm.update_player_health(2, nueva_salud_p2)
		print("¡El zombie atacó a los jugadores! Daño: ", attack_damage)

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	is_attacking = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	
	if get_node_or_null("/root/GameManager"):
		GameManager.add_kill(ultimo_jugador_que_disparo, score_value)
		
	play_animation("death")
	if animation_player and animation_player.has_animation("death"):
		await animation_player.animation_finished
	queue_free()

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
