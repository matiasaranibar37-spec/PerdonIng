#extends TextureButton
#
## Exportamos el tipo de objeto para asignarlo individualmente en el Inspector
#@export var tipo_objeto: ElevatorEvent.Objeto
#
#func _input(_event: InputEvent) -> void:
	## Si la UI no está visible, no procesamos clics
	#if not is_visible_in_tree():
		#return
		#
	## Detección del disparo del Jugador 1 o Jugador 2
	#if Input.is_action_just_pressed("p1_fire"):
		#if get_global_rect().has_point(GameManager.p1_pointer_position):
			#_procesar_impacto()
			#
	#elif Input.is_action_just_pressed("p2_fire"):
		#if get_global_rect().has_point(GameManager.p2_pointer_position):
			#_procesar_impacto()
#
#func _procesar_impacto() -> void:
	## Busca el nodo raíz ElevatorEvent para notificar la elección
	#var elevador = owner
	#if elevador and elevador.has_method("seleccionar_objeto"):
		#elevador.seleccionar_objeto(tipo_objeto)
