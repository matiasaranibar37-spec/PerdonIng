extends Node3D
## Nivel 2: empieza con la animación "start" (cinemática) y luego funciona igual que el nivel 1:
## cámara sobre el riel con balanceo al caminar, punteros, vidas, kills, puntos, zombies,
## pausa, guardado y game over.

@export var animacion_intro: StringName = &"start"
## Con Enter/Espacio se salta la cinemática inicial.
@export var permitir_saltar_intro: bool = true
## Si es true, al terminar la cinemática la cámara camina por el riel (como en el nivel 1).
## Ponlo en false si en este nivel la cámara debe quedarse quieta tras la cinemática.
@export var avanzar_riel_tras_intro: bool = true
@export var velocidad_camara: float = 1.0
## Si un zombie ya detectó a los jugadores y está a esta distancia (o menos) de la cámara,
## la cámara se detiene hasta que lo maten.
@export var distancia_parada_camara: float = 5.0
## Segundo de la cinemática en que suena el derrumbe (nodo falling_debris).
## Déjalo en -1 si tu animación ya tiene una pista de audio para ese sonido.
@export var sonido_escombros_en_segundo: float = -1.0
## Evita que los zombies suelten su grito inicial al cargar el nivel (la biblioteca debe estar en silencio).
@export var silenciar_grito_inicial: bool = true
## Nodos extra que deben brillar al apuntarlos (además de "Coat" y "computer", que se detectan solos).
@export var interactuables_extra: Array[NodePath] = []
@export_file("*.tscn") var siguiente_nivel: String = ""

var en_cinematica: bool = false
var intro_hecha: bool = false
var riel_activo: bool = false
var camino_completado: bool = false
var camara_bloqueada: bool = false
var nivel_completado: bool = false

@onready var hud: Node = get_node_or_null("HUD")
@onready var rail_follow: PathFollow3D = get_node_or_null("CameraRail/RailFollow")
@onready var camara: Camera3D = get_node_or_null("CameraRail/RailFollow/Camera3D")
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var zombies_node: Node = get_node_or_null("zombies")
@onready var pasos: AudioStreamPlayer = get_node_or_null("Pasos")
@onready var sonido_escombros: AudioStreamPlayer = get_node_or_null("falling_debris")


func _ready() -> void:
	# Salud nueva para el nivel; puntos y kills continúan los del nivel 1
	if get_node_or_null("/root/GameManager"):
		GameManager.is_game_over = false
		GameManager.reset_health_for_new_level()

	_registrar_interactuables()
	var brillo: Node = load("res://scripts/interaction_highlighter.gd").new()
	brillo.name = "InteractionHighlighter"
	add_child(brillo)

	if silenciar_grito_inicial:
		_silenciar_zombies()

	# Si el jugador eligió "Load Game", se restaura aquí (y entonces no se repite la cinemática)
	SaveManager.apply_save_data(self)

	if intro_hecha:
		_terminar_intro()
	else:
		_iniciar_intro()


# ==========================================
# CINEMÁTICA INICIAL
# ==========================================
func _iniciar_intro() -> void:
	if anim_player == null or not anim_player.has_animation(animacion_intro):
		push_warning("No se encontró la animación '%s' en AnimationPlayer. Se salta la cinemática." % animacion_intro)
		_terminar_intro()
		return

	en_cinematica = true
	riel_activo = false

	# La cámara solo la mueve la animación: apagamos el balanceo y el bloqueo de horizonte
	if rail_follow:
		rail_follow.set("moving", false)
	if camara:
		camara.set_process(false)

	# Sin HUD ni punteros, y zombies quietos mientras dura la cinemática
	_set_interfaz_de_juego(false)
	_set_zombies_activos(false)

	anim_player.play(animacion_intro)

	if sonido_escombros_en_segundo >= 0.0 and sonido_escombros:
		get_tree().create_timer(sonido_escombros_en_segundo).timeout.connect(_reproducir_escombros)

	await anim_player.animation_finished
	_terminar_intro()


func _reproducir_escombros() -> void:
	if en_cinematica and sonido_escombros:
		sonido_escombros.play()


func _terminar_intro() -> void:
	en_cinematica = false
	intro_hecha = true

	_set_interfaz_de_juego(true)
	_set_zombies_activos(true)

	var puede_avanzar: bool = avanzar_riel_tras_intro and _riel_valido() and not camino_completado
	riel_activo = puede_avanzar
	if rail_follow:
		rail_follow.set("moving", puede_avanzar)
	if camara:
		# El script de la cámara (horizonte nivelado) solo vuelve cuando la cámara camina por el riel;
		# si se queda quieta, conserva exactamente la pose con la que terminó la animación.
		camara.set_process(puede_avanzar)
	_actualizar_pasos()


func _input(event: InputEvent) -> void:
	if en_cinematica and permitir_saltar_intro and event.is_action_pressed("ui_accept"):
		if anim_player and anim_player.is_playing():
			anim_player.seek(anim_player.current_animation_length, true)
			get_viewport().set_input_as_handled()


