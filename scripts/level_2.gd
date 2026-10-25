extends Node3D
## Nivel 2 (biblioteca).

enum Estado {
	INTRO,
	ESPERA_ABRIGO,
	CAMINO_ALTAVOCES,
	CINE_ALTAVOCES,
	ESPERA_COMPUTADORA,
	CAMINO_BIBLIOTECARIA,
	COMBATE_BIBLIOTECARIA,
	ESPERA_LLAVE,
	CAMINO_PUERTA,
	ESPERA_INTERRUPTOR,
	CINE_FINAL,
}

@export_group("Animaciones")
@export var animacion_intro: StringName = &"start"
@export var animacion_altavoces: StringName = &"activation_speakers"
@export var animacion_final: StringName = &"final_level2"
@export var animacion_puerta: StringName = &"open_door"
## Con Enter/Espacio se salta la cinemática en curso.
@export var permitir_saltar_cinematicas: bool = true

@export_group("Recorrido del riel (metros)")
@export var progreso_fin_intro: float = 85.85
@export var progreso_inicio_altavoces: float = 142.5
@export var progreso_fin_altavoces: float = 149.83
@export var progreso_bibliotecaria: float = 174.65
@export var progreso_puerta: float = 199.25

@export_group("Camara y zombies")
@export var velocidad_camara: float = 1.0
## Si un zombie ya detectó a los jugadores y está a esta distancia (o menos) de la cámara, la cámara se detiene.
@export var distancia_parada_camara: float = 5.0
## Si un zombie lleva más de estos segundos frenando la cámara sin poder alcanzarla (p. ej. atascado
## detrás de un estante) se deja de tener en cuenta y la cámara sigue. 0 = nunca se ignora.
@export var tiempo_max_bloqueo: float = 8.0
## Los zombies solo atacan si están delante de la cámara; los que quedan atrás se desactivan.
@export var zombies_solo_atacan_de_frente: bool = true
## Evita que los zombies suelten su grito inicial al cargar el nivel (la biblioteca debe estar en silencio).
@export var silenciar_grito_inicial: bool = true
@export var duracion_transicion_camara: float = 0.8
## Altura de la cámara sobre el riel al caminar (tu animación usa 0.73). Sube este valor si la vista sigue a ras de suelo.
@export var altura_camara_caminata: float = 1.5
## Los zombies caminan de un lado a otro mientras no detecten al jugador
@export var zombies_patrullan: bool = true
## Radio (m) alrededor de su posición inicial en el que patrullan
@export var radio_patrulla_zombies: float = 3.0

@export_group("Llave e interruptor")
@export var llave_se_recoge_disparando: bool = true
@export var llave_offset: Vector3 = Vector3(0.0, 0.6, 0.0)
@export var espera_tras_muerte_bibliotecaria: float = 1.5
@export var margen_colision_interruptor: float = 0.15
@export var mensaje_insertar_llave: String = "Insert key"

@export_group("Final")
@export var duracion_oscurecer: float = 1.5
@export var espera_pantalla_negra: float = 1.5
@export_file("*.tscn") var siguiente_nivel: String = "res://level_3/level_3.tscn"

const SCRIPT_INTERACTIVO: String = "res://scripts/objects/interactive_area.gd"
const SCRIPT_BRILLO: String = "res://scripts/interaction_highlighter.gd"

# --- Estado ---
var estado: int = Estado.INTRO
var en_cinematica: bool = false
var riel_activo: bool = false
var camara_bloqueada: bool = false
var objetivo_actual: float = 0.0
var pose_de_cinematica: bool = false
var camuflado: bool = false
var alerta_general: bool = false
var musica_activada: bool = false
var llave_soltada: bool = false
var tiene_llave: bool = false
var llave_pos: Vector3 = Vector3.ZERO
var nivel_completado: bool = false
var reproductor_actual: AnimationPlayer = null
# Zombie (id de instancia) -> segundo en que empezó a frenar la cámara. Sirve para detectar atascos.
var _bloqueo_desde: Dictionary = {}
var _nombre_bloqueador: String = ""

