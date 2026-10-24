extends Area3D

# Señal emitida cuando el puntero del P1 o P2 le dispara a la computadora
signal computadora_disparada

@export var puzzle_ui: CanvasLayer # Asigna PuzzleMusicaUI en el Inspector si aplica

func _ready() -> void:
	# Agregamos la computadora al grupo 'interactuable' para que el PointerManager/Brillo la detecte
	add_to_group("interactuable")

# Función invocada automáticamente por el PointerManager al dispararle
func recibir_disparo(jugador_id: String) -> void:
	print("¡Jugador ", jugador_id, " disparó a la computadora de la biblioteca!")
	
	if puzzle_ui:
		puzzle_ui.show()
		
	computadora_disparada.emit()
