extends Area3D

signal activado

var fue_activado: bool = false

@export var puzzle_ui: Node2D # Arrastra la escena interactive_puzzle.tscn aquí en el Inspector

# 1. Función cuando los punteros disparan directamente al objeto
func recibir_disparo(_jugador_id: String) -> void:
	# Muestra la interfaz gráfica del teclado que hizo tu compañero
	if puzzle_ui:
		puzzle_ui.show()
	
	# También procesa la activación/daño del cilindro
	recibir_dano(1)

# 2. Función cuando recibe impacto/daño
func recibir_dano(_cantidad: int) -> void:
	if fue_activado:
		return

	fue_activado = true
	
	# Cambia la escala visual del cilindro como feedback al ser disparado
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.scale = Vector3(0.6, 0.6, 0.6)
		
	activado.emit()

	# Suma puntos al marcador global usando el Singleton
	if get_node_or_null("/root/GameManager"):
		GameManager.add_score(100) # O la cantidad de puntos que asignen por acertijo

	print("¡Interruptor/Llave del acertijo activado!")