# --- Nodos del nivel ---
@onready var hud: Node = get_node_or_null("HUD")
@onready var rail_follow: PathFollow3D = get_node_or_null("CameraRail/RailFollow")
@onready var camara: Camera3D = get_node_or_null("CameraRail/RailFollow/Camera3D")
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var zombies_node: Node = get_node_or_null("zombies")
@onready var bibliotecaria: CharacterBody3D = get_node_or_null("zombies/ZombieLibrarian")
@onready var pasos: AudioStreamPlayer = get_node_or_null("Pasos")
@onready var musica_altavoces: AudioStreamPlayer = get_node_or_null("music_speakers")
@onready var puzzle_ui: CanvasLayer = get_node_or_null("PuzzleMusicaUI")
@onready var capa_texto: CanvasLayer = get_node_or_null("TextAnimation")
@onready var color_rect_fade: ColorRect = get_node_or_null("TextAnimation/ColorRectFade")
@onready var label_altavoces: Label = get_node_or_null("TextAnimation/LabelMensaje")
@onready var label_final: Label = get_node_or_null("TextAnimation/LabelMensaje2")
@onready var label_abrigo: Label = get_node_or_null("TextAnimation/LabelMensaje3")
@onready var label_puerta_cerrada: Label = get_node_or_null("TextAnimation/LabelMensaje4")
@onready var puerta: Node3D = get_node_or_null("Bag_Door")

var label_insertar_llave: Label = null
var coat: Area3D = null
var computadora: Area3D = null
var interruptor: Area3D = null
var anim_puerta: AnimationPlayer = null
var llave_nodo: Area3D = null


func _ready() -> void:
	add_to_group("nivel_alerta")  # Los zombies avisan aquí cuando reciben un disparo

	# Salud nueva para el nivel; puntos y kills continúan los del nivel 1
	if get_node_or_null("/root/GameManager"):
		GameManager.is_game_over = false
		GameManager.reset_health_for_new_level()

	if rail_follow:
		rail_follow.set("altura_camara", altura_camara_caminata)  # Requiere el rail_follow.gd nuevo
	_configurar_modo_jugadores()
	_asignar_camara_a_jugadores()
	_configurar_capas_ui()
	_preparar_textos()
	_preparar_interactuables()
	_preparar_zombies()
	_comprobar_riel()

	# Brillo leve al apuntar a los objetos interactuables
	var brillo: Node = load(SCRIPT_BRILLO).new()
	brillo.name = "InteractionHighlighter"
	add_child(brillo)

	# Si el jugador eligió "Load Game", se restaura aquí
	SaveManager.apply_save_data(self)

	if estado == Estado.INTRO:
		_iniciar_intro()
	else:
		_reanudar_estado()


# ==========================================
# PREPARACIÓN
# ==========================================
func _configurar_modo_jugadores() -> void:
	# Igual que el nivel 1: el segundo jugador depende del modo elegido
	var jugador_2: Node = get_node_or_null("PlayerP2")
	var punteros: Node = get_node_or_null("PointerManager")
	var modo_dos_jugadores := not get_node_or_null("/root/GameManager") or GameManager.player_count >= 2
	if jugador_2:
		jugador_2.visible = modo_dos_jugadores
	if punteros and punteros.has_node("Control/PointerP2"):
		punteros.get_node("Control/PointerP2").visible = modo_dos_jugadores
	if hud and hud.has_node("Control/P2Container"):
		hud.get_node("Control/P2Container").visible = modo_dos_jugadores


func _asignar_camara_a_jugadores() -> void:
	# PlayerP1/PlayerP2 de este nivel no tenían camera_path: sin cámara no pueden disparar
	if camara == null:
		return
	for nombre in ["PlayerP1", "PlayerP2"]:
		var jugador: Node = get_node_or_null(nombre)
		if jugador == null:
			continue
		if jugador.get("camera") == null:
			jugador.set("camera", camara)
		var ruta: NodePath = jugador.get("camera_path")
		if ruta.is_empty():
			jugador.set("camera_path", jugador.get_path_to(camara))


func _configurar_capas_ui() -> void:
	# Orden de capas: HUD < textos < ventana de música < punteros (los punteros siempre arriba)
	var pm: Node = get_tree().get_first_node_in_group("pointer_manager")
	if pm is CanvasLayer:
		(pm as CanvasLayer).layer = 30
	if puzzle_ui:
		puzzle_ui.layer = 20
	if capa_texto:
		capa_texto.layer = 15


