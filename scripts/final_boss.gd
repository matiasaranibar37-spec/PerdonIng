extends CharacterBody3D
## Final Boss estilo "Drácula" de After Dark Arcade:
## - Se desliza de lado a lado manteniendo la distancia con la cámara.
## - Se detiene, avisa con un grito y se lanza contra la pantalla (embestida).
## - Disparar a sus puntos débiles interrumpe la embestida.

signal boss_defeated
signal health_changed(current: int, maximum: int)
signal attack_started
signal attack_connected
signal enraged

enum BossState { IN_CINEMATIC, STRAFE, PREPARE_ATTACK, CHARGE, RETREAT, STUNNED, DEAD }
var current_state: BossState = BossState.IN_CINEMATIC

@export_group("Estadísticas del Jefe")
## Un zombie normal tiene 5 de vida; el jefe tiene mucho más.
@export var max_health: int = 150
@export var body_hit_damage: int = 1
@export var weak_point_damage: int = 3
@export var attack_damage: int = 25
@export var score_value: int = 2000

@export_group("Movimiento lateral (deslizamiento)")
@export var strafe_speed: float = 4.5
## Cuántos metros se aleja a cada lado de su centro
@export var strafe_range: float = 4.5

@export_group("Distancia a la cámara")
@export var min_distance: float = 6.0
@export var max_distance: float = 15.0
@export var distance_adjust_speed: float = 2.0

@export_group("Embestida (ataque especial)")
@export var attack_interval_min: float = 4.0
@export var attack_interval_max: float = 7.0
## Tiempo que se queda quieto gritando antes de lanzarse (ventana para interrumpirlo)
@export var telegraph_time: float = 1.3
@export var charge_speed: float = 14.0
@export var retreat_speed: float = 9.0
## A qué distancia de la cámara "conecta" el golpe
@export var lunge_stop_distance: float = 1.6
@export var max_charge_time: float = 3.0
## Disparos al punto débil necesarios para cancelar el ataque
@export var hits_to_cancel: int = 3
## Daño total (cualquier parte) durante el ataque que también lo cancela
@export var damage_to_cancel: int = 12
@export var stun_time: float = 1.2

@export_group("Furia (poca vida)")
@export var enrage_health_ratio: float = 0.5
@export var enrage_speed_multiplier: float = 1.35
@export var enrage_interval_multiplier: float = 0.65

@export_group("Sonidos")
@export var scream_sound: AudioStream

@export_group("Referencias")
@export var camera_ref: Camera3D

@onready var anim_player: AnimationPlayer = get_node_or_null("Zombie_Boss/AnimationPlayer")
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")
@onready var attack_timer: Timer = get_node_or_null("AttackTimer")
@onready var health_bar_2d: ProgressBar = get_node_or_null("HealthBarViewport/HealthBar2D")

var health: int = 0
var cancel_hits_count: int = 0
var ultimo_jugador_que_disparo: String = "1"

var _center: Vector3                 # centro de la "arena" del jefe
var _lateral_offset: float = 0.0
var _lateral_dir: float = 1.0
var _charge_elapsed: float = 0.0
var _retreat_wait: float = 0.0
var _damage_in_attack: int = 0
var _attack_id: int = 0
var _enraged: bool = false


func _ready() -> void:
	health = max_health
	if health_bar_2d:
		health_bar_2d.max_value = max_health
		health_bar_2d.value = health
	if attack_timer:
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	if scream_sound == null and ResourceLoader.exists("res://assets/sounds/screem-finalBoss.mp3"):
		scream_sound = load("res://assets/sounds/screem-finalBoss.mp3")
	if anim_player and anim_player.has_animation("deathBoss"):
		anim_player.get_animation("deathBoss").loop_mode = Animation.LOOP_NONE
	play_animation("idleBoss")
	health_changed.emit(health, max_health)


# La llama la animación "start" del nivel (pista de método) cuando el jefe le grita al jugador
func play_scream() -> void:
	if current_state != BossState.IN_CINEMATIC:
		return
	play_animation("screamBoss")
	await get_tree().create_timer(3.8).timeout
	if current_state == BossState.IN_CINEMATIC:
		play_animation("idleBoss")


func start_boss_fight(cam: Camera3D = null) -> void:
	if cam:
		camera_ref = cam
	_center = global_position
	_lateral_offset = 0.0
	_lateral_dir = 1.0
	current_state = BossState.STRAFE
	play_animation("walkBoss")
	_schedule_next_attack()


func _get_camera() -> Camera3D:
	if is_instance_valid(camera_ref):
		return camera_ref
	return get_viewport().get_camera_3d()


