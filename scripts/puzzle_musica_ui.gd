extends CanvasLayer
## Ventana "LIBRARY AUDIO SYSTEM": el jugador dispara al botón ACTIVATE (con el puntero de P1 o P2)
## y se emite "musica_encendida".

signal musica_encendida

@onready var btn_activar: Button = get_node_or_null("Control/windowPanel/VBoxContainer/MusicActivation")

var _activada: bool = false


func _ready() -> void:
	# Mientras esta ventana está visible, los disparos NO llegan al mundo 3D (ver pointer_manager.gd)
	add_to_group("ui_bloquea_disparo")
	hide()

	if btn_activar:
		btn_activar.pressed.connect(_activar)
	else:
		push_warning("PuzzleMusicaUI: no se encontró el botón Control/windowPanel/VBoxContainer/MusicActivation")

	# Los punteros (P1 con mouse/táctil, P2 con teclado o mando) avisan dónde dispararon
	_conectar_punteros.call_deferred()


func _conectar_punteros() -> void:
	var pm: Node = get_tree().get_first_node_in_group("pointer_manager")
	if pm and pm.has_signal("disparo") and not pm.is_connected("disparo", _on_disparo):
		pm.connect("disparo", _on_disparo)


func mostrar() -> void:
	_activada = false
	show()


func _on_disparo(_jugador_id: int, posicion: Vector2) -> void:
	if visible and btn_activar and btn_activar.get_global_rect().has_point(posicion):
		_activar()


func _activar() -> void:
	if _activada or not visible:
		return
	_activada = true
	print("Música de distracción activada desde la ventana de audio.")
	hide()
	musica_encendida.emit()