func _preparar_textos() -> void:
	for etiqueta in [label_altavoces, label_final, label_abrigo, label_puerta_cerrada]:
		if etiqueta:
			etiqueta.hide()
			etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color_rect_fade:
		color_rect_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect_fade.self_modulate = Color(0, 0, 0, 0)

	# Mensaje "Insert key": copia de un mensaje existente para conservar su estilo
	if label_altavoces:
		label_insertar_llave = label_altavoces.duplicate() as Label
		label_insertar_llave.name = "LabelInsertKey"
		label_insertar_llave.text = mensaje_insertar_llave
		label_altavoces.get_parent().add_child(label_insertar_llave)
		label_insertar_llave.hide()


func _preparar_interactuables() -> void:
	# La música de los altavoces solo debe sonar cuando el jugador pulsa ACTIVATE
	# (el nodo music_speakers tiene Autoplay activado en la escena)
	if musica_altavoces:
		musica_altavoces.stop()

	# --- Chaqueta ---
	coat = find_child("Coat", true, false) as Area3D
	if coat:
		_convertir_en_interactivo(coat)  # Funciona aunque coat.tscn no tenga el script
		coat.set("habilitado", false)
		coat.connect("disparado", _on_abrigo_disparado)
	else:
		push_warning("No se encontró el nodo 'Coat'.")

	# --- Computadora ---
	computadora = get_tree().get_first_node_in_group("library_computer") as Area3D
	if computadora:
		computadora.set("habilitado", false)
		computadora.connect("computadora_disparada", _on_computadora_disparada)
	else:
		push_warning("No se encontró la LibraryComputer (grupo 'library_computer').")

	# --- Interruptor de la puerta (el Area3D dentro de Bag_Door) ---
	if puerta:
		interruptor = puerta.get_node_or_null("Area3D") as Area3D
		anim_puerta = puerta.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if interruptor:
		_convertir_en_interactivo(interruptor)
		interruptor.set("habilitado", false)
		interruptor.connect("disparado", _on_interruptor_disparado)
	else:
		push_warning("No se encontró el interruptor (Area3D) dentro de Bag_Door.")

	# --- Ventana de música ---
	if puzzle_ui and puzzle_ui.has_signal("musica_encendida"):
		puzzle_ui.connect("musica_encendida", _on_musica_encendida)

	# --- Bibliotecaria ---
	if bibliotecaria and bibliotecaria.has_signal("died"):
		bibliotecaria.connect("died", _on_bibliotecaria_derrotada)


# Le da a un Area3D la lógica de "disparable" y, si no tiene, una caja de colisión
func _convertir_en_interactivo(area: Area3D) -> void:
	if not area.has_signal("disparado"):
		area.set_script(load(SCRIPT_INTERACTIVO))
		area.call("_ready")  # Ya estaba en el árbol: lo ejecutamos a mano
	for hijo in area.get_children():
		if hijo is CollisionShape3D:
			return
	_agregar_colision_desde_cajas(area)


func _agregar_colision_desde_cajas(area: Area3D) -> void:
	var minimo := Vector3(INF, INF, INF)
	var maximo := Vector3(-INF, -INF, -INF)
	var hay_cajas := false
	for hijo in area.get_children():
		if hijo is CSGBox3D:
			var caja := hijo as CSGBox3D
			var mitad: Vector3 = caja.size * caja.scale.abs() * 0.5
			minimo = minimo.min(caja.position - mitad)
			maximo = maximo.max(caja.position + mitad)
			hay_cajas = true
	if not hay_cajas:
		return
	var margen := Vector3.ONE * margen_colision_interruptor
	var forma := BoxShape3D.new()
	forma.size = (maximo - minimo) + margen * 2.0
	var colision := CollisionShape3D.new()
	colision.shape = forma
	colision.position = (minimo + maximo) * 0.5
	area.add_child(colision)


func _preparar_zombies() -> void:
	if zombies_node == null:
		return
	# La bibliotecaria no detecta al jugador por sí sola: solo pelea cuando la cámara llega
	# al metro progreso_bibliotecaria (activar_combate) o si le disparan.
	if _es_bibliotecaria(bibliotecaria):
		bibliotecaria.set("detection_enabled", false)
	for z in zombies_node.get_children():
		# Patrullaje (la bibliotecaria ya tiene el suyo propio)
		if zombies_patrullan and not _es_bibliotecaria(z) and "patrullar" in z:
			z.patrullar = true
			z.radio_patrulla = radio_patrulla_zombies
		if silenciar_grito_inicial:
			if "audio_player" in z and z.audio_player:
				z.audio_player.stop()
			if "run_audio_player" in z and z.run_audio_player:
				z.run_audio_player.stop()


