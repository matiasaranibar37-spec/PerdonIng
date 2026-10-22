extends CanvasLayer

@onready var slots_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/SlotsContainer
@onready var close_button: Button = $PanelContainer/VBoxContainer/CloseButton


func _ready() -> void:
	hide()
	if close_button:
		close_button.pressed.connect(hide)


# Esc cierra el menú de carga (se procesa antes que el menú de pausa)
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and not event.is_echo():
		hide()
		get_viewport().set_input_as_handled()


func refresh_slots() -> void:
	for child in slots_container.get_children():
		slots_container.remove_child(child)
		child.queue_free()

	var saves: Array = SaveManager.get_save_history()

	if saves.is_empty():
		var no_save_label := Label.new()
		no_save_label.text = "No hay partidas guardadas."
		no_save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slots_container.add_child(no_save_label)
		return

	for save_info in saves:
		var btn := Button.new()
		# Ej: Partida 001 | level_1 | Vida: 60 | Score: 350 | Kills: 4 | 2026-10-21 18:30
		btn.text = "%s | %s | Vida: %d | Score: %d | Kills: %d | %s" % [
			save_info.get("slot_name", "Partida"),
			save_info.get("level_name", "Nivel"),
			int(save_info.get("health", 100)),
			int(save_info.get("score", 0)),
			int(save_info.get("kills", 0)),
			save_info.get("date", "Sin fecha")
		]

		var file_path: String = save_info.get("file_path", "")
		btn.pressed.connect(func():
			hide()
			SaveManager.load_game_from_file(file_path)
		)
		slots_container.add_child(btn)


func show_menu() -> void:
	show()
	refresh_slots()
