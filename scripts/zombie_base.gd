extends CharacterBody3D

## Se emite cuando el zombie muere (la usan el ascensor y el nivel 2)
signal died

@export var run_speed: float = 3.5
@export var health: int = 5
@export var score_value: int = 100              # Puntos normales por muerte al cuerpo
@export var headshot_score_value: int = 200     # Puntos aumentados por tiro a la cabeza
@export var attack_distance: float = 2.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5

@export_group("Vision y Deteccion")
@export var detection_distance: float = 15.0
@export var detection_angle_degrees: float = 110.0

@export_group("Patrullaje")
## Si es true, mientras no haya detectado al jugador camina de un lado a otro en vez de quedarse quieto.
## (Desactivado por defecto: el nivel 2 lo activa desde level_2.gd)
@export var patrullar: bool = false
@export var walk_speed: float = 0.8
## Radio (m) alrededor de su punto de partida dentro del cual patrulla
@export var radio_patrulla: float = 3.0
## Pausa en idle (segundos, mínimo y máximo) al llegar a cada punto
@export var pausa_patrulla_min: float = 1.0
@export var pausa_patrulla_max: float = 3.0
## Si tarda más de esto en llegar a un punto (atascado contra un estante), elige otro
@export var tiempo_max_atasco: float = 4.0

@export_group("Sonidos (Audio Streams)")
@export var sound_screech: AudioStream
@export var sound_attack: AudioStream
@export var sound_dying_1: AudioStream
@export var sound_dying_2: AudioStream
@export var sound_running: AudioStream

@onready var animation_player: AnimationPlayer = get_node_or_null("zombie_model/AnimationPlayer")
@onready var ray_cast: RayCast3D = get_node_or_null("RayCast3D")
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")
@onready var run_audio_player: AudioStreamPlayer3D = get_node_or_null("RunAudioPlayer")

var target_node: Node3D = null
var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_player_detected: bool = false
var ultimo_jugador_que_disparo: String = "1"
# Si es false, el zombie no detecta al jugador por sí solo (camuflaje); solo ataca si le disparan o hay alerta
var detection_enabled: bool = true
var is_headshot: bool = false # Rastrea si murió por un tiro a la cabeza

# Patrullaje
var _home_position: Vector3 = Vector3.ZERO
var _patrulla_destino: Vector3 = Vector3.ZERO
var _patrulla_pausa_hasta: float = 0.0
var _patrulla_timer: float = 0.0

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
	
	# Patrullaje: punto de partida y primer destino. La pausa inicial es aleatoria para que
	# no todos arranquen a la vez.
	_home_position = global_position
	_elegir_destino_patrulla()
	_patrulla_pausa_hasta = Time.get_ticks_msec() / 1000.0 + randf_range(0.0, pausa_patrulla_max)
	
	if sound_screech and audio_player:
		audio_player.stream = sound_screech
		audio_player.play()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if target_node == null:
		target_node = get_viewport().get_camera_3d()
		return

	var target_position = target_node.global_transform.origin
	var distance = global_transform.origin.distance_to(target_position)

	if not is_player_detected and detection_enabled:
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
				if ray_cast:
					ray_cast.target_position = to_target_local(target_position)
					ray_cast.force_raycast_update()
					
					if not ray_cast.is_colliding() or ray_cast.get_collider() == target_node:
						is_player_detected = true
				else:
					is_player_detected = true

	if not is_player_detected:
		stop_running_sound()
		if patrullar:
			_patrullar(delta)
		else:
			velocity = Vector3.ZERO
			play_animation("idle")
		return

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

# --- PATRULLAJE ---

func _patrullar(delta: float) -> void:
	var ahora: float = Time.get_ticks_msec() / 1000.0
	
	# Pausa en idle entre un punto y otro
	if ahora < _patrulla_pausa_hasta:
		velocity = Vector3.ZERO
		play_animation("idle")
		return
	
	var hacia: Vector3 = _patrulla_destino - global_position
	hacia.y = 0.0
	_patrulla_timer += delta
	
	# Llegó, se atascó o chocó con algo: elige otro punto y descansa un rato
	if hacia.length() < 0.5 or _patrulla_timer > tiempo_max_atasco or is_on_wall():
		_elegir_destino_patrulla()
		_patrulla_pausa_hasta = ahora + randf_range(pausa_patrulla_min, pausa_patrulla_max)
		velocity = Vector3.ZERO
		play_animation("idle")
		return
	
	var direccion: Vector3 = hacia.normalized()
	look_at(global_position + direccion, Vector3.UP)
	velocity = direccion * walk_speed
	move_and_slide()
	play_animation("walk")

func _elegir_destino_patrulla() -> void:
	var offset := Vector3(randf_range(-radio_patrulla, radio_patrulla), 0.0, randf_range(-radio_patrulla, radio_patrulla))
	_patrulla_destino = _home_position + offset
	_patrulla_timer = 0.0

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

# --- MÉTODOS DE DISPAROS Y DAÑO ---

func recibir_disparo(jugador_id: String) -> void:
	if jugador_id != "":
		ultimo_jugador_que_disparo = jugador_id
	recibir_dano(1)

# NUEVA FUNCIÓN: Se ejecuta exclusivamente cuando le dan en la cabeza
func recibir_disparo_cabeza(jugador_id: String) -> void:
	if jugador_id != "":
		ultimo_jugador_que_disparo = jugador_id
	
	is_headshot = true
	print("¡TIRO A LA CABEZA! (HEADSHOT)")
	
	# Opcional: Un tiro a la cabeza los mata instantáneamente o les hace el doble de daño
	# Aquí hacemos que le quite toda la vida de golpe para que muera al instante de un headshot:
	recibir_dano(health) 

func recibir_dano(cantidad: int) -> void:
	take_damage(cantidad)

func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	is_player_detected = true
	# Avisa al nivel: un disparo a un zombie alerta a todos los demás
	get_tree().call_group("nivel_alerta", "zombie_disparado", self)
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
	
	if sound_attack and audio_player:
		audio_player.stream = sound_attack
		audio_player.play()
	
	if animation_player and animation_player.has_animation("attack"):
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
	if is_dead:
		return
	is_dead = true
	died.emit()
	velocity = Vector3.ZERO
	stop_running_sound()
	
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = true
		
	# Desactivar también el Area3D de la cabeza para que no siga recibiendo disparos una vez muerto
	var head_area = get_node_or_null("HeadArea")
	if head_area:
		head_area.monitoring = false
	
	if audio_player:
		var elegir_dying_2 = randf() < 0.5
		if elegir_dying_2 and sound_dying_2:
			audio_player.stream = sound_dying_2
			audio_player.play()
		elif sound_dying_1:
			audio_player.stream = sound_dying_1
			audio_player.play()
	
	# AQUí SE APLICA EL CAMBIO DE PUNTUACIÓN SEGÚN EL HEADSHOT
	if get_node_or_null("/root/GameManager"):
		var puntos_finales = headshot_score_value if is_headshot else score_value
		GameManager.add_kill(ultimo_jugador_que_disparo, puntos_finales)
		if is_headshot:
			print("¡Kill por HeadSHOT! Puntos otorgados: ", puntos_finales)
		
	play_animation("death")
	if animation_player and animation_player.has_animation("death"):
		await animation_player.animation_finished
		
	set_physics_process(false)

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