func _physics_process(delta: float) -> void:
	if current_state == BossState.IN_CINEMATIC or current_state == BossState.DEAD:
		return
	var cam := _get_camera()
	if cam == null:
		return
	var cam_pos := cam.global_position

	_keep_distance(cam_pos, delta)

	match current_state:
		BossState.STRAFE:
			_handle_strafe(cam_pos, delta)
		BossState.CHARGE:
			_handle_charge(cam_pos, delta)
		BossState.RETREAT:
			_handle_retreat(cam_pos, delta)
		_:
			pass  # PREPARE_ATTACK y STUNNED: se queda quieto

	_face_camera(cam_pos)


func _face_camera(cam_pos: Vector3) -> void:
	var target := Vector3(cam_pos.x, global_position.y, cam_pos.z)
	if target.distance_to(global_position) > 0.05:
		look_at(target, Vector3.UP)
		rotate_object_local(Vector3.UP, PI) # Invierte la rotación si quedó mirando al revés


# --- DISTANCIA: si la cámara se aleja o se acerca demasiado, mueve el centro de la arena ---
func _keep_distance(cam_pos: Vector3, delta: float) -> void:
	var flat := Vector3(_center.x - cam_pos.x, 0.0, _center.z - cam_pos.z)
	var d := flat.length()
	if d < 0.01:
		return
	var wanted := clampf(d, min_distance, max_distance)
	if absf(wanted - d) > 0.01:
		var new_d := move_toward(d, wanted, distance_adjust_speed * delta)
		var n := flat.normalized() * new_d
		_center.x = cam_pos.x + n.x
		_center.z = cam_pos.z + n.z


# Eje "izquierda-derecha" tal como lo ve la cámara (se recalcula porque la cámara orbita)
func _lateral_axis(cam_pos: Vector3) -> Vector3:
	var fwd := Vector3(_center.x - cam_pos.x, 0.0, _center.z - cam_pos.z)
	if fwd.length() < 0.01:
		return Vector3.RIGHT
	return fwd.normalized().cross(Vector3.UP).normalized()


func _strafe_position(cam_pos: Vector3) -> Vector3:
	return _center + _lateral_axis(cam_pos) * _lateral_offset


func _speed_mult() -> float:
	return enrage_speed_multiplier if _enraged else 1.0


# --- MOVIMIENTO LATERAL ---
func _handle_strafe(cam_pos: Vector3, delta: float) -> void:
	var limit := _lateral_dir * strafe_range
	_lateral_offset = move_toward(_lateral_offset, limit, strafe_speed * _speed_mult() * delta)
	if is_equal_approx(_lateral_offset, limit):
		_lateral_dir *= -1.0
	var desired := _strafe_position(cam_pos)
	global_position = global_position.lerp(desired, 1.0 - exp(-10.0 * delta))


# --- ATAQUE ESPECIAL: aviso -> embestida -> retirada ---
func _schedule_next_attack() -> void:
	if attack_timer == null:
		return
	var t := randf_range(attack_interval_min, attack_interval_max)
	if _enraged:
		t *= enrage_interval_multiplier
	attack_timer.start(t)


func _on_attack_timer_timeout() -> void:
	if current_state == BossState.STRAFE:
		_start_attack()
	elif current_state != BossState.DEAD:
		_schedule_next_attack()


func _start_attack() -> void:
	current_state = BossState.PREPARE_ATTACK
	cancel_hits_count = 0
	_damage_in_attack = 0
	_attack_id += 1
	var my_id := _attack_id
	play_animation("screamBoss")
	if audio_player and scream_sound:
		audio_player.stream = scream_sound
		audio_player.play()
	attack_started.emit()

	await get_tree().create_timer(telegraph_time).timeout
	if my_id == _attack_id and current_state == BossState.PREPARE_ATTACK:
		_charge_elapsed = 0.0
		current_state = BossState.CHARGE
		play_animation("runBoss")


func _handle_charge(cam_pos: Vector3, delta: float) -> void:
	_charge_elapsed += delta
	var to_cam := Vector3(cam_pos.x - global_position.x, 0.0, cam_pos.z - global_position.z)
	var dist := to_cam.length()
	if dist <= lunge_stop_distance:
		_connect_attack()
		return
	if _charge_elapsed >= max_charge_time:
		_begin_retreat(0.0)  # se atascó: se retira sin hacer daño
		return
	var step := minf(charge_speed * _speed_mult() * delta, dist - lunge_stop_distance)
	global_position += to_cam.normalized() * step


