extends Node

signal score_updated(new_score: int)
signal level_change_requested(scene_path: String)

var score: int = 0
var p1_health: int = 100
var p2_health: int = 100

func add_score(amount: int = 1) -> void:
	score += amount
	score_updated.emit(score)

func reset_game() -> void:
	score = 0
	p1_health = 100
	p2_health = 100
	score_updated.emit(score)

func change_level(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("No existe la escena: " + scene_path)
		return
	get_tree().change_scene_to_file(scene_path)

func check_level_complete(required_score: int, next_scene: String) -> bool:
	if score >= required_score:
		change_level(next_scene)
		return true
	return false
