extends Area3D

signal weapon_picked_up

func _ready() -> void:
	monitoring = true
	# 1. Asegurar que esté en el grupo para que tu gestor de brillo lo reconozca
	add_to_group("interactuable")

func _process(delta: float) -> void:
	# Rotación flotante continua dentro de la cafetería
	rotate_y(deg_to_rad(60.0) * delta)

# Método de verificación para tu gestor de brillo
func puede_interactuar() -> bool:
	return is_visible_in_tree()

# Métodos que se ejecutan cuando el jugador le dispara a la pistola
func recibir_disparo(_jugador_id: String) -> void:
	recibir_dano(1)

func recibir_dano(_cantidad: int) -> void:
	print("¡Pistola 3D impactada y obtenida!")
	weapon_picked_up.emit()
	queue_free()
