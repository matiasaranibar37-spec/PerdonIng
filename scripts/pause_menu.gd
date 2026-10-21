extends CanvasLayer

# Referencias a los botones según tu jerarquía de nodos
@onready var save_button: Button = $Control/RedBanner/VBoxContainer/SaveButton
@onready var load_button: Button = $Control/LoadButton

func _ready() -> void:
	# Ocultamos el menú al iniciar la escena
	hide()
	
	# Conectamos las señales de los botones
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_button_pressed)

func _unhandled_input(event: InputEvent) -> void:
	# Escucha la acción de pausa (tecla ESC o asignada en el Mapa de Entradas)
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause() -> void:
	var new_pause_state: bool = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	
	if new_pause_state:
		# Al pausar, mostramos el ratón nativo para usar los botones del menú
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Al despausar, ocultamos el ratón nativo para usar tu mira azul en 2D
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _on_save_button_pressed() -> void:
	var current_scene = get_tree().current_scene
	var level_path = current_scene.scene_file_path
	
	# Busca al jugador por grupo o nombre
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = current_scene.find_child("Player", true, false)
	if player == null:
		player = current_scene.find_child("player", true, false)
		
	if player:
		SaveManager.save_game(player, level_path)
		print("Partida guardada correctamente.")
	else:
		push_error("No se encontró el nodo 'Player' para guardar la partida.")

func _on_load_button_pressed() -> void:
	SaveManager.load_game()