# ==========================================
# AVANCE DE LA CÁMARA (igual que el nivel 1)
# ==========================================
func _process(delta: float) -> void:
	if en_cinematica or nivel_completado or not riel_activo or rail_follow == null:
		return

	# Si un zombie está atacando de cerca, la cámara se detiene hasta matarlo
	_actualizar_bloqueo_camara()
	if camara_bloqueada:
		return

	rail_follow.progress += velocidad_camara * delta
	if camara:
		camara.rotation.z = 0.0  # Cancela la inclinación lateral

	# Al llegar al final del recorrido la cámara se detiene
	if rail_follow.progress_ratio >= 0.98:
		riel_activo = false
		camino_completado = true
		rail_follow.set("moving", false)
		_actualizar_pasos()
		print("Fin del recorrido del nivel 2.")


func _actualizar_bloqueo_camara() -> void:
	var bloquear: bool = _hay_zombie_cerca()
	if bloquear == camara_bloqueada:
		return
	camara_bloqueada = bloquear
	if rail_follow:
		rail_follow.set("moving", not bloquear)
	_actualizar_pasos()


func _hay_zombie_cerca() -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return false
	for z in get_tree().get_nodes_in_group("zombies"):
		# El grupo "zombies" también incluye RayCast3D hijos: solo nos interesan los zombies
		if not (z is CharacterBody3D) or not ("is_dead" in z):
			continue
		if z.is_dead or not z.is_player_detected or not z.is_visible_in_tree():
			continue
		if z.global_position.distance_to(cam.global_position) <= distancia_parada_camara:
			return true
	return false


# Los pasos suenan solo mientras la cámara camina
func _actualizar_pasos() -> void:
	if pasos == null:
		return
	var caminando: bool = riel_activo and not camara_bloqueada and not en_cinematica
	pasos.stream_paused = not caminando


func _riel_valido() -> bool:
	if rail_follow == null:
		return false
	var camino := rail_follow.get_parent() as Path3D
	return camino != null and camino.curve != null and camino.curve.point_count > 1


# ==========================================
# AYUDAS
# ==========================================
func _set_interfaz_de_juego(visible_: bool) -> void:
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = visible_
	var pm: Node = get_tree().get_first_node_in_group("pointer_manager")
	if pm:
		if pm is CanvasLayer:
			(pm as CanvasLayer).visible = visible_
		# Desactivado = no recibe clics, así no se dispara durante la cinemática
		pm.process_mode = Node.PROCESS_MODE_INHERIT if visible_ else Node.PROCESS_MODE_DISABLED


func _set_zombies_activos(activos: bool) -> void:
	if zombies_node == null:
		return
	for z in zombies_node.get_children():
		if z is CharacterBody3D and not ("is_dead" in z and z.is_dead):
			z.set_physics_process(activos)


func _silenciar_zombies() -> void:
	if zombies_node == null:
		return
	for z in zombies_node.get_children():
		if "audio_player" in z and z.audio_player:
			z.audio_player.stop()
		if "run_audio_player" in z and z.run_audio_player:
			z.run_audio_player.stop()


func _registrar_interactuables() -> void:
	# Por nombre: la chaqueta y la computadora brillan al apuntarlas
	for nombre in ["Coat", "computer"]:
		var nodo: Node = find_child(nombre, true, false)
		if nodo:
			nodo.add_to_group("interactuable")
	# Los que agregues desde el Inspector
	for ruta in interactuables_extra:
		var extra: Node = get_node_or_null(ruta)
		if extra:
			extra.add_to_group("interactuable")


# Lo llamará el nivel cuando el jugador salga de la biblioteca por la puerta final
func ir_al_siguiente_nivel() -> void:
	if nivel_completado:
		return
	nivel_completado = true
	if siguiente_nivel != "" and ResourceLoader.exists(siguiente_nivel):
		if get_node_or_null("/root/GameManager"):
			GameManager.change_level(siguiente_nivel)
		else:
			get_tree().change_scene_to_file(siguiente_nivel)
	else:
		push_warning("Falta definir el siguiente nivel en el Inspector (siguiente_nivel).")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ==========================================
# GUARDAR / CARGAR PARTIDA
# ==========================================
func get_save_state() -> Dictionary:
	var zombies_vivos: Array = []
	if zombies_node:
		for z in zombies_node.get_children():
			if z.is_queued_for_deletion():
				continue
			if "is_dead" in z and z.is_dead:
				continue
			zombies_vivos.append(str(z.name))

	return {
		"intro_hecha": intro_hecha,
		"rail_progress": rail_follow.progress if rail_follow else 0.0,
		"camino_completado": camino_completado,
		"zombies_vivos": zombies_vivos
	}


func apply_save_state(state: Dictionary) -> void:
	intro_hecha = bool(state.get("intro_hecha", true))
	camino_completado = bool(state.get("camino_completado", false))
	if rail_follow and state.has("rail_progress"):
		rail_follow.progress = float(state["rail_progress"])

	# Los zombies que ya habían sido eliminados no deben reaparecer
	if state.has("zombies_vivos") and zombies_node:
		var vivos: Array = state["zombies_vivos"]
		for z in zombies_node.get_children():
			if not vivos.has(str(z.name)):
				z.queue_free()
