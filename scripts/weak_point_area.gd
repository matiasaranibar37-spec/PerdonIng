extends Area3D
## Zona débil del jefe. Si no se asignó boss_ref en el editor, lo busca solo
## subiendo por el árbol hasta encontrar el nodo que sabe recibir daño de punto débil.

@export var boss_ref: Node

func _ready() -> void:
	if boss_ref == null:
		var n: Node = get_parent()
		while n != null and not n.has_method("recibir_disparo_punto_debil"):
			n = n.get_parent()
		boss_ref = n

func recibir_disparo(jugador_id: String) -> void:
	if boss_ref and boss_ref.has_method("recibir_disparo_punto_debil"):
		boss_ref.recibir_disparo_punto_debil(jugador_id)

func recibir_dano(_cantidad: int) -> void:
	recibir_disparo("1")
