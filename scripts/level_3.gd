extends Node3D
## Nivel 3: cinemática -> conseguir la pistola en la cafetería -> salir -> pelea contra el Final Boss.

signal rail_arrived

enum Fase { CINEMATICA, ESPERANDO_ARMA, SALIENDO_CAFETERIA, PELEA, VICTORIA }

@export_group("Escenas y Referencias")
@export var zombie_minion_scene: PackedScene
@export var camera_ref: Camera3D
@export var boss_ref: CharacterBody3D
## Opcional: Marker3D en la cafetería donde aparece la pistola
@export var weapon_spawn_marker: Marker3D
@export_file("*.tscn") var next_scene_path: String = "res://scenes/main_menu.tscn"

@export_group("Configuración de Cinemática")
@export var start_cinematic_name: String = "start"
@export var altura_camara: float = 1.6

@export_group("Recorrido (progreso del riel en metros)")
## Dónde termina la cafetería y empieza el patio (el jefe se activa aquí)
@export var patio_entrance_progress: float = 75.0
@export var exit_cafeteria_speed: float = 3.0
## Paradas de la cámara durante la pelea (el riel rodea al jefe)
@export var fight_stops: Array[float] = [84.6, 103.4, 124.4, 131.1]
## Velocidad lenta entre paradas (efecto "camina hacia atrás" sin dejar de ver al jefe)
@export var fight_walk_speed: float = 1.3
@export var stop_wait_time: float = 12.0

@export_group("Zombies de apoyo (los 'murciélagos' de After Dark Arcade)")
## Zombies que aparecen de golpe al llegar a cada parada
@export var wave_sizes: Array[int] = [2, 3, 3, 4]
@export var max_minions_alive: int = 4
@export var minion_interval: float = 9.0

@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var spawn_timer: Timer = get_node_or_null("SpawnTimer")
@onready var zombies_container: Node3D = get_node_or_null("Zombies")
@onready var rail_follow: PathFollow3D = $CameraRail/RailFollow
@onready var camera_3d: Camera3D = $CameraRail/RailFollow/Camera3D
@onready var label_mensaje: Label = get_node_or_null("TextAnimation/LabelMensaje")
@onready var fade_rect: ColorRect = get_node_or_null("TextAnimation/ColorRectFade")
@onready var theme_final_boss: AudioStreamPlayer = get_node_or_null("theme_finalBoss")

@export_group("Música del jefe final")
@export var volumen_musica_jefe_db: float = -15.0

var fase: Fase = Fase.CINEMATICA
var is_boss_fight_active: bool = false
var has_weapon: bool = false
var active_weapon_instance: Area3D = null

var _walking: bool = false
var _walk_target: float = 0.0
var _walk_speed: float = 1.0
var _minions: Array[Node3D] = []
var _boss_bar: ProgressBar = null
var _boss_ui: CanvasLayer = null


func _ready() -> void:
	if theme_final_boss:
		theme_final_boss.stop()
		theme_final_boss.volume_db = volumen_musica_jefe_db
	rail_follow.set("altura_camara", altura_camara)
	# rail_follow.gd avanza solo si moving=true; lo apagamos hasta que el nivel lo pida
	rail_follow.set("moving", false)
	rail_follow.set_rail_speed(0.0)

	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.stop()

	if boss_ref:
		# El jefe necesita la cámara para deslizarse y embestir
		boss_ref.set("camera_ref", camera_3d)
		if boss_ref.has_signal("boss_defeated"):
			boss_ref.connect("boss_defeated", _on_boss_defeated)
		if boss_ref.has_signal("attack_connected"):
			boss_ref.connect("attack_connected", _on_boss_attack_connected)
		if boss_ref.has_signal("enraged"):
			boss_ref.connect("enraged", _on_boss_enraged)
		if boss_ref.has_signal("health_changed"):
			boss_ref.connect("health_changed", _on_boss_health_changed)
	# "Level 2 completed..." es un texto sobrante de la escena: se oculta
	var texto_sobrante: Node = get_node_or_null("TextAnimation/LabelMensaje2")
	if texto_sobrante:
		texto_sobrante.hide()

	_crear_barra_jefe()
	_iniciar_cinematica_entrada()


# =========================================================
# 1) CINEMÁTICA  ->  2) PISTOLA
# =========================================================
func _iniciar_cinematica_entrada() -> void:
	fase = Fase.CINEMATICA
	if anim_player and anim_player.has_animation(start_cinematic_name):
		anim_player.play(start_cinematic_name)
		await anim_player.animation_finished
	# La animación termina en CameraRail 61.3 m, dentro de la cafetería
	_esperar_arma()


func _esperar_arma() -> void:
	fase = Fase.ESPERANDO_ARMA
	rail_follow.set("moving", false)
	_crear_pistola()


