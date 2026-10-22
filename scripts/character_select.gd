extends Control

# Al confirmar la selección, regresamos al Menú Principal
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

const CHARACTERS := [
  {"id": "docente", "name": "Teacher", "health": 150, "description": "Higher endurance and leadership."},
  {"id": "estudiante_1", "name": "Student 1", "health": 100, "description": "Agile and balanced."},
  {"id": "estudiante_2", "name": "Student 2", "health": 110, "description": "Versatile and strategic."},
  {"id": "limpieza", "name": "Janitor", "health": 125, "description": "Resilient and consistent."}
]

const CHARACTER_IMAGES := [
	preload("res://assets/characters/docente.png"),
	preload("res://assets/characters/estudiante_1.png"),
	preload("res://assets/characters/estudiante_2.png"),
	preload("res://assets/characters/limpieza.png")
]

var selections: Dictionary = {1: 0, 2: 2}
var cards: Dictionary = {}
var status_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_interface()
	_refresh_cards()

func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#101827")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = "SELECT YOUR CHARACTER"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("#f8fafc"))
	layout.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Choose a character for each player"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#b8c9e6"))
	layout.add_child(subtitle)

	var player_panels := HBoxContainer.new()
	player_panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_panels.add_theme_constant_override("separation", 14)
	layout.add_child(player_panels)

	for player_id in [1, 2]:
		var player_panel := PanelContainer.new()
		player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		player_panel.add_theme_stylebox_override("panel", _panel_style(Color("#243650")))
		player_panels.add_child(player_panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		player_panel.add_child(column)

		var player_title := Label.new()
		player_title.text = "PLAYER %d — %s" % [player_id, "MOUSE" if player_id == 1 else "GAMEPAD"]
		player_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_title.add_theme_font_size_override("font_size", 20)
		column.add_child(player_title)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		column.add_child(grid)

		for index in range(CHARACTERS.size()):
			var character: Dictionary = CHARACTERS[index]
			var card_column := VBoxContainer.new()
			card_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card_column.add_theme_constant_override("separation", 4)
			grid.add_child(card_column)

			var portrait := TextureRect.new()
			portrait.texture = CHARACTER_IMAGES[index]
			portrait.custom_minimum_size = Vector2(120, 95)
			portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			card_column.add_child(portrait)

			var card := Button.new()
			card.custom_minimum_size = Vector2(135, 70)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.text = "%s\nBase Health: %d\n%s" % [character.name, character.health, character.description]
			card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.pressed.connect(_select_character.bind(player_id, index))
			card_column.add_child(card)
			cards["%d_%d" % [player_id, index]] = card

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)

	var confirm_button := Button.new()
	confirm_button.text = "✔ CONFIRMAR Y VOLVER"
	confirm_button.custom_minimum_size = Vector2(0, 48)
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_button.add_theme_font_size_override("font_size", 20)
	confirm_button.pressed.connect(_confirm_and_return)
	layout.add_child(confirm_button)

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	return style

func _select_character(player_id: int, character_index: int) -> void:
	selections[player_id] = character_index
	_refresh_cards()

func _refresh_cards() -> void:
	for player_id in [1, 2]:
		for index in range(CHARACTERS.size()):
			var card: Button = cards.get("%d_%d" % [player_id, index])
			if card:
				card.modulate = Color("#79d8ff") if selections[player_id] == index else Color.WHITE
	if status_label:
		var p1: Dictionary = CHARACTERS[selections[1]]
		var p2: Dictionary = CHARACTERS[selections[2]]
		status_label.text = "P1: %s (%d Health)     |     P2: %s (%d Health)" % [p1.name, p1.health, p2.name, p2.health]

func _confirm_and_return() -> void:
	# Guardamos la selección de personajes en GameManager
	if get_node_or_null("/root/GameManager"):
		GameManager.set_character_selection(CHARACTERS[selections[1]], CHARACTERS[selections[2]])
	# Regresamos al Menú Principal
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