func _comprobar_riel() -> void:
	if rail_follow == null:
		push_error("No se encontró CameraRail/RailFollow.")
		return
	var camino := rail_follow.get_parent() as Path3D
	if camino == null or camino.curve == null:
		push_error("CameraRail no tiene curva.")
		return
	var largo: float = camino.curve.get_baked_length()
	if largo < progreso_puerta:
		push_warning("El riel mide %.1f m pero la puerta está en el metro %.2f." % [largo, progreso_puerta])


# ==========================================
# CINEMÁTICAS
# ==========================================
func _reproducir_cinematica(nombre: StringName, reproductor: AnimationPlayer = null, mueve_camara: bool = true, restaurar_interfaz: bool = true) -> void:
	var ap: AnimationPlayer = reproductor if reproductor else anim_player
	if ap == null or not ap.has_animation(nombre):
		push_warning("No existe la animación '%s'." % nombre)
		return

	en_cinematica = true
	_parar_camara()
	if mueve_camara and camara:
		camara.set_process(false)  # Solo la mueve la animación
	_set_interfaz_de_juego(false)

	reproductor_actual = ap
	ap.play(nombre)
	await ap.animation_finished
	reproductor_actual = null

	en_cinematica = false
	if mueve_camara:
		pose_de_cinematica = true
	if restaurar_interfaz:
		_set_interfaz_de_juego(true)


func _input(event: InputEvent) -> void:
	if en_cinematica and permitir_saltar_cinematicas and event.is_action_pressed("ui_accept"):
		if reproductor_actual and reproductor_actual.is_playing():
			reproductor_actual.seek(reproductor_actual.current_animation_length, true)
			get_viewport().set_input_as_handled()


# ==========================================
# 1. INTRO Y CHAQUETA
# ==========================================
func _iniciar_intro() -> void:
	estado = Estado.INTRO
	if rail_follow:
		rail_follow.progress = 0.0
	await _reproducir_cinematica(animacion_intro)
	_entrar_espera_abrigo()


func _entrar_espera_abrigo() -> void:
	estado = Estado.ESPERA_ABRIGO
	_parar_camara()
	if label_abrigo:
		label_abrigo.show()
	if coat:
		coat.show()
		coat.set("habilitado", true)


func _on_abrigo_disparado(_jugador_id: String) -> void:
	if estado != Estado.ESPERA_ABRIGO:
		return
	camuflado = true
	_aplicar_camuflaje()
	if label_abrigo:
		label_abrigo.hide()
	if coat:
		coat.hide()  # El jugador "se pone" la chaqueta
	print("Chaqueta puesta: los zombies no detectan a los jugadores (mientras no disparen).")
	estado = Estado.CAMINO_ALTAVOCES
	_caminar_hasta(progreso_inicio_altavoces)


# Camuflado = los zombies no pueden detectar al jugador por sí solos
func _aplicar_camuflaje() -> void:
	_set_deteccion_zombies(not camuflado)


func _set_deteccion_zombies(activa: bool) -> void:
	if zombies_node == null:
		return
	for z in zombies_node.get_children():
		if _es_bibliotecaria(z):
			continue  # Ella solo se activa en su pelea
		if "detection_enabled" in z:
			z.detection_enabled = activa


# ==========================================
# 2. ALTAVOCES Y COMPUTADORA
# ==========================================
func _llegar_a_altavoces() -> void:
	_parar_camara()
	estado = Estado.CINE_ALTAVOCES
	await _reproducir_cinematica(animacion_altavoces)
	_entrar_espera_computadora()


func _entrar_espera_computadora() -> void:
	estado = Estado.ESPERA_COMPUTADORA
	_parar_camara()
	if computadora:
		computadora.set("habilitado", true)


func _on_computadora_disparada() -> void:
	if estado != Estado.ESPERA_COMPUTADORA:
		return
	if computadora:
		computadora.set("habilitado", false)
	if puzzle_ui and puzzle_ui.has_method("mostrar"):
		puzzle_ui.call("mostrar")
	else:
		_on_musica_encendida()


