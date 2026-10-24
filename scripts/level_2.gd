extends Node3D
## Nivel 2: Biblioteca con cinemática inicial, parada en computadoras,
## activación de música, combate con la bibliotecaria y transición final.

@export var animacion_intro: StringName = &"start"
@export var permitir_saltar_intro: bool = true
@export var avanzar_riel_tras_intro: bool = true
@export var velocidad_camara: float = 1.0
@export var distancia_parada_camara: float = 5.0

## Progreso en el Path3D (0.0 a 1.0) donde la cámara se detiene en las computadoras
@export_range(0.0, 1.0) var punto_computadora_ratio: float = 0.5 

@export_file("*.tscn") var siguiente_nivel: String = "res://scenes/levels/level_3.tscn"

var en_cinematica: bool = false
var intro_hecha: bool = false
var riel_activo: bool = false
var camino_completado: bool = false
var camara_bloqueada: bool = false
var nivel_completado: bool = false

# Control del puzle y jefe
var en_computadora: bool = false
var musica_activada: bool = false
var camino_hacia_jefe_completado: bool = false

@onready var hud: Node = get_node_or_null("HUD")
@onready var rail_follow: PathFollow3D = get_node_or_null("CameraRail/RailFollow")
@onready var camara: Camera3D = get_node_or_null("CameraRail/RailFollow/Camera3D")
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var zombies_node: Node = get_node_or_null("zombies")
@onready var pasos: AudioStreamPlayer = get_node_or_null("Pasos")
@onready var soundtrack: AudioStreamPlayer = get_node_or_null("Soundtrack")

# Nodos de UI e Interacción del Nivel 2
@onready var library_computer: Area3D = get_node_or_null("LibraryComputer")
@onready var text_animation: CanvasLayer = get_node_or_null("TextAnimation")
@onready var color_rect_fade: ColorRect = get_node_or_null("TextAnimation/ColorRectFade")
@onready var label_mensaje: Label = get_node_or_null("TextAnimation/LabelMensaje")
@onready var zombie_librarian: CharacterBody3D = get_node_or_null("zombies/ZombieLibrarian")


func _ready() -> void:
	if get_node_or_null("/root/GameManager"):
		GameManager.is_game_over = false
		GameManager.reset_health_for_new_level()

	_registrar_interactuables()
	
	# Ocultar mensajes de finalización
	if label_mensaje:
		label_mensaje.hide()
	if color_rect_fade:
		color_rect_fade.modulate.a = 0.0

	# Conectar con la Zombie Bibliotecaria si existe en el grupo de zombies
	if zombie_librarian and zombie_librarian.has_signal("die"):
		zombie_librarian.die.connect(_on_bibliotecaria_derrotada)

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
		_terminar_intro()
		return

	en_cinematica = true
	riel_activo = false

	if rail_follow:
		rail_follow.set("moving", false)
	if camara:
		camara.set_process(false)

	_set_interfaz_de_juego(false)
	_set_zombies_activos(false)

	anim_player.play(animacion_intro)

	await anim_player.animation_finished
	_terminar_intro()


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
		camara.set_process(puede_avanzar)
		
	_actualizar_pasos()


func _input(event: InputEvent) -> void:
	if en_cinematica and permitir_saltar_intro and event.is_action_pressed("ui_accept"):
		if anim_player and anim_player.is_playing():
			anim_player.seek(anim_player.current_animation_length, true)
			get_viewport().set_input_as_handled()


# ==========================================
# AVANCE DE CÁMARA Y EVENTO DE COMPUTADORA
# ==========================================
func _process(delta: float) -> void:
	if en_cinematica or nivel_completado or not riel_activo or rail_follow == null:
		return

	_actualizar_bloqueo_camara()
	if camara_bloqueada:
		return

	# TRAMO 1: Avanzar camuflado hasta la Computadora
	if not en_computadora and not musica_activada:
		rail_follow.progress += velocidad_camara * delta
		
		if rail_follow.progress_ratio >= punto_computadora_ratio:
			en_computadora = true
			_llegar_a_computadoras()

	# TRAMO 2: Continuar hacia la Zombie Bibliotecaria tras activar la música
	elif musica_activada and not camino_hacia_jefe_completado:
		rail_follow.progress += velocidad_camara * delta
		
		if rail_follow.progress_ratio >= 0.98:
			camino_hacia_jefe_completado = true
			riel_activo = false
			_iniciar_combate_bibliotecaria()

	_actualizar_pasos()


