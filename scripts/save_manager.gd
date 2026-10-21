extends Node

const SAVE_PATH: String = "user://savegame.json"
var pending_data: Dictionary = {}

func save_game(player: Node, level_path: String) -> bool:
	var current_score: int = 0
	var current_p1_kills: int = 0
	var current_p2_kills: int = 0
	
	if get_node_or_null("/root/GameManager"):
		current_score = GameManager.score
		current_p1_kills = GameManager.p1_kills
		current_p2_kills = GameManager.p2_kills

	var data: Dictionary = {
		"version": 1,
		"level_path": level_path,
		"health": player.health if "health" in player else 100,
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"position_z": player.global_position.z,
		"score": current_score,
		"p1_kills": current_p1_kills,
		"p2_kills": current_p2_kills
	}
	
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar la partida")
		return false
		
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Partida guardada correctamente en: ", SAVE_PATH)
	return true

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No existe un archivo de partida guardada.")
		return
		
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el archivo de guardado.")
		return
		
	var json_text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_error("Archivo de guardado inválido.")
		return
		
	var data: Dictionary = parsed
	var level_path: String = str(data.get("level_path", ""))
	
	if level_path.is_empty() or not ResourceLoader.exists(level_path):
		push_error("El nivel guardado no existe o la ruta está vacía: " + level_path)
		return
		
	pending_data = data
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(level_path)

func apply_save_data(player: Node) -> void:
	if pending_data.is_empty():
		return
		
	# 1. Restaurar Posición 3D del Jugador
	player.global_position = Vector3(
		float(pending_data.get("position_x", 0.0)),
		float(pending_data.get("position_y", 0.0)),
		float(pending_data.get("position_z", 0.0))
	)
	
	# 2. Restaurar Puntuación, Kills y Salud en GameManager
	if get_node_or_null("/root/GameManager"):
		GameManager.score = int(pending_data.get("score", 0))
		GameManager.p1_kills = int(pending_data.get("p1_kills", 0))
		GameManager.p2_kills = int(pending_data.get("p2_kills", 0))
		
		var saved_health = int(pending_data.get("health", 100))
		GameManager.p1_health = saved_health
		
		# Emite las señales para actualizar el HUD de inmediato
		GameManager.score_updated.emit(GameManager.score)
		GameManager.kills_updated.emit(GameManager.p1_kills, GameManager.p2_kills)
		GameManager.health_updated.emit(GameManager.p1_health, GameManager.p2_health)

	# 3. Actualizar la variable interna de salud en el nodo del jugador si la tiene
	if "health" in player:
		player.health = int(pending_data.get("health", 100))

	pending_data.clear()
	print("Datos de guardado aplicados exitosamente al jugador y GameManager.")