func _on_musica_encendida() -> void:
	if estado != Estado.ESPERA_COMPUTADORA:
		return
	musica_activada = true
	if musica_altavoces:
		musica_altavoces.play()
	if label_altavoces:
		label_altavoces.hide()
	print("Música encendida: los zombies no oirán la pelea con la bibliotecaria.")
	estado = Estado.CAMINO_BIBLIOTECARIA
	_caminar_hasta(progreso_bibliotecaria)


# ==========================================
# 3. BIBLIOTECARIA Y LLAVE
# ==========================================
func _es_bibliotecaria(z: Node) -> bool:
	return is_instance_valid(bibliotecaria) and z == bibliotecaria


func _bibliotecaria_viva() -> bool:
	return is_instance_valid(bibliotecaria) \
		and not bibliotecaria.is_queued_for_deletion() \
		and not bool(bibliotecaria.get("is_dead"))


func _iniciar_combate_bibliotecaria() -> void:
	_parar_camara()
	estado = Estado.COMBATE_BIBLIOTECARIA
	if not _bibliotecaria_viva():
		_on_bibliotecaria_derrotada()
		return
	print("Frente a la bibliotecaria: ¡empieza la pelea!")
	if bibliotecaria.has_method("activar_combate"):
		bibliotecaria.call("activar_combate")


func _on_bibliotecaria_derrotada() -> void:
	if llave_soltada:
		return
	llave_soltada = true
	_parar_camara()
	estado = Estado.ESPERA_LLAVE
	var posicion: Vector3 = llave_pos
	if is_instance_valid(bibliotecaria):
		posicion = bibliotecaria.global_position + llave_offset
	await get_tree().create_timer(espera_tras_muerte_bibliotecaria).timeout
	_soltar_llave(posicion)


func _soltar_llave(posicion: Vector3) -> void:
	llave_pos = posicion
	llave_nodo = _crear_llave()
	add_child(llave_nodo)
	llave_nodo.global_position = posicion
	llave_nodo.connect("disparado", _on_llave_disparada)
	if not llave_se_recoge_disparando:
		_on_llave_disparada("")


func _crear_llave() -> Area3D:
	var llave := Area3D.new()
	llave.name = "Llave"
	llave.set_script(load(SCRIPT_INTERACTIVO))  # Antes de add_child: su _ready se ejecuta solo
	llave.set("velocidad_giro", 1.8)

	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.45
	forma.shape = esfera
	llave.add_child(forma)

	var dorado := StandardMaterial3D.new()
	dorado.albedo_color = Color(1.0, 0.78, 0.2)
	dorado.metallic = 0.8
	dorado.roughness = 0.3
	dorado.emission_enabled = true
	dorado.emission = Color(0.35, 0.22, 0.0)

	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.06
	toro.outer_radius = 0.13
	aro.mesh = toro
	aro.material_override = dorado
	aro.position = Vector3(0.0, 0.17, 0.0)
	aro.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	llave.add_child(aro)

	var eje := MeshInstance3D.new()
	var caja_eje := BoxMesh.new()
	caja_eje.size = Vector3(0.045, 0.32, 0.045)
	eje.mesh = caja_eje
	eje.material_override = dorado
	eje.position = Vector3(0.0, -0.05, 0.0)
	llave.add_child(eje)

	var diente := MeshInstance3D.new()
	var caja_diente := BoxMesh.new()
	caja_diente.size = Vector3(0.12, 0.045, 0.045)
	diente.mesh = caja_diente
	diente.material_override = dorado
	diente.position = Vector3(0.07, -0.16, 0.0)
	llave.add_child(diente)

	return llave


func _on_llave_disparada(_jugador_id: String) -> void:
	if estado != Estado.ESPERA_LLAVE:
		return
	tiene_llave = true
	if is_instance_valid(llave_nodo):
		llave_nodo.queue_free()
	print("Llave obtenida.")
	estado = Estado.CAMINO_PUERTA
	_caminar_hasta(progreso_puerta)


# ==========================================
# 4. PUERTA Y FINAL
# ==========================================
func _llegar_a_puerta() -> void:
	_parar_camara()
	estado = Estado.ESPERA_INTERRUPTOR
	if label_insertar_llave:
		label_insertar_llave.show()
	if interruptor:
		interruptor.set("habilitado", true)


