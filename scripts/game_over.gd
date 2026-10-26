extends CanvasLayer
## Pantalla de fin de partida (victoria o derrota): "ENTER YOUR INITIALS".
## Pide 3 letras, guarda el resultado en el ranking y permite volver al menú.

var dead_player_id: int = 1
var result: String = "DERROTA"

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const SLOT_SIZE: Vector2 = Vector2(78, 96)

@onready var title_label: Label = get_node_or_null("Center/Panel/VBoxContainer/TitleLabel")
@onready var subtitle_label: Label = get_node_or_null("Center/Panel/VBoxContainer/SubtitleLabel")
@onready var score_label: Label = get_node_or_null("Center/Panel/VBoxContainer/ScoreLabel")
@onready var stats_label: Label = get_node_or_null("Center/Panel/VBoxContainer/StatsLabel")
@onready var prompt_label: Label = get_node_or_null("Center/Panel/VBoxContainer/PromptLabel")
@onready var slots_box: HBoxContainer = get_node_or_null("Center/Panel/VBoxContainer/Slots")
@onready var hint_label: Label = get_node_or_null("Center/Panel/VBoxContainer/HintLabel")
@onready var status_label: Label = get_node_or_null("Center/Panel/VBoxContainer/StatusLabel")
@onready var return_button: Button = get_node_or_null("Center/Panel/VBoxContainer/ReturnButton")

var initials: String = ""
var saved: bool = false
var _slot_labels: Array[Label] = []
var _final_score: int = 0
var _final_kills: int = 0
var _final_time: int = 0
var _blink: float = 0.0
var _returning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var pointer_mgr: Node = get_tree().get_first_node_in_group("pointer_manager")
	if pointer_mgr:
		pointer_mgr.hide()

	# Se congelan los datos finales de la partida
	_final_score = GameManager.score
	_final_kills = GameManager.p1_kills + GameManager.p2_kills
	_final_time = GameManager.get_run_seconds()

	var is_win: bool = result == GameManager.RESULT_WIN
	
	if title_label:
		title_label.text = "VICTORY" if is_win else "GAME OVER"
		title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if is_win else Color(0.85, 0.08, 0.05))
		
	if subtitle_label:
		if is_win:
			subtitle_label.text = "YOU ESCAPED THE UNIVERSITY"
		else:
			var p_name: String = str(GameManager.p1_character.get("name", "Player 1")) if dead_player_id != 2 \
					else str(GameManager.p2_character.get("name", "Player 2"))
			subtitle_label.text = "%s DIED" % p_name.to_upper()
			
	if score_label:
		score_label.text = "SCORE %d" % _final_score
	if stats_label:
		stats_label.text = "KILLS %d     TIME %s" % [_final_kills, RankingManager.format_time(_final_time)]

	# Crear las casillas visuales para las 3 letras
	if slots_box:
		for child in slots_box.get_children():
			child.queue_free()
		_slot_labels.clear()

		for i in range(RankingManager.INITIALS_LENGTH):
			var slot := PanelContainer.new()
			slot.custom_minimum_size = SLOT_SIZE
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.05, 0.05, 1)
			style.set_border_width_all(3)
			style.border_color = Color(1, 0.85, 0.3)
			slot.add_theme_stylebox_override("panel", style)
			
			var letter := Label.new()
			letter.text = "_"
			letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			letter.add_theme_font_size_override("font_size", 64)
			letter.add_theme_color_override("font_color", Color(1, 1, 1))
			
			slot.add_child(letter)
			slots_box.add_child(slot)
			_slot_labels.append(letter)

	if return_button:
		return_button.pressed.connect(_return_to_menu)
		return_button.hide() # Se oculta hasta que guarde con ENTER

	_refresh_slots()


func _process(delta: float) -> void:
	if saved:
		return
	# Parpadeo del cursor sobre la posición actual
	_blink += delta
	_refresh_slots()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	get_viewport().set_input_as_handled()

	if saved:
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			_return_to_menu()
		return

	var code: int = key_event.keycode
	# Detectar letras de la A a la Z
	if code >= KEY_A and code <= KEY_Z:
		if initials.length() < RankingManager.INITIALS_LENGTH:
			initials += char(code)
			if status_label: status_label.text = ""
			_refresh_slots()
	# Tecla Borrar
	elif code == KEY_BACKSPACE:
		if not initials.is_empty():
			initials = initials.substr(0, initials.length() - 1)
			if status_label: status_label.text = ""
			_refresh_slots()
	# Tecla Enter para confirmar e ingresar al ranking
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		_confirm()


func _refresh_slots() -> void:
	var cursor_on: bool = int(_blink * 2.0) % 2 == 0
	for i in range(_slot_labels.size()):
		if i < initials.length():
			_slot_labels[i].text = initials[i]
		elif i == initials.length() and not saved and cursor_on:
			_slot_labels[i].text = "_"
		else:
			_slot_labels[i].text = " " if i == initials.length() and not saved else "-"


func _confirm() -> void:
	if saved:
		return
	if initials.length() != RankingManager.INITIALS_LENGTH:
		if status_label:
			status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
			status_label.text = "ENTER 3 LETTERS"
		return
	if GameManager.result_saved:
		return

	# Guarda en el archivo ranking.json y obtiene el puesto alcanzado
	var rank: int = RankingManager.add_entry(initials, _final_score, _final_kills, _final_time, result)
	if rank < 0:
		if status_label:
			status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
			status_label.text = "COULD NOT SAVE"
		return

	GameManager.result_saved = true
	saved = true
	_refresh_slots()
	
	if prompt_label: prompt_label.text = "SCORE SAVED!"
	if status_label:
		status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		status_label.text = "%s - %d PTS - RANK #%d" % [initials, _final_score, rank] if rank <= RankingManager.TABLE_SIZE \
				else "%s - %d PTS SAVED" % [initials, _final_score]
	if hint_label: hint_label.text = "PRESS ENTER TO RETURN"
	
	if return_button:
		return_button.show()
		return_button.grab_focus()


func _return_to_menu() -> void:
	if _returning:
		return
	_returning = true
	GameManager.reset_game()
	SaveManager.pending_data.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	queue_free()
