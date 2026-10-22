extends CanvasLayer

@onready var continue_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/ContinueButton")
@onready var save_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/SaveButton")
@onready var load_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/LoadButton")
@onready var restart_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/RestartButton")
@onready var exit_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/ExitButton")
@onready var load_menu_panel: CanvasLayer = get_node_or_null("LoadMenu")

var _status_label: Label


func _ready() -> void:
	# Evita tener dos menús de pausa a la vez (si el nivel se usa dentro de main.tscn)
	if get_tree().get_nodes_in_group("pause_menu").size() > 0:
		queue_free()
		return
	add_to_group("pause_menu")

	# Debe seguir funcionando mientras el juego está en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	if get_tree().current_scene == self:
		show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		hide()

	# El menú de carga debe verse por encima del menú de pausa
	if load_menu_panel:
		load_menu_panel.layer = 101

	_create_status_label()

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
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	# Si el menú de carga está abierto, primero lo cerramos
	if load_menu_panel and load_menu_panel.visible:
		load_menu_panel.hide()
		return

	var new_pause_state: bool = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state

	var pointer_mgr: Node = get_tree().get_first_node_in_group("pointer_manager")

	if new_pause_state:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if pointer_mgr:
			pointer_mgr.hide()
	else:
		_status_label.text = ""
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		if pointer_mgr:
			pointer_mgr.show()


func _on_save_pressed() -> void:
	var level: Node = get_tree().current_scene
	if SaveManager.save_game(level):
		_show_status("Partida guardada")
	else:
		_show_status("No se pudo guardar")


func _on_load_pressed() -> void:
	if load_menu_panel:
		load_menu_panel.show()
		if load_menu_panel.has_method("refresh_slots"):
			load_menu_panel.call("refresh_slots")


func _on_restart_pressed() -> void:
	SaveManager.pending_data.clear()
	GameManager.reset_game()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 32)
	_status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_status_label.add_theme_constant_override("outline_size", 8)
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status_label.position.y = 40
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var root_control: Control = get_node_or_null("Control")
	if root_control:
		root_control.add_child(_status_label)
	else:
		add_child(_status_label)


func _show_status(text: String) -> void:
	_status_label.text = text
	_status_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_status_label, "modulate:a", 0.0, 0.5)