func _on_interruptor_disparado(_jugador_id: String) -> void:
	if estado != Estado.ESPERA_INTERRUPTOR:
		return
	estado = Estado.CINE_FINAL
	if label_insertar_llave:
		label_insertar_llave.hide()

	# Se abre la puerta grande (escena Bag_Door)
	if anim_puerta and anim_puerta.has_animation(animacion_puerta):
		anim_puerta.play(animacion_puerta)
		await anim_puerta.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout

	_apagar_musica_altavoces()
	await _reproducir_cinematica(animacion_final, null, false, false)
	await _oscurecer_pantalla()
	nivel_completado = true
	_ir_al_siguiente_nivel()


func _apagar_musica_altavoces() -> void:
	if musica_altavoces and musica_altavoces.playing:
		var tween := create_tween()
		tween.tween_property(musica_altavoces, "volume_db", -40.0, 1.2)
		tween.tween_callback(musica_altavoces.stop)


func _oscurecer_pantalla() -> void:
	if color_rect_fade:
		color_rect_fade.show()
		# La animación la deja a medias: la llevamos a negro total
		var tween := create_tween()
		tween.tween_property(color_rect_fade, "self_modulate", Color(0, 0, 0, 1), duracion_oscurecer)
		await tween.finished
	await get_tree().create_timer(espera_pantalla_negra).timeout


func _ir_al_siguiente_nivel() -> void:
	if siguiente_nivel != "" and ResourceLoader.exists(siguiente_nivel):
		if get_node_or_null("/root/GameManager"):
			GameManager.change_level(siguiente_nivel)
		else:
			get_tree().change_scene_to_file(siguiente_nivel)
	else:
		push_warning("No existe el siguiente nivel: '%s'. Vuelvo al menú." % siguiente_nivel)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ==========================================
# MOVIMIENTO DE LA CÁMARA POR EL RIEL
# ==========================================
func _process(delta: float) -> void:
	_actualizar_zombies()
	if nivel_completado or en_cinematica or not riel_activo or rail_follow == null:
		return

	# Si un zombie está atacando de frente y cerca, la cámara se detiene hasta matarlo
	_actualizar_bloqueo_camara()
	if camara_bloqueada:
		return

	rail_follow.progress += velocidad_camara * delta
	if camara:
		camara.rotation.z = 0.0  # Cancela la inclinación lateral

	if rail_follow.progress >= objetivo_actual:
		rail_follow.progress = objetivo_actual
		_llegar_a_objetivo()


func _llegar_a_objetivo() -> void:
	match estado:
		Estado.CAMINO_ALTAVOCES:
			_llegar_a_altavoces()
		Estado.CAMINO_BIBLIOTECARIA:
			_iniciar_combate_bibliotecaria()
		Estado.CAMINO_PUERTA:
			_llegar_a_puerta()
		_:
			_parar_camara()


func _caminar_hasta(objetivo: float) -> void:
	objetivo_actual = objetivo
	if pose_de_cinematica:
		await _suavizar_camara()
	if en_cinematica or nivel_completado:
		return
	riel_activo = true
	camara_bloqueada = false
	_bloqueo_desde.clear()
	if rail_follow:
		rail_follow.set("moving", true)  # Activa el balanceo al caminar
	if camara:
		camara.set_process(true)
	_actualizar_pasos()


func _parar_camara() -> void:
	riel_activo = false
	if rail_follow:
		rail_follow.set("moving", false)
	_actualizar_pasos()


# Pasa de la pose de la cinemática a la pose normal de caminata sin saltos bruscos
func _suavizar_camara() -> void:
	pose_de_cinematica = false
	if camara == null:
		return
	camara.set_process(false)
	var pitch: float = -5.0
	if "fixed_pitch_angle" in camara:
		pitch = float(camara.get("fixed_pitch_angle"))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(camara, "position", Vector3(0.0, altura_camara_caminata, 0.0), duracion_transicion_camara)
	tween.tween_property(camara, "rotation", Vector3(deg_to_rad(pitch), 0.0, 0.0), duracion_transicion_camara)
	await tween.finished


