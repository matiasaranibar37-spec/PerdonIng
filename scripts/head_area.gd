extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
# Esto redirige cualquier disparo que reciba la cabeza hacia la función de headshot del zombie padre
func recibir_disparo(jugador_id: String) -> void:
	if owner.has_method("recibir_disparo_cabeza"):
		owner.recibir_disparo_cabeza(jugador_id)
