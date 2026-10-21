extends CanvasLayer

@onready var save_button: Button = get_node_or_null("Control/RedBanner/VBoxContainer/SaveButton")
@onready var load_button: Button = get_node_or_null("Control/LoadButton")

func _ready() -> void:
	# Si ejecutamos esta escena sola con F6, la mantenemos visible para pruebas
	if get_tree().current_scene == self:
		show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		hide()
	
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_button_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause() -> void:
	var new_pause_state: bool = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	
	# Buscamos la instancia del PointerManager en la escena
	var pointer_mgr = get_tree().get_first_node_in_group("pointer_manager")
	if pointer_mgr == null:
		pointer_mgr = get_tree().current_scene.find_child("PointerManager", true, false)
		
	if new_pause_state:
		# MODO PAUSA: Mostramos el cursor del SO y ocultamos las miras del juego
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if pointer_mgr:
			pointer_mgr.hide()
	else:
		# MODO JUEGO: Ocultamos el cursor del SO y mostramos las miras
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		if pointer_mgr:
			pointer_mgr.show()

func _on_save_button_pressed() -> void:
	print("Partida guardada correctamente.")

func _on_load_button_pressed() -> void:
	print("Partida cargada correctamente.")