func _actualizar_bloqueo_camara() -> void:
	var bloquear: bool = _hay_zombie_cerca()
	if bloquear == camara_bloqueada:
		return
	camara_bloqueada = bloquear
	if bloquear:
		print("Cámara detenida por: ", _nombre_bloqueador)
	if rail_follow:
		rail_follow.set("moving", not bloquear)
	_actualizar_pasos()


func _adelante_de(cam: Camera3D) -> Vector3:
	var adelante: Vector3 = -cam.global_transform.basis.z
	adelante.y = 0.0
	if adelante.length() < 0.001:
		return Vector3.FORWARD
	return adelante.normalized()


func _hay_zombie_cerca() -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return false
	var adelante: Vector3 = _adelante_de(cam)
	var ahora: float = Time.get_ticks_msec() / 1000.0
	var bloqueando: Dictionary = {}
	var hay_bloqueo: bool = false
	for z in get_tree().get_nodes_in_group("zombies"):
		# El grupo "zombies" también incluye RayCast3D hijos: solo nos interesan los zombies
		if not (z is CharacterBody3D) or not ("is_dead" in z):
			continue
		if z.is_dead or not z.is_player_detected or not z.is_visible_in_tree():
			continue
		if not bool(z.get_meta("activo", true)):
			continue
		var hacia: Vector3 = z.global_position - cam.global_position
		if hacia.length() > distancia_parada_camara:
			continue
		hacia.y = 0.0
		if zombies_solo_atacan_de_frente and hacia.length() > 0.5 and adelante.dot(hacia.normalized()) < 0.0:
			continue

		# Este zombie está cerca, de frente y detectó al jugador: frena la cámara...
		var id: int = z.get_instance_id()
		var desde: float = float(_bloqueo_desde.get(id, ahora))
		bloqueando[id] = desde
		# ...salvo que lleve demasiado tiempo sin llegar (atascado en un estante, sin poder dispararle)
		if tiempo_max_bloqueo > 0.0 and ahora - desde > tiempo_max_bloqueo:
			continue
		hay_bloqueo = true
		_nombre_bloqueador = "%s (a %.1f m)" % [z.name, (z.global_position - cam.global_position).length()]
	_bloqueo_desde = bloqueando
	return hay_bloqueo


# Los pasos suenan solo mientras la cámara camina
func _actualizar_pasos() -> void:
	if pasos == null:
		return
	var caminando: bool = riel_activo and not camara_bloqueada and not en_cinematica
	pasos.stream_paused = not caminando


# ==========================================
# ZOMBIES: SOLO ATACAN DE FRENTE Y SE CONGELAN EN LAS CINEMÁTICAS
# ==========================================
func _actualizar_zombies() -> void:
	if zombies_node == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var adelante: Vector3 = _adelante_de(cam)

	for z in zombies_node.get_children():
		if not (z is CharacterBody3D) or z.is_queued_for_deletion():
			continue
		if "is_dead" in z and z.is_dead:
			continue

		var detras: bool = bool(z.get_meta("detras", false))
		if zombies_solo_atacan_de_frente:
			var hacia: Vector3 = z.global_position - cam.global_position
			hacia.y = 0.0
			if hacia.length() > 0.5:
				var d: float = adelante.dot(hacia.normalized())
				if d < -0.35:
					detras = true
				elif d > -0.05:
					detras = false
		else:
			detras = false
		z.set_meta("detras", detras)

		var activo: bool = not en_cinematica and not detras
		if bool(z.get_meta("activo", true)) != activo:
			z.set_meta("activo", activo)
			z.set_physics_process(activo)
			if not activo:
				if z.has_method("stop_running_sound"):
					z.stop_running_sound()
				if detras and "is_player_detected" in z:
					z.is_player_detected = false  # Se olvida del jugador al quedar atrás


# Lo llaman los zombies (grupo "nivel_alerta") cuando reciben un disparo
func zombie_disparado(z: Node) -> void:
	# La música tapa el ruido de la pelea con la bibliotecaria
	if z == bibliotecaria and musica_activada:
		return
	_alertar_a_todos()


func _alertar_a_todos() -> void:
	if alerta_general:
		return
	alerta_general = true
	camuflado = false
	print("¡Alerta! Todos los zombies detectaron a los jugadores.")
	if zombies_node == null:
		return
	for z in zombies_node.get_children():
		if not (z is CharacterBody3D):
			continue
		if _es_bibliotecaria(z):
			continue  # La alarma general NO despierta a la bibliotecaria
		if "is_dead" in z and z.is_dead:
			continue
		if "detection_enabled" in z:
			z.detection_enabled = true
		if "is_player_detected" in z:
			z.is_player_detected = true


