extends CanvasLayer

# Usamos get_node_or_null para evitar cierres inesperados si la ruta del nodo cambia
@onready var label_score: Label = get_node_or_null("Control/MarginContainer/HBoxContainer/LabelScore")
@onready var label_p1_health: Label = get_node_or_null("Control/MarginContainer/HBoxContainer/LabelP1Health")
@onready var label_p2_health: Label = get_node_or_null("Control/MarginContainer/HBoxContainer/LabelP2Health")
@onready var label_mensaje: Label = get_node_or_null("Control/LabelMessage")

func _ready() -> void:
	# Ocultar mensaje de transición inicialmente
	if label_mensaje:
		label_mensaje.visible = false
	
	# Conectar la señal de puntuación desde el Singleton GameManager
	if get_node_or_null("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_signal("score_updated"):
			if not gm.score_updated.is_connected(_on_score_updated):
				gm.score_updated.connect(_on_score_updated)
	
	actualizar_hud()

func actualizar_hud() -> void:
	if get_node_or_null("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		
		# Validamos que cada etiqueta exista antes de cambiar su texto
		if label_score:
			label_score.text = "Puntaje: " + str(gm.score)
		if label_p1_health:
			label_p1_health.text = "P1 Salud: " + str(gm.p1_health)
		if label_p2_health:
			label_p2_health.text = "P2 Salud: " + str(gm.p2_health)

func _on_score_updated(nuevo_puntaje: int) -> void:
	if label_score:
		label_score.text = "Puntaje: " + str(nuevo_puntaje)

func mostrar_mensaje_transicion(texto: String) -> void:
	if label_mensaje:
		label_mensaje.text = texto
		label_mensaje.visible = true