func _crear_pistola() -> void:
	var arma := Area3D.new()
	arma.name = "Pistola3D_Item"
	var weapon_script: Script = load("res://scripts/objects/weapon_item.gd")
	if weapon_script:
		arma.set_script(weapon_script)
	add_child(arma)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.177, 0.223, 0.224, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.521, 0.387, 0.051, 1.0)
	mat.emission_energy_multiplier = 1.2

	# Silueta de pistola: cañón/corredera + empuñadura
	var cuerpo := MeshInstance3D.new()
	var cuerpo_mesh := BoxMesh.new()
	cuerpo_mesh.size = Vector3(0.12, 0.16, 0.55)
	cuerpo.mesh = cuerpo_mesh
	cuerpo.material_override = mat
	arma.add_child(cuerpo)

	var mango := MeshInstance3D.new()
	var mango_mesh := BoxMesh.new()
	mango_mesh.size = Vector3(0.12, 0.34, 0.16)
	mango.mesh = mango_mesh
	mango.material_override = mat
	mango.position = Vector3(0.0, -0.22, 0.17)
	mango.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	arma.add_child(mango)

	# Colisión grande y generosa para que sea fácil dispararle (capa 1, como pide el RayCast)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.8, 0.9)
	col.shape = shape
	arma.add_child(col)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.85, 0.2)
	luz.light_energy = 3.0
	luz.omni_range = 5.0
	arma.add_child(luz)

	# Posición (después de add_child para que global_position sea válido)
	if weapon_spawn_marker:
		arma.global_position = weapon_spawn_marker.global_position
	else:
		var adelante: Vector3 = -camera_3d.global_transform.basis.z
		adelante.y = 0.0
		adelante = adelante.normalized() if adelante.length() > 0.001 else Vector3.FORWARD
		arma.global_position = camera_3d.global_position + adelante * 2.5 + Vector3(0.0, -0.2, 0.0)

	arma.add_to_group("interactuable")
	if arma.has_signal("weapon_picked_up"):
		arma.connect("weapon_picked_up", _on_weapon_picked_up)
	active_weapon_instance = arma


func _on_weapon_picked_up() -> void:
	if has_weapon:
		return
	has_weapon = true
	_mostrar_mensaje("Weapon obtained!", 2.0)
	_salir_de_cafeteria_y_pelear()


# =========================================================
# 3) SALIR DE LA CAFETERÍA  ->  4) PELEA
# =========================================================
func _salir_de_cafeteria_y_pelear() -> void:
	fase = Fase.SALIENDO_CAFETERIA
	# La cámara empieza a mirar al jefe desde que sale (gira suave desde su pose actual)
	if boss_ref:
		camera_3d.call("start_tracking_boss", boss_ref)

	await _caminar_a(patio_entrance_progress, exit_cafeteria_speed)
	if fase == Fase.VICTORIA:
		return

	_iniciar_pelea()

	for i in fight_stops.size():
		await _caminar_a(fight_stops[i], fight_walk_speed)
		if not is_boss_fight_active:
			return
		_spawn_wave(wave_sizes[i] if i < wave_sizes.size() else 2)
		if i < fight_stops.size() - 1:
			await get_tree().create_timer(stop_wait_time).timeout
			if not is_boss_fight_active:
				return
	# Última parada: la cámara se queda quieta hasta que el jefe muera


func _iniciar_pelea() -> void:
	if is_boss_fight_active:
		return
	is_boss_fight_active = true
	fase = Fase.PELEA
	# Iniciar la música del jefe final con volumen reducido.
	if theme_final_boss:
		theme_final_boss.volume_db = volumen_musica_jefe_db
		theme_final_boss.play()
	
	if boss_ref and boss_ref.has_method("start_boss_fight"):
		boss_ref.call("start_boss_fight", camera_3d)

	if _boss_ui:
		_boss_ui.visible = true
	_mostrar_mensaje("Shoot its weak point to stop its attacks", 4.0)

	if spawn_timer:
		spawn_timer.wait_time = minion_interval
		spawn_timer.start()


# --- Movimiento de la cámara por el riel (lo avanza rail_follow.gd; aquí solo fijamos velocidad) ---
func _caminar_a(objetivo: float, velocidad: float) -> void:
	if rail_follow.progress >= objetivo - 0.05:
		return
	_walk_target = objetivo
	_walk_speed = velocidad
	_walking = true
	rail_follow.set_rail_speed(velocidad)
	rail_follow.set("moving", true)
	await rail_arrived


func _process(_delta: float) -> void:
	if not _walking:
		return
	var resto: float = _walk_target - rail_follow.progress
	if resto <= 0.05:
		_terminar_caminata()
		return
	# Frena suavemente al acercarse a la parada
	rail_follow.set_rail_speed(clampf(resto * 1.2, 0.35, _walk_speed))


func _terminar_caminata() -> void:
	_walking = false
	rail_follow.set("moving", false)
	rail_follow.set_rail_speed(0.0)
	rail_follow.progress = _walk_target
	rail_arrived.emit()


# =========================================================
# ZOMBIES DE APOYO
# =========================================================
func _on_spawn_timer_timeout() -> void:
	if not is_boss_fight_active:
		return
	_limpiar_minions()
	if _minions.size() < max_minions_alive:
		_spawn_minion()


