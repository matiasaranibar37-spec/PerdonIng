extends Node3D

# Referencias a los nodos de la escena
@onready var door_left: CSGBox3D = $DoorLeft
@onready var door_right: CSGBox3D = $DoorRight
@onready var zombie_emboscada: Node3D = $ZombieEmboscada
@onready var selection_ui: CanvasLayer = $SelectionUI
@onready var puzzle_ui: CanvasLayer = get_node_or_null("InteractivePuzzle") # Referencia al teclado

# Parámetros editables desde el Inspector
@export var distancia_apertura: float = 1.0  # Distancia que desliza cada puerta
@export var tiempo_apertura: float = 1.2     # Tiempo en segundos que dura la apertura

# Enumeración de los 3 objetos de la emboscada
enum Objeto { EXTINTOR, TUBO_PLASTICO, PLUMON }
const OBJETO_CORRECTO = Objeto.EXTINTOR

var pos_inicial_izq: Vector3
var pos_inicial_der: Vector3

func _ready() -> void:
	# Guardamos las posiciones iniciales de las puertas cerradas
	pos_inicial_izq = door_left.position
	pos_inicial_der = door_right.position
	
	# Ocultamos la UI y el zombie al arrancar la escena
	if selection_ui:
		selection_ui.hide()
	if zombie_emboscada:
		zombie_emboscada.hide()
	
	# Escuchar cuando se resuelva la clave de 3 dígitos
	if puzzle_ui:
		puzzle_ui.hide()
		if puzzle_ui.has_signal("codigo_correcto"):
			if not puzzle_ui.codigo_correcto.is_connected(abrir_puertas):
				puzzle_ui.codigo_correcto.connect(abrir_puertas)


# Función llamada por el interruptor para desplegar la UI
func activar_teclado_puzzle() -> void:
	if puzzle_ui:
		puzzle_ui.show()

# ==========================================
# 1. APERTURA DE PUERTAS (Animación Tween)
# ==========================================
# Esta función se llama cuando el jugador acierta el código del teclado numérico
func abrir_puertas() -> void:
	print("¡Código correcto! Abriendo las puertas del ascensor...")
	
	# Usamos Tween para interpolar las posiciones de X en paralelo
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Desplazamos la puerta izquierda hacia -X y la derecha hacia +X
	tween.tween_property(door_left, "position:x", pos_inicial_izq.x - distancia_apertura, tiempo_apertura)
	tween.tween_property(door_right, "position:x", pos_inicial_der.x + distancia_apertura, tiempo_apertura)
	
	# Al finalizar el desplazamiento de ambas puertas, lanzamos la emboscada
	tween.chain().tween_callback(_ejecutar_emboscada_zombie)

# ==========================================
# 2. EMBOSCADA Y SELECCIÓN DE OBJETOS
# ==========================================
func _ejecutar_emboscada_zombie() -> void:
	print("¡Un zombie salta desde el ascensor! Has perdido tu arma principal.")
	
	if zombie_emboscada:
		zombie_emboscada.show()
		
	if selection_ui:
		selection_ui.show()

# Función que procesa la elección realizada por el jugador
func seleccionar_objeto(objeto_elegido: Objeto) -> void:
	if selection_ui:
		selection_ui.hide()
		
	if objeto_elegido == OBJETO_CORRECTO:
		print("¡Correcto! Neutralizaste al zombie con el extintor.")
		_completar_evento()
	else:
		print("Objeto equivocado. El zombie ataca. Game Over.")
		_game_over()

func _completar_evento() -> void:
	if zombie_emboscada:
		zombie_emboscada.queue_free()
		
	print("El cable del ascensor se rompe. Avanzando al Nivel 2...")
	await get_tree().create_timer(2.0).timeout
	
	# Notificamos al nivel principal que el evento concluyó para cambiar de escena
	var nivel_padre = get_parent()
	if nivel_padre and nivel_padre.has_method("completar_nivel_1"):
		nivel_padre.completar_nivel_1()

func _game_over() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
