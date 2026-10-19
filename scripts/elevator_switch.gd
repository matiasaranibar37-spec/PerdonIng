extends Area3D

signal interruptor_disparado

@export var puzzle_ui: CanvasLayer # Arrastra la escena InteractivePuzzle aquí en el Inspector

# Esta función es invocada por el pointer_manager al hacer clic/disparar
func recibir_disparo(_jugador_id: String) -> void:
	print("¡Interruptor disparado! Mostrando teclado numérico.")
	
	if puzzle_ui:
		puzzle_ui.show()
	
	interruptor_disparado.emit()
