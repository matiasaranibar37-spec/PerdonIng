extends Node3D

@export var interruptores_necesarios: int = 3
@export_file("*.tscn") var siguiente_nivel: String = "res://level/level_2.tscn"
@export var velocidad_camara: float = 1.0

var interruptores_activados: int = 0
var nivel_completado := false
var camino_completado := false

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

func _process(delta: float) -> void:
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