func _spawn_wave(cantidad: int) -> void:
	_limpiar_minions()
	for i in cantidad:
		if _minions.size() >= max_minions_alive + 2:
			break
		_spawn_minion()
		await get_tree().create_timer(0.6).timeout
		if not is_boss_fight_active:
			return


func _spawn_minion() -> void:
	if zombie_minion_scene == null or boss_ref == null:
		return
	var minion := zombie_minion_scene.instantiate() as Node3D
	if minion == null:
		return
	if zombies_container:
		zombies_container.add_child(minion)
	else:
		add_child(minion)
	# global_position se asigna DESPUÉS de add_child (antes da error)
	minion.global_position = _minion_spawn_position()
	minion.set("is_player_detected", true)
	_minions.append(minion)


# Aparecen por los costados del jefe, para que corran hacia la cámara
# Aparecen únicamente por el lado derecho del jefe
func _minion_spawn_position() -> Vector3:
	var boss_pos: Vector3 = boss_ref.global_position
	var hacia_jefe: Vector3 = boss_pos - camera_3d.global_position
	hacia_jefe.y = 0.0
	hacia_jefe = hacia_jefe.normalized() if hacia_jefe.length() > 0.001 else Vector3.FORWARD
	var derecha: Vector3 = hacia_jefe.cross(Vector3.UP).normalized()
	
	# Forzamos siempre el lado derecho (1.0 en lugar de [-1.0, 1.0].pick_random())
	var lado: float = 1.0 
	
	var pos: Vector3 = boss_pos + derecha * lado * randf_range(4.0, 7.0) + hacia_jefe * randf_range(-1.0, 3.0)
	pos.y = boss_pos.y + 0.05
	return pos


func _limpiar_minions() -> void:
	var vivos: Array[Node3D] = []
	for m in _minions:
		if is_instance_valid(m) and not bool(m.get("is_dead")):
			vivos.append(m)
	_minions = vivos


# =========================================================
# EVENTOS DEL JEFE
# =========================================================
func _on_boss_attack_connected() -> void:
	if camera_3d.has_method("shake"):
		camera_3d.call("shake", 0.3, 0.4)


func _on_boss_enraged() -> void:
	_mostrar_mensaje("The boss is furious!", 2.0)
	if spawn_timer:
		spawn_timer.wait_time = maxf(minion_interval * 0.6, 3.0)
	_spawn_wave(2)


func _on_boss_health_changed(actual: int, maximo: int) -> void:
	if _boss_bar:
		_boss_bar.max_value = maximo
		_boss_bar.value = actual


func _on_boss_defeated() -> void:
	if fase == Fase.VICTORIA:
		return
	fase = Fase.VICTORIA
	is_boss_fight_active = false
	if theme_final_boss:
		theme_final_boss.stop()
	if spawn_timer:
		spawn_timer.stop()
	if _walking:
		_terminar_caminata()
	if _boss_ui:
		_boss_ui.visible = false
	for m in _minions:
		if is_instance_valid(m):
			m.queue_free()
	_minions.clear()

	await get_tree().create_timer(3.5).timeout
	if fade_rect:
		var tween := create_tween()
		tween.tween_property(fade_rect, "self_modulate:a", 1.0, 1.5)
		await tween.finished
	_mostrar_mensaje("YOU WON!, You escaped from the university", 3.0)
	await get_tree().create_timer(3.0).timeout
	if next_scene_path != "" and ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)


# =========================================================
# UI
# =========================================================
func _mostrar_mensaje(texto: String, duracion: float) -> void:
	if label_mensaje == null:
		return
	label_mensaje.text = texto
	label_mensaje.visible = true
	if duracion > 0.0:
		var actual := texto
		await get_tree().create_timer(duracion).timeout
		if is_instance_valid(label_mensaje) and label_mensaje.text == actual and fase != Fase.VICTORIA:
			label_mensaje.visible = false


# Barra de vida grande del jefe, arriba en pantalla (la barra 3D pequeña sigue existiendo)
func _crear_barra_jefe() -> void:
	_boss_ui = CanvasLayer.new()
	_boss_ui.layer = 20
	_boss_ui.visible = false
	add_child(_boss_ui)

	var titulo := Label.new()
	titulo.text = "FINAL BOSS"
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	titulo.anchor_left = 0.5
	titulo.anchor_right = 0.5
	titulo.offset_left = -260.0
	titulo.offset_right = 260.0
	titulo.offset_top = 10.0
	titulo.offset_bottom = 34.0
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_ui.add_child(titulo)

	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.offset_left = -260.0
	_boss_bar.offset_right = 260.0
	_boss_bar.offset_top = 38.0
	_boss_bar.offset_bottom = 60.0
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.08, 0.0, 0.0, 0.85)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Color(0.78, 0.08, 0.04)
	_boss_bar.add_theme_stylebox_override("background", fondo)
	_boss_bar.add_theme_stylebox_override("fill", relleno)
	_boss_ui.add_child(_boss_bar)
	if boss_ref:
		_boss_bar.max_value = float(boss_ref.get("max_health"))
		_boss_bar.value = _boss_bar.max_value
