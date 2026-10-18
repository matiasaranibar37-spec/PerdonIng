extends CharacterBody3D

@export var speed: float = 3.0
@export var health: int = 2
@export var score_value: int = 100
@export var attack_distance: float = 2.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5

@onready var animation_player: AnimationPlayer = get_node_or_null("zombie_model/AnimationPlayer")

var target_node: Node3D = null
var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true

func _ready() -> void:
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer")
		
	# Busca automáticamente la cámara 3D activa en la escena actual
	target_node = get_viewport().get_camera_3d()
	
	play_animation("idle")

func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	# Si la cámara cambió o aún no la encuentra, intenta volver a obtenerla
	if target_node == null:
		target_node = get_viewport().get_camera_3d()
		return

	var target_position = target_node.global_transform.origin
	var distance = global_transform.origin.distance_to(target_position)

	# Si está lejos, persigue a la cámara
	if distance > attack_distance:
		is_attacking = false
		var direction = (target_position - global_transform.origin).normalized()
		direction.y = 0.0 # Mantiene el movimiento en el plano horizontal
		
		if direction.length() > 0.0:
			look_at(global_transform.origin + direction, Vector3.UP)
		
		velocity = direction * speed
		move_and_slide()
		play_animation("walk")
	else:
		# Al llegar al rango de ataque ataca
		velocity = Vector3.ZERO
		if can_attack:
			trigger_attack()

# MÉTODOS DE COMPATIBILIDAD CON MOBILEPLAYER 

func recibir_disparo(_jugador_id: String) -> void:
	recibir_dano(1)

func recibir_dano(cantidad: int) -> void:
	take_damage(cantidad)

#SALUD, ANIMACIONES Y DAÑO

func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	health -= amount
	print("Zombie impactado. Vida restante: ", health)
	
	if health <= 0:
		die()
	else:
		play_reaction_hit()

func play_reaction_hit() -> void:
	play_animation("reaction_hit")
	# Breve pausa por impacto antes de continuar persiguiendo
	await get_tree().create_timer(0.3).timeout
	if not is_dead and not is_attacking:
		play_animation("walk")

func trigger_attack() -> void:
	is_attacking = true
	can_attack = false
	play_animation("attack")
	
	# Hace daño a la salud de los jugadores 
	if get_node_or_null("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.p1_health = max(0, gm.p1_health - attack_damage)
		gm.p2_health = max(0, gm.p2_health - attack_damage)
		
		# Actualiza el HUD 
		var hud = get_tree().current_scene.get_node_or_null("HUD")
		if hud and hud.has_method("actualizar_hud"):
			hud.actualizar_hud()
			
	print("¡El zombie atacó a los jugadores! Daño: ", attack_damage)
	
	# Cooldown de ataque
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	is_attacking = false

func die() -> void:
	if is_dead:
		return
		
	is_dead = true
	velocity = Vector3.ZERO
	
	# Suma puntos 
	if get_node_or_null("/root/GameManager"):
		GameManager.add_score(score_value)
		
	play_animation("death")
	
	if animation_player and animation_player.has_animation("death"):
		await animation_player.animation_finished
		
	queue_free()

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
