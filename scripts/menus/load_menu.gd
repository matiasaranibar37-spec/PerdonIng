extends CanvasLayer

@onready var slots_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/SlotsContainer
@onready var close_button: Button = $PanelContainer/VBoxContainer/CloseButton

func _ready() -> void:
	hide()
	if close_button:
		close_button.pressed.connect(func(): hide())

func refresh_slots() -> void:
	# Limpiamos slots anteriores
	for child in slots_container.get_children():
		child.queue_free()
		
	var saves: Array = SaveManager.get_save_history()
	
	if saves.is_empty():
		var no_save_label := Label.new()
		no_save_label.text = "No hay partidas guardadas."
		no_save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slots_container.add_child(no_save_label)
		return

	# Generamos un botón/fila por cada partida guardada
	for save_info in saves:
		var btn := Button.new()
		# Formato como la imagen 2: Partida 001 | level_1 | Vida: 60 | Fecha
		var display_text: String = "%s | %s | Vida: %d | %s" % [
			save_info.get("slot_name", "Partida"),
			save_info.get("level_name", "Nivel"),
			save_info.get("health", 100),
			save_info.get("date", "Sin Fecha")
		]
		btn.text = display_text
		
		# Conectamos la carga de esta partida
		var file_path: String = save_info.get("file_path", "")
		btn.pressed.connect(func():
			SaveManager.load_game_from_file(file_path)
			hide()
		)
		slots_container.add_child(btn)