func _llegar_a_computadoras() -> void:
	print("Llegaste al sector de computadoras. La cámara se detiene.")
	riel_activo = false
	_actualizar_pasos()
	
	# Si la computadora tiene un AnimationPlayer o interacción, se ejecuta aquí:
	if anim_player and anim_player.has_animation("activation_speakers"):
		anim_player.play("activation_speakers")
		await anim_player.animation_finished
		
	_activar_musica_y_reanudar()


func _activar_musica_y_reanudar() -> void:
	musica_activada = true
	print("Música activada. Los zombies se distraen y la cámara avanza hacia la bibliotecaria.")
	
	if soundtrack:
		soundtrack.play()
		
	riel_activo = true
	if rail_follow:
		rail_follow.set("moving", true)
	_actualizar_pasos()


func _iniciar_combate_bibliotecaria() -> void:
	print("Llegaste frente a la Zombie Bibliotecaria. ¡Inicia el combate!")
	if zombie_librarian and zombie_librarian.has_method("activar_combate"):
		zombie_librarian.activar_combate()


# ==========================================
# COMPLETAR NIVEL (PANTALLA NEGRA)
# ==========================================
func _on_bibliotecaria_derrotada() -> void:
	print("Zombie Bibliotecaria eliminada. Llave obtenida.")
	await get_tree().create_timer(1.0).timeout
	completar_nivel_2()


func completar_nivel_2() -> void:
	if nivel_completado:
		return
	nivel_completado = true
	riel_activo = false
	_actualizar_pasos()

	# Transición suave a pantalla negra mediante Tween
	if color_rect_fade:
		var tween = create_tween()
		tween.tween_property(color_rect_fade, "modulate:a", 1.0, 1.5)
		await tween.finished

	if label_mensaje:
		label_mensaje.text = "Level 2 completed..."
		label_mensaje.show()

	await get_tree().create_timer(2.5).timeout

	if siguiente_nivel != "" and ResourceLoader.exists(siguiente_nivel):
		if get_node_or_null("/root/GameManager"):
			GameManager.change_level(siguiente_nivel)
		else:
			get_tree().change_scene_to_file(siguiente_nivel)
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ==========================================
# HELPER FUNCTIONS
# ==========================================
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
		if not (z is CharacterBody3D) or not ("is_dead" in z):
			continue
		if z.is_dead or not z.is_player_detected or not z.is_visible_in_tree():
			continue
		if z.global_position.distance_to(cam.global_position) <= distancia_parada_camara:
			return true
	return false


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


func _set_interfaz_de_juego(visible_: bool) -> void:
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = visible_
	var pm: Node = get_tree().get_first_node_in_group("pointer_manager")
	if pm:
		if pm is CanvasLayer:
			(pm as CanvasLayer).visible = visible_
		pm.process_mode = Node.PROCESS_MODE_INHERIT if visible_ else Node.PROCESS_MODE_DISABLED


func _set_zombies_activos(activos: bool) -> void:
	if zombies_node == null:
		return
	for z in zombies_node.get_children():
		if z is CharacterBody3D and not ("is_dead" in z and z.is_dead):
			z.set_physics_process(activos)


func _registrar_interactuables() -> void:
	for nombre in ["Coat", "LibraryComputer"]:
		var nodo: Node = find_child(nombre, true, false)
		if nodo:
			nodo.add_to_group("interactuable")


# ==========================================
# SAVE / LOAD
# ==========================================
func get_save_state() -> Dictionary:
	var zombies_vivos: Array = []
	if zombies_node:
		for z in zombies_node.get_children():
			if z.is_queued_for_deletion() or ("is_dead" in z and z.is_dead):
				continue
			zombies_vivos.append(str(z.name))

	return {
		"intro_hecha": intro_hecha,
		"rail_progress": rail_follow.progress if rail_follow else 0.0,
		"camino_completado": camino_completado,
		"musica_activada": musica_activada,
		"zombies_vivos": zombies_vivos
	}


func apply_save_state(state: Dictionary) -> void:
	intro_hecha = bool(state.get("intro_hecha", true))
	camino_completado = bool(state.get("camino_completado", false))
	musica_activada = bool(state.get("musica_activada", false))
	
	if rail_follow and state.has("rail_progress"):
		rail_follow.progress = float(state["rail_progress"])

	if state.has("zombies_vivos") and zombies_node:
		var vivos: Array = state["zombies_vivos"]
		for z in zombies_node.get_children():
			if not vivos.has(str(z.name)):
				z.queue_free()