# ==========================================
# INTERFAZ
# ==========================================
func _set_interfaz_de_juego(mostrar: bool) -> void:
	if hud and "visible" in hud:
		hud.visible = mostrar
	var pm: Node = get_tree().get_first_node_in_group("pointer_manager")
	if pm:
		if pm is CanvasLayer:
			(pm as CanvasLayer).visible = mostrar
		# Desactivado = no recibe clics, así no se dispara durante las cinemáticas
		pm.process_mode = Node.PROCESS_MODE_INHERIT if mostrar else Node.PROCESS_MODE_DISABLED


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
		"estado": int(estado),
		"camuflado": camuflado,
		"alerta_general": alerta_general,
		"musica_activada": musica_activada,
		"tiene_llave": tiene_llave,
		"llave_soltada": llave_soltada,
		"llave_pos": [llave_pos.x, llave_pos.y, llave_pos.z],
		"rail_progress": rail_follow.progress if rail_follow else 0.0,
		"zombies_vivos": zombies_vivos
	}


func apply_save_state(state: Dictionary) -> void:
	estado = int(state.get("estado", Estado.INTRO))
	camuflado = bool(state.get("camuflado", false))
	alerta_general = bool(state.get("alerta_general", false))
	musica_activada = bool(state.get("musica_activada", false))
	tiene_llave = bool(state.get("tiene_llave", false))
	llave_soltada = bool(state.get("llave_soltada", false))
	var lp: Variant = state.get("llave_pos", [0.0, 0.0, 0.0])
	if lp is Array and lp.size() == 3:
		llave_pos = Vector3(float(lp[0]), float(lp[1]), float(lp[2]))
	if rail_follow and state.has("rail_progress"):
		rail_follow.progress = float(state["rail_progress"])

	# Los zombies que ya habían sido eliminados no deben reaparecer
	if state.has("zombies_vivos") and zombies_node:
		var vivos: Array = state["zombies_vivos"]
		for z in zombies_node.get_children():
			if not vivos.has(str(z.name)):
				z.queue_free()


# Continúa desde el punto guardado (sin repetir las cinemáticas ya vistas)
func _reanudar_estado() -> void:
	pose_de_cinematica = false
	if camara:
		var pitch: float = -5.0
		if "fixed_pitch_angle" in camara:
			pitch = float(camara.get("fixed_pitch_angle"))
		camara.position = Vector3(0.0, altura_camara_caminata, 0.0)
		camara.rotation = Vector3(deg_to_rad(pitch), 0.0, 0.0)
	_set_interfaz_de_juego(true)

	if camuflado:
		_aplicar_camuflaje()
		if coat:
			coat.hide()
			coat.set("habilitado", false)
	if musica_activada and musica_altavoces:
		musica_altavoces.play()
	if alerta_general:
		alerta_general = false
		_alertar_a_todos()

	match estado:
		Estado.ESPERA_ABRIGO:
			if rail_follow:
				rail_follow.progress = progreso_fin_intro
			_entrar_espera_abrigo()
		Estado.CAMINO_ALTAVOCES:
			_caminar_hasta(progreso_inicio_altavoces)
		Estado.CINE_ALTAVOCES, Estado.ESPERA_COMPUTADORA:
			if rail_follow:
				rail_follow.progress = progreso_fin_altavoces
			_entrar_espera_computadora()
		Estado.CAMINO_BIBLIOTECARIA:
			_caminar_hasta(progreso_bibliotecaria)
		Estado.COMBATE_BIBLIOTECARIA:
			if rail_follow:
				rail_follow.progress = progreso_bibliotecaria
			_iniciar_combate_bibliotecaria()
		Estado.ESPERA_LLAVE:
			if llave_soltada:
				_soltar_llave(llave_pos)
			else:
				_on_bibliotecaria_derrotada()
		Estado.CAMINO_PUERTA:
			_caminar_hasta(progreso_puerta)
		Estado.ESPERA_INTERRUPTOR, Estado.CINE_FINAL:
			if rail_follow:
				rail_follow.progress = progreso_puerta
			_llegar_a_puerta()
		_:
			_iniciar_intro()
