extends Node3D

@export var interruptores_necesarios: int = 3
@export_file("*.tscn") var siguiente_nivel: String = "res://level/level_2.tscn"
@export var velocidad_camara: float = 1.0
## Si un zombie ya detectó a los jugadores y está a esta distancia (o menos) de la cámara,
## la cámara se detiene hasta que lo maten.
@export var distancia_parada_camara: float = 5.0

var interruptores_activados: int = 0
var nivel_completado := false
var camino_completado := false
var camara_bloqueada := false

# Referencias a los nodos de la escena
@onready var hud = $HUD
@onready var rail_follow: PathFollow3D = get_node_or_null("CameraRail/RailFollow")
@onready var puzle_ui: CanvasLayer = get_node_or_null("InteractivePuzzle")
@onready var elevator_event: Node3D = get_node_or_null("ElevatorEvent")

func _ready() -> void:
	# 1. Ocultar la UI del teclado numérico al iniciar el nivel
	if puzle_ui:
		puzle_ui.hide()
		# Escuchar la señal del teclado que envía el puzle al acertar la clave
		if puzle_ui.has_signal("codigo_correcto"):
			if not puzle_ui.codigo_correcto.is_connected(_on_codigo_correcto):
				puzle_ui.codigo_correcto.connect(_on_codigo_correcto)
	# Regenerar la salud de los jugadores al iniciar el nivel
	if get_node_or_null("/root/GameManager"):
		GameManager.reset_health_for_new_level()

	# 2. Conectar interactuables o cilindros del grupo "switches" (si aún los usas)
	var interruptores = get_tree().get_nodes_in_group("switches")
	for interruptor in interruptores:
		if interruptor.has_signal("activado"):
			if not interruptor.activado.is_connected(_on_interruptor_activado):
				interruptor.activado.connect(_on_interruptor_activado)

	# 3. Si el jugador eligió "Load Game", restauramos aquí la partida guardada
	SaveManager.apply_save_data(self)

func _process(delta: float) -> void:
	# Si un zombie está atacando de cerca, la cámara se detiene hasta matarlo
	_actualizar_bloqueo_camara()
	if camara_bloqueada:
		return

	# Mueve la cámara sobre el riel hacia el fondo del pasillo
	if not camino_completado and rail_follow:
		rail_follow.progress += velocidad_camara * delta
		# FORZAR A LA CÁMARA A MANTENERSE TOTALMENTE HORIZONTAL
		
		if $CameraRail/RailFollow/Camera3D:
			$CameraRail/RailFollow/Camera3D.rotation.z = 0.0 # Cancela la inclinación lateral
		
		# Al llegar cerca del final del pasillo (frente a la puerta del ascensor)
		if rail_follow.progress_ratio >= 0.98:
			camino_completado = true
			_llegar_al_ascensor()

# Detiene (o reanuda) la cámara según haya un zombie vivo cerca atacando
func _actualizar_bloqueo_camara() -> void:
	var bloquear := _hay_zombie_cerca()
	if bloquear == camara_bloqueada:
		return
	camara_bloqueada = bloquear
	if rail_follow:
		rail_follow.set("moving", not bloquear)
	# Los pasos suenan solo mientras la cámara avanza
	var pasos: AudioStreamPlayer = get_node_or_null("Pasos")
	if pasos:
		pasos.stream_paused = bloquear

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

# Se ejecuta al llegar físicamente al fondo del pasillo
func _llegar_al_ascensor() -> void:
	print("Llegaste al ascensor. Se despliega la interfaz de la clave.")
	if puzle_ui:
		puzle_ui.show()

# Se ejecuta cuando el jugador ingresa el código correcto en el puzle
func _on_codigo_correcto() -> void:
	print("¡Código correcto ingresado! Abriendo el ascensor...")
	if puzle_ui:
		puzle_ui.hide()
		
	# Inicia la animación de las puertas deslizantes y la emboscada
	if elevator_event and elevator_event.has_method("abrir_puertas"):
		elevator_event.abrir_puertas()
	elif elevator_event and elevator_event.has_method("iniciar_secuencia_apertura"):
		elevator_event.iniciar_secuencia_apertura()

func _on_interruptor_activado() -> void:
	interruptores_activados += 1
	print("Interruptores activados: ", interruptores_activados, "/", interruptores_necesarios)

	if interruptores_activados >= interruptores_necesarios:
		completar_nivel_1()

# Lo llama el ascensor al terminar la cinemática final (pantalla ya en negro)
func ir_al_siguiente_nivel() -> void:
	if nivel_completado:
		return
	nivel_completado = true

	var ruta: String = _resolver_ruta_siguiente_nivel()
	if ruta != "":
		if get_node_or_null("/root/GameManager"):
			GameManager.change_level(ruta)
		else:
			get_tree().change_scene_to_file(ruta)
	else:
		push_warning("No se encontró level_2.tscn. Indica su ruta en 'siguiente_nivel' (Inspector de level_1).")
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Usa 'siguiente_nivel' si existe; si no, prueba las carpetas más comunes
func _resolver_ruta_siguiente_nivel() -> String:
	var candidatas: Array[String] = [
		siguiente_nivel,
		"res://level_2/level_2.tscn",
		"res://level/level_2.tscn",
		"res://level_2/level/level_2.tscn",
		"res://levels/level_2.tscn",
		"res://scenes/level_2.tscn",
	]
	for ruta in candidatas:
		if ruta != "" and ResourceLoader.exists(ruta):
			return ruta
	return ""

func completar_nivel_1() -> void:
	if nivel_completado:
		return
	nivel_completado = true

	# Notifica al HUD si la función existe
	if hud and hud.has_method("mostrar_mensaje_transicion"):
		hud.mostrar_mensaje_transicion("¡Acertijo resuelto! Pasando al Nivel 2...")

	await get_tree().create_timer(2.0).timeout

	# Cambia de nivel utilizando el GameManager Autoload o la carga directa
	if get_node_or_null("/root/GameManager"):
		GameManager.change_level(siguiente_nivel)
	elif ResourceLoader.exists(siguiente_nivel):
		get_tree().change_scene_to_file(siguiente_nivel)
	else:
		print("Crea la escena del siguiente nivel en la ruta: ", siguiente_nivel)


# ==========================================
# GUARDAR / CARGAR PARTIDA
# ==========================================
# SaveManager llama a estas dos funciones para guardar y restaurar el nivel.
func get_save_state() -> Dictionary:
	var zombies_vivos: Array = []
	var zombies_node: Node = get_node_or_null("zombies")
	if zombies_node:
		for z in zombies_node.get_children():
			if z.is_queued_for_deletion():
				continue
			if "is_dead" in z and z.is_dead:
				continue
			zombies_vivos.append(str(z.name))

	return {
		"rail_progress": rail_follow.progress if rail_follow else 0.0,
		"camino_completado": camino_completado,
		"interruptores_activados": interruptores_activados,
		"zombies_vivos": zombies_vivos
	}

func apply_save_state(state: Dictionary) -> void:
	if rail_follow and state.has("rail_progress"):
		rail_follow.progress = float(state["rail_progress"])
	camino_completado = bool(state.get("camino_completado", false))
	interruptores_activados = int(state.get("interruptores_activados", 0))

	# Los zombies que ya habían sido eliminados no deben reaparecer
	if state.has("zombies_vivos"):
		var vivos: Array = state["zombies_vivos"]
		var zombies_node: Node = get_node_or_null("zombies")
		if zombies_node:
			for z in zombies_node.get_children():
				if not vivos.has(str(z.name)):
					z.queue_free()
