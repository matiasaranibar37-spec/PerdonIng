extends Area3D

#@export var puzzle_ui: CanvasLayer # Arrastrado en el Inspector
#
#func recibir_disparo(_jugador_id: String) -> void:
	#print("¡Interruptor disparado! Mostrando teclado numérico.")
	#if puzzle_ui:
		#puzzle_ui.show()
		#puzzle_ui.visible = true
		#
		# Forzar que el nodo Control y sus hijos también se muestren
		#var control_node = puzzle_ui.get_node_or_null("Control")
		#if control_node:
			#control_node.show()
			#control_node.visible = true
			

func recibir_disparo(_jugador_id: String) -> void:
	print("¡Interruptor disparado! Mostrando teclado numérico.")
	var ascensor_padre = get_parent()
	if ascensor_padre and ascensor_padre.has_method("activar_teclado_puzzle"):
		ascensor_padre.activar_teclado_puzzle()