func _connect_attack() -> void:
	play_animation("attackBoss")
	_aplicar_dano_jugadores()
	attack_connected.emit()
	_begin_retreat(0.45)


func _begin_retreat(wait: float) -> void:
	_retreat_wait = wait
	current_state = BossState.RETREAT


func _handle_retreat(cam_pos: Vector3, delta: float) -> void:
	if _retreat_wait > 0.0:
		_retreat_wait -= delta
		return
	play_animation("runBoss")
	var target := _strafe_position(cam_pos)
	global_position = global_position.move_toward(target, retreat_speed * _speed_mult() * delta)
	if global_position.distance_to(target) < 0.6:
		current_state = BossState.STRAFE
		play_animation("walkBoss")
		_schedule_next_attack()


func _stun() -> void:
	current_state = BossState.STUNNED
	_attack_id += 1
	play_animation("idleBoss")
	await get_tree().create_timer(stun_time).timeout
	if current_state == BossState.STUNNED:
		_begin_retreat(0.0)


# --- RECIBIR DAÑO ---
func _set_shooter(jugador_id: String) -> void:
	if jugador_id != "":
		ultimo_jugador_que_disparo = jugador_id


# Disparo al cuerpo (el jugador llama a este método por defecto)
func recibir_disparo(jugador_id: String) -> void:
	_set_shooter(jugador_id)
	_aplicar_golpe(body_hit_damage, false)


func recibir_disparo_punto_debil(jugador_id: String) -> void:
	_set_shooter(jugador_id)
	_aplicar_golpe(weak_point_damage, true)


# player.gd llama a este método (si existe) pasando el punto exacto del impacto.
# Así el punto débil funciona aunque el rayo choque primero con la cápsula del cuerpo.
func recibir_disparo_en_punto(jugador_id: String, punto: Vector3) -> void:
	if _punto_en_zona_debil(punto):
		recibir_disparo_punto_debil(jugador_id)
	else:
		recibir_disparo(jugador_id)


func recibir_dano(cantidad: int) -> void:
	_aplicar_golpe(cantidad, false)


func _punto_en_zona_debil(punto: Vector3) -> bool:
	var areas := get_node_or_null("AttacksAreas")
	if areas == null:
		return false
	for area in areas.get_children():
		for child in area.get_children():
			if child is CollisionShape3D and child.shape is SphereShape3D:
				var s: Vector3 = child.global_transform.basis.get_scale()
				var radio: float = child.shape.radius * maxf(maxf(s.x, s.y), s.z)
				if punto.distance_to(child.global_position) <= radio * 1.3:
					return true
	return false


func _aplicar_golpe(cantidad: int, es_punto_debil: bool) -> void:
	if health <= 0 or current_state == BossState.DEAD or current_state == BossState.IN_CINEMATIC:
		return
	health = maxi(health - cantidad, 0)
	if health_bar_2d:
		health_bar_2d.value = health
	health_changed.emit(health, max_health)

	if not _enraged and health > 0 and health <= int(max_health * enrage_health_ratio):
		_enraged = true
		enraged.emit()

	if health <= 0:
		die()
		return

	# Interrumpir el ataque especial
	if current_state == BossState.PREPARE_ATTACK or current_state == BossState.CHARGE:
		if es_punto_debil:
			cancel_hits_count += 1
		_damage_in_attack += cantidad
		if cancel_hits_count >= hits_to_cancel or _damage_in_attack >= damage_to_cancel:
			_stun()


func _aplicar_dano_jugadores() -> void:
	if get_node_or_null("/root/GameManager") == null:
		return
	GameManager.update_player_health(1, maxi(0, GameManager.p1_health - attack_damage))
	if GameManager.player_count >= 2:
		GameManager.update_player_health(2, maxi(0, GameManager.p2_health - attack_damage))


func die() -> void:
	current_state = BossState.DEAD
	if attack_timer:
		attack_timer.stop()
	# Que los disparos ya no lo toquen
	collision_layer = 0
	collision_mask = 0
	var areas := get_node_or_null("AttacksAreas")
	if areas:
		for area in areas.get_children():
			if area is Area3D:
				area.collision_layer = 0
	play_animation("deathBoss")
	boss_defeated.emit()

	if get_node_or_null("/root/GameManager"):
		GameManager.add_kill(ultimo_jugador_que_disparo, score_value)

	var espera := 3.0
	if anim_player and anim_player.has_animation("deathBoss"):
		espera = anim_player.get_animation("deathBoss").length + 2.0
	await get_tree().create_timer(espera).timeout
	queue_free()


func play_animation(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)
