extends CanvasLayer
## Pantalla BEST SCORES: tabla arcade con los 5 mejores resultados guardados.

const HEADERS: Array[String] = ["RANK", "INITIALS", "SCORE", "KILLS", "TIME"]
const FONT: Font = preload("res://assets/Font/28 Days Later.ttf")

@onready var table: GridContainer = $Center/Panel/VBoxContainer/Table
@onready var back_button: Button = $Center/Panel/VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(close)
	refresh()
	back_button.grab_focus()


## Vuelve a leer ranking.json y reconstruye la tabla.
func refresh() -> void:
	for child in table.get_children():
		table.remove_child(child)
		child.queue_free()

	for header in HEADERS:
		table.add_child(_make_label(header, Color(1, 0.85, 0.3), 30))

	var top: Array = RankingManager.get_top()
	for i in range(RankingManager.TABLE_SIZE):
		var color: Color = Color(1, 0.85, 0.3) if i == 0 else Color(1, 1, 1)
		if i < top.size():
			var entry: Dictionary = top[i]
			table.add_child(_make_label(str(i + 1), color))
			table.add_child(_make_label(str(entry.get("initials", "---")), color))
			table.add_child(_make_label(str(int(entry.get("score", 0))), color))
			table.add_child(_make_label(str(int(entry.get("kills", 0))), color))
			table.add_child(_make_label(RankingManager.format_time(int(entry.get("time", -1))), color))
		else:
			var dim: Color = Color(0.5, 0.5, 0.5)
			table.add_child(_make_label(str(i + 1), dim))
			for _c in range(4):
				table.add_child(_make_label("---", dim))


func close() -> void:
	queue_free()


# Esc cierra la pantalla (igual que el menú de carga)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()


func _make_label(text: String, color: Color, size: int = 32) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(110, 0)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
