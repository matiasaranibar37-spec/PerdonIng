extends CanvasLayer

@onready var continue_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/ContinueButton")
@onready var save_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/SaveButton")
@onready var load_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/LoadButton")
@onready var restart_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/RestartButton")
@onready var exit_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/ExitButton")
@onready var load_menu_panel: CanvasLayer = get_node_or_null("LoadMenu")

func _ready() -> void:
	# Subimos el orden de renderizado al nivel máximo (100)
	layer = 100
	
	if get_tree().current_scene == self:
		show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		hide()
	
	if continue_button:
		continue_button.pressed.connect(toggle_pause)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

func _input(event: InputEvent) -> void:
	# Forzamos la detección de la acción "pause" (ESC)
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled() # Indica a Godot que ya se procesó esta tecla

func toggle_pause() -> void:
	var new_pause_state: bool = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	
	# Gestionar visibilidad de las miras 2D
	var pointer_mgr = get_tree().get_first_node_in_group("pointer_manager")
	if pointer_mgr == null and get_tree().current_scene:
		pointer_mgr = get_tree().current_scene.find_child("PointerManager", true, false)
		
	if new_pause_state:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if pointer_mgr:
			pointer_mgr.hide()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		if pointer_mgr:
			pointer_mgr.show()

func _on_save_pressed() -> void:
	var current_scene = get_tree().current_scene
	var player = get_tree().get_first_node_in_group("player")
	if player == null and current_scene:
		player = current_scene.find_child("Player", true, false)
	if player == null and current_scene:
		player = current_scene.find_child("player", true, false)
		
	if player:
		SaveManager.save_game(player, current_scene.scene_file_path)
		print("Partida guardada correctamente desde la pausa.")

func _on_load_pressed() -> void:
	if load_menu_panel:
		load_menu_panel.show()
		if load_menu_panel.has_method("refresh_slots"):
			load_menu_panel.call("refresh_slots")

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
