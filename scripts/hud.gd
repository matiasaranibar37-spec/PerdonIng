extends CanvasLayer

# Referencias a los nodos de vida y score
@onready var health_bar_p1: ProgressBar = get_node_or_null("Control/P1Container/HBoxContainer/HeaderBanner/HealthBarP1")
@onready var health_bar_p2: ProgressBar = get_node_or_null("Control/P2Container/HBoxContainer2/HeaderBanner/HealthBarP2")
@onready var score_label: Label = get_node_or_null("Control/MarginContainer/TotalScoreLabel")

# Referencias directas a los Labels de Kills según tu árbol de escena de HUD
@onready var kills_label_p1: Label = get_node_or_null("Control/P1Container/HBoxContainer/KillsP1Label")
@onready var kills_label_p2: Label = get_node_or_null("Control/P2Container/HBoxContainer2/KillsP2Label")

func _ready() -> void:
	var p2_container: Control = get_node_or_null("Control/P2Container")
	if p2_container and get_node_or_null("/root/GameManager"):
		p2_container.visible = GameManager.player_count >= 2
	# Búsqueda alternativa si los Labels están como hijos directos de P1Container/P2Container
	if kills_label_p1 == null:
		kills_label_p1 = get_node_or_null("Control/P1Container/KillsP1Label")
	if kills_label_p2 == null:
		kills_label_p2 = get_node_or_null("Control/P2Container/KillsP2Label")

	# Nos conectamos a las señales emitidas por GameManager
	if get_node_or_null("/root/GameManager"):
		var gm = GameManager
		if gm.has_signal("score_updated") and not gm.score_updated.is_connected(_on_score_updated):
			gm.score_updated.connect(_on_score_updated)
		if gm.has_signal("kills_updated") and not gm.kills_updated.is_connected(_on_kills_updated):
			gm.kills_updated.connect(_on_kills_updated)
		if gm.has_signal("health_updated") and not gm.health_updated.is_connected(_on_health_updated):
			gm.health_updated.connect(_on_health_updated)

	actualizar_todo()

func actualizar_todo() -> void:
	if get_node_or_null("/root/GameManager"):
		var gm = GameManager
		_on_score_updated(gm.score)
		_on_kills_updated(gm.p1_kills, gm.p2_kills)
		_on_health_updated(gm.p1_health, gm.p2_health)

func _on_score_updated(nuevo_puntaje: int) -> void:
	if score_label:
		score_label.text = "SCORE: " + str(nuevo_puntaje)

func _on_kills_updated(p1_k: int, p2_k: int) -> void:
	if kills_label_p1:
		kills_label_p1.text = "KILLS: " + str(p1_k)
	if kills_label_p2:
		kills_label_p2.text = "KILLS: " + str(p2_k)

func _on_health_updated(p1_hp: int, p2_hp: int) -> void:
	if health_bar_p1:
		health_bar_p1.value = p1_hp
	if health_bar_p2:
		health_bar_p2.value = p2_hp
