extends Node

# Señales para notificar cambios a la interfaz de usuario (HUD) y al sistema de juego
signal score_updated(new_score: int)
signal level_change_requested(scene_path: String)
signal kills_updated(p1_kills: int, p2_kills: int)
signal health_updated(p1_hp: int, p2_hp: int)
signal game_over_triggered(dead_player_id: int)

# Variables globales de estado y puntuación
var score: int = 0
var p1_kills: int = 0
var p2_kills: int = 0
var p1_health: int = 100
var p2_health: int = 100
var is_game_over: bool = false
# Cantidad de jugadores seleccionada en el menú: 1 o 2.
var player_count: int = 1

const GAME_OVER_SCENE: String = "res://scenes/game_over.tscn"

# Selección de personajes desde el menú inicial
var p1_character: Dictionary = {"id": "default", "name": "Jugador 1", "health": 100}
var p2_character: Dictionary = {"id": "default", "name": "Jugador 2", "health": 100}


func add_score(amount: int = 1) -> void:
	score += amount
	score_updated.emit(score)


func add_kill(player_id: String, points: int = 100) -> void:
	score += points
	
	var id_clean = str(player_id).to_upper().strip_edges()
	
	if id_clean == "2" or id_clean == "P2" or id_clean == "PLAYER2":
		p2_kills += 1
	else:
		# Asigna a P1 para los valores "1", "P1", "PLAYER1" o por defecto
		p1_kills += 1

	print("Zombie eliminado. Kills P1: ", p1_kills, " | Kills P2: ", p2_kills)

	# Emitir señales para actualizar el HUD
	score_updated.emit(score)
	kills_updated.emit(p1_kills, p2_kills)

func update_player_health(player_id: int, new_health: int) -> void:
	if player_id == 1:
		p1_health = new_health
	elif player_id == 2:
		p2_health = new_health
		
	health_updated.emit(p1_health, p2_health)

	# Si la vida de un jugador llega a 0, termina la partida
	if new_health <= 0:
		trigger_game_over(player_id)


func trigger_game_over(dead_player_id: int) -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over_triggered.emit(dead_player_id)

	var scene: PackedScene = load(GAME_OVER_SCENE)
	if scene == null:
		push_error("No se encontró la escena de Game Over: " + GAME_OVER_SCENE)
		return
	var screen: Node = scene.instantiate()
	screen.set("dead_player_id", dead_player_id)
	get_tree().root.add_child.call_deferred(screen)
	get_tree().paused = true


func reset_health_for_new_level() -> void:
	p1_health = int(p1_character.get("health", 100))
	p2_health = int(p2_character.get("health", 100))
	health_updated.emit(p1_health, p2_health)


func reset_game() -> void:
	is_game_over = false
	score = 0
	p1_kills = 0
	p2_kills = 0
	reset_health_for_new_level()
	score_updated.emit(score)
	kills_updated.emit(p1_kills, p2_kills)


func change_level(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("No existe la escena: " + scene_path)
		return
		
	level_change_requested.emit(scene_path)
	reset_health_for_new_level()
	get_tree().change_scene_to_file(scene_path)


func check_level_complete(required_score: int, next_scene: String) -> bool:
	if score >= required_score:
		change_level(next_scene)
		return true
	return false


func set_character_selection(character_p1: Dictionary, character_p2: Dictionary) -> void:
	p1_character = character_p1.duplicate(true)
	p2_character = character_p2.duplicate(true)
	p1_health = int(p1_character.get("health", 100))
	p2_health = int(p2_character.get("health", 100))
	score_updated.emit(score)
	health_updated.emit(p1_health, p2_health)
