extends CanvasLayer
## Pantalla de Game Over: muestra kills de cada jugador y los puntos totales.

# Lo asigna GameManager antes de añadir esta escena al árbol
var dead_player_id: int = 1

@onready var subtitle_label: Label = get_node_or_null("Center/VBoxContainer/SubtitleLabel")
@onready var p1_label: Label = get_node_or_null("Center/VBoxContainer/P1Label")
@onready var p2_label: Label = get_node_or_null("Center/VBoxContainer/P2Label")
@onready var score_label: Label = get_node_or_null("Center/VBoxContainer/ScoreLabel")
@onready var return_button: Button = get_node_or_null("Center/VBoxContainer/ReturnButton")


func _ready() -> void:
	# Debe funcionar con el juego en pausa y verse encima de todo
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var pointer_mgr: Node = get_tree().get_first_node_in_group("pointer_manager")
	if pointer_mgr:
		pointer_mgr.hide()

	var p1_name: String = str(GameManager.p1_character.get("name", "Jugador 1"))
	var p2_name: String = str(GameManager.p2_character.get("name", "Jugador 2"))
	var dead_name: String = p1_name if dead_player_id != 2 else p2_name

	if subtitle_label:
		subtitle_label.text = "%s ha muerto" % dead_name
	if p1_label:
		p1_label.text = "%s  -  KILLS: %d" % [p1_name, GameManager.p1_kills]
	if p2_label:
		p2_label.text = "%s  -  KILLS: %d" % [p2_name, GameManager.p2_kills]
	if score_label:
		score_label.text = "PUNTOS TOTALES: %d" % GameManager.score

	if return_button:
		return_button.pressed.connect(_on_return_pressed)
		return_button.grab_focus()


func _on_return_pressed() -> void:
	GameManager.reset_game()
	SaveManager.pending_data.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	queue_free()
