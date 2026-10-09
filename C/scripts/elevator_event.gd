extends Node3D

@onready var door_left: Node3D = $DoorLeft
@onready var door_right: Node3D = $DoorRight
@onready var zombie_emboscada: CharacterBody3D = $ZombieEmboscada
@onready var keypad_ui: Control = $ElevatorUI/KeypadUI
@onready var weapon_selection_ui: Control = $ElevatorUI/WeaponSelectionUI

@export var door_open_distance: float = 1.2
@export var door_speed: float = 1.0

# Define cuál es el objeto correcto que salva al jugador
enum ItemElegido { EXTINTOR, TUBO_PLASTICO, PLUMON }
const ITEM_CORRECTO = ItemElegido.EXTINTOR

var left_initial_pos: Vector3
var right_initial_pos: Vector3

func _ready() -> void:
	left_initial_pos = door_left.position
	right_initial_pos = door_right.position
	weapon_selection_ui.hide()
	zombie_emboscada.hide()

# 1. Función llamada cuando el equipo ingresa el código correcto en el puzle
func _on_codigo_puzzle_correcto() -> void:
	keypad_ui.hide()
	abrir_puertas()

func abrir_puertas() -> void:
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_left, "position:x", left_initial_pos.x - door_open_distance, door_speed)
	tween.tween_property(door_right, "position:x", right_initial_pos.x + door_open_distance, door_speed)
	
	# Al terminar de abrirse las puertas, se activa la emboscada
	tween.chain().tween_callback(_iniciar_emboscada)

# 2. El zombie ataca y el jugador pierde su arma inicial
func _iniciar_emboscada() -> void:
	zombie_emboscada.show()
	print("¡Un zombie salta desde el ascensor! Has perdido tu arma principal.")
	# Mostrar la pantalla de los 3 objetos interactivos
	weapon_selection_ui.show()

# 3. Respuesta a la selección de objeto (Interactuable por P1 o P2)
func seleccionar_objeto(item: ItemElegido) -> void:
	weapon_selection_ui.hide()
	
	if item == ITEM_CORRECTO:
		print("¡Usaste el extintor! Lograste derrotar al zombie.")
		_derrotar_zombie_y_avanzar()
	else:
		print("El objeto no sirvió para defenderte. ¡Game Over!")
		_game_over()

func _derrotar_zombie_y_avanzar() -> void:
	zombie_emboscada.queue_free()
	# Simular caída/falla del ascensor y cambiar al Nivel 2
	print("El ascensor se desploma por el combate. Obligados a ir a las escaleras...")
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/levels/level_2.tscn")

func _game_over() -> void:
	# Reiniciar el nivel o cargar la escena de Game Over
	get_tree().reload_current_scene()
