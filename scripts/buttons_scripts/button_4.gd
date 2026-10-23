# Adjunta este script a los botones Button1..Button9 de KeypadGrid
extends Button

@export var numero_digito: String = "1" # Asigna "1", "2", "3", etc., en el Inspector

func _input(_event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
		
	# Detección del impacto de disparo de P1 o P2 mediante GameManager
	if Input.is_action_just_pressed("p1_fire"):
		if get_global_rect().has_point(GameManager.p1_pointer_position):
			_procesar_impacto()
	elif Input.is_action_just_pressed("p2_fire"):
		if get_global_rect().has_point(GameManager.p2_pointer_position):
			_procesar_impacto()

func _procesar_impacto() -> void:
	var puzzle_padre = owner # Obtiene la raíz CanvasLayer (InteractivePuzzle)
	if puzzle_padre and puzzle_padre.has_method("presionar_numero"):
		puzzle_padre.presionar_numero(numero_digito)
