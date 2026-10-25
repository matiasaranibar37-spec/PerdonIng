extends Area3D

# Señal emitida cuando el puntero del P1 o P2 le dispara a la computadora
signal computadora_disparada

@export var puzzle_ui: CanvasLayer # Opcional: si lo asignas, se muestra al disparar
## Si es false no recibe disparos ni brilla (el nivel la habilita cuando toca).
@export var habilitado: bool = true:
	set(valor):
		habilitado = valor
		collision_layer = 1 if valor else 0


func _ready() -> void:
	# Grupo 'interactuable' para que el brillo la detecte; 'library_computer' para encontrarla
	add_to_group("interactuable")
	add_to_group("library_computer")
	collision_layer = 1 if habilitado else 0


func puede_interactuar() -> bool:
	return habilitado


# Función invocada automáticamente por el disparo del jugador
func recibir_disparo(jugador_id: String = "") -> void:
	if not habilitado:
		return
	print("¡Jugador ", jugador_id, " disparó a la computadora de la biblioteca!")

	if puzzle_ui:
		puzzle_ui.show()

	computadora_disparada.emit()
