extends Node3D

func _ready() -> void:
	# Busca al jugador por grupo o por nombre e intenta aplicar la partida guardada
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = find_child("Player", true, false)
	if player == null:
		player = find_child("PlayerP1", true, false)
	if player == null:
		player = find_child("player", true, false)
		
	if player:
		SaveManager.apply_save_data(player)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
