extends CanvasLayer

signal musica_encendida

@onready var btn_activar: Button = $Control/VentanaPanel/VBoxContainer/BtnActivarMusica

func _ready() -> void:
	hide() # Nace oculto hasta que le disparan a la computadora 3D
	
	if btn_activar:
		btn_activar.pressed.connect(_on_btn_activar_pressed)

# Conectado al botón en pantalla
func _on_btn_activar_pressed() -> void:
	print("¡Música de distracción encendida desde la UI!")
	musica_encendida.emit()
	hide()

# Soporte para clics con los punteros arcade de P1 y P2 (vía PointerManager)
func _input(event: InputEvent) -> void:
	if not visible or btn_activar == null:
		return
		
	var pos_p1 = GameManager.p1_pointer_position if "p1_pointer_position" in GameManager else Vector2.ZERO
	var pos_p2 = GameManager.p2_pointer_position if "p2_pointer_position" in GameManager else Vector2.ZERO

	if event.is_action_pressed("p1_fire") and btn_activar.get_global_rect().has_point(pos_p1):
		_on_btn_activar_pressed()
	elif event.is_action_pressed("p2_fire") and btn_activar.get_global_rect().has_point(pos_p2):
		_on_btn_activar_pressed()
