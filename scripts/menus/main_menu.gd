extends Control

# Corregimos el nombre del nodo para que coincida exactamente con la jerarquía
@onready var new_game_button: Button = get_node_or_null("VBoxContainer/NewGameButton")
@onready var load_game_button: Button = get_node_or_null("VBoxContainer/LoadGameButton")
@onready var select_character_button: Button = get_node_or_null("VBoxContainer/SelectCharacterButton")
@onready var exit_button: Button = get_node_or_null("VBoxContainer/ExitButton")

@onready var load_menu_panel: CanvasLayer = get_node_or_null("LoadMenu")

# Rutas corregidas hacia tus archivos .tscn
@export_file("*.tscn") var character_select_scene: String = "res://scenes/ui/character_select.tscn"
@export_file("*.tscn") var first_level_path: String = "res://scenes/levels/level_1.tscn"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	else:
		push_error("No se encontró el nodo NewGameButton")
		
	if load_game_button:
		load_game_button.pressed.connect(_on_load_game_pressed)
	else:
		push_error("No se encontró el nodo LoadGameButton")
		
	if select_character_button:
		select_character_button.pressed.connect(_on_select_character_pressed)
	else:
		push_error("No se encontró el nodo SelectCharacterButton")
		
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	else:
		push_error("No se encontró el nodo ExitButton")
		
	if load_menu_panel:
		load_menu_panel.hide()

func _on_new_game_pressed() -> void:
	print("Iniciando nueva partida...")
	SaveManager.pending_data.clear()
	if get_node_or_null("/root/GameManager"):
		GameManager.reset_game()
	
	if ResourceLoader.exists(first_level_path):
		get_tree().change_scene_to_file(first_level_path)
	else:
		push_error("No existe el nivel inicial en la ruta: " + first_level_path)

func _on_start_game_pressed() -> void:
	# Si MainMenu es hijo de main.tscn, notificamos al script padre
	var main_parent = get_parent()
	if main_parent and main_parent.has_method("start_game"):
		main_parent.start_game()
	else:
		# Si el Menú Principal es una escena separada, despausamos antes de cargar
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/levels/level_1.tscn")

func _on_load_game_pressed() -> void:
	print("Abriendo menú de carga...")
	if load_menu_panel:
		load_menu_panel.show()
		if load_menu_panel.has_method("refresh_slots"):
			load_menu_panel.call("refresh_slots")
	else:
		push_error("No se encontró la instancia de LoadMenu en MainMenu")

func _on_select_character_pressed() -> void:
	print("Cargando selección de personajes...")
	if ResourceLoader.exists(character_select_scene):
		get_tree().change_scene_to_file(character_select_scene)
	else:
		push_error("No se encontró la escena de selección de personajes en: " + character_select_scene)

func _on_exit_pressed() -> void:
	print("Saliendo del juego...")
	get_tree().quit()
