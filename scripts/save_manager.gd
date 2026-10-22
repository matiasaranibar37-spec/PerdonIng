extends Node
## Sistema de guardado: cada partida se guarda en su propio archivo JSON
## dentro de user://saves/. El Load Menu lista todas ellas.

const SAVE_DIR: String = "user://saves"
const LEGACY_SAVE_PATH: String = "user://savegame.json" # formato antiguo (1 solo slot)

# Datos de la partida elegida; el nivel los aplica cuando termina de cargar.
var pending_data: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# ==========================================================
# GUARDAR
# ==========================================================
## `level` es la escena actual del nivel. Si tiene get_save_state(),
## se guarda también su estado interno (zombies vivos, avance, etc.).
func save_game(level: Node) -> bool:
	if level == null:
		push_error("save_game: no hay nivel activo para guardar.")
		return false

	var level_path: String = level.scene_file_path
	if level_path.is_empty():
		push_error("save_game: el nivel actual no tiene scene_file_path.")
		return false

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var slot_number: int = _next_slot_number()
	var now: Dictionary = Time.get_datetime_dict_from_system()

	var data: Dictionary = {
		"version": 2,
		"slot_number": slot_number,
		"slot_name": "Partida %03d" % slot_number,
		"level_path": level_path,
		"level_name": level_path.get_file().get_basename(),
		"date": "%04d-%02d-%02d %02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute],
		"timestamp": Time.get_unix_time_from_system(),
		"score": GameManager.score,
		"p1_kills": GameManager.p1_kills,
		"p2_kills": GameManager.p2_kills,
		"p1_health": GameManager.p1_health,
		"p2_health": GameManager.p2_health,
		"p1_character": GameManager.p1_character,
		"p2_character": GameManager.p2_character,
		"level_state": level.call("get_save_state") if level.has_method("get_save_state") else {}
	}

	var file_path: String = "%s/partida_%03d.json" % [SAVE_DIR, slot_number]
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar la partida en: " + file_path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Partida guardada en: ", ProjectSettings.globalize_path(file_path))
	return true


# ==========================================================
# LISTAR PARTIDAS (para el Load Menu)
# ==========================================================
## Devuelve un Array de Dictionary (la más reciente primero) con:
## slot_name, level_name, health, score, kills, date, file_path
func get_save_history() -> Array:
	var saves: Array = []

	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir:
		for file_name in dir.get_files():
			if file_name.get_extension() != "json":
				continue
			var path: String = "%s/%s" % [SAVE_DIR, file_name]
			var data: Dictionary = _read_json(path)
			if data.is_empty():
				continue
			saves.append(_build_info(data, path))

	# Partida del formato antiguo, si existe
	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		var legacy: Dictionary = _read_json(LEGACY_SAVE_PATH)
		if not legacy.is_empty():
			var info: Dictionary = _build_info(legacy, LEGACY_SAVE_PATH)
			info["slot_name"] = "Partida anterior"
			info["timestamp"] = FileAccess.get_modified_time(LEGACY_SAVE_PATH)
			saves.append(info)

	saves.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	return saves


func has_saves() -> bool:
	return not get_save_history().is_empty()


func _build_info(data: Dictionary, path: String) -> Dictionary:
	var level_path: String = str(data.get("level_path", ""))
	return {
		"slot_name": str(data.get("slot_name", "Partida")),
		"level_name": str(data.get("level_name", level_path.get_file().get_basename())),
		"health": int(data.get("p1_health", data.get("health", 100))),
		"score": int(data.get("score", 0)),
		"kills": int(data.get("p1_kills", 0)) + int(data.get("p2_kills", 0)),
		"date": str(data.get("date", "Sin fecha")),
		"timestamp": float(data.get("timestamp", 0.0)),
		"file_path": path
	}


# ==========================================================
# CARGAR
# ==========================================================
func load_game_from_file(file_path: String) -> void:
	var data: Dictionary = _read_json(file_path)
	if data.is_empty():
		push_error("Archivo de guardado inválido o inexistente: " + file_path)
		return

	var level_path: String = str(data.get("level_path", ""))
	if level_path.is_empty() or not ResourceLoader.exists(level_path):
		push_error("El nivel guardado no existe: " + level_path)
		return

	pending_data = data

	# Restauramos el estado global (puntos, kills, vida y personajes)
	GameManager.score = int(data.get("score", 0))
	GameManager.p1_kills = int(data.get("p1_kills", 0))
	GameManager.p2_kills = int(data.get("p2_kills", 0))
	GameManager.p1_health = int(data.get("p1_health", data.get("health", 100)))
	GameManager.p2_health = int(data.get("p2_health", 100))
	if data.get("p1_character") is Dictionary:
		GameManager.p1_character = data["p1_character"]
	if data.get("p2_character") is Dictionary:
		GameManager.p2_character = data["p2_character"]

	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(level_path)


## Carga la partida más reciente (por compatibilidad).
func load_game() -> void:
	var saves: Array = get_save_history()
	if saves.is_empty():
		print("No existe ninguna partida guardada.")
		return
	load_game_from_file(saves[0]["file_path"])


## Lo llama el nivel al final de su _ready(), cuando ya existe todo.
func apply_save_data(level: Node) -> void:
	if pending_data.is_empty():
		return

	# Re-aplicamos el estado global (el nivel lo reinicia en su _ready)
	GameManager.score = int(pending_data.get("score", 0))
	GameManager.p1_kills = int(pending_data.get("p1_kills", 0))
	GameManager.p2_kills = int(pending_data.get("p2_kills", 0))
	GameManager.p1_health = int(pending_data.get("p1_health", pending_data.get("health", 100)))
	GameManager.p2_health = int(pending_data.get("p2_health", 100))

	GameManager.score_updated.emit(GameManager.score)
	GameManager.kills_updated.emit(GameManager.p1_kills, GameManager.p2_kills)
	GameManager.health_updated.emit(GameManager.p1_health, GameManager.p2_health)

	var level_state: Variant = pending_data.get("level_state", {})
	if level_state is Dictionary and level.has_method("apply_save_state"):
		level.call("apply_save_state", level_state)

	pending_data.clear()
	print("Partida cargada correctamente.")


# ==========================================================
# UTILIDADES
# ==========================================================
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _next_slot_number() -> int:
	var highest: int = 0
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir:
		for file_name in dir.get_files():
			if file_name.get_extension() != "json":
				continue
			var data: Dictionary = _read_json("%s/%s" % [SAVE_DIR, file_name])
			highest = maxi(highest, int(data.get("slot_number", 0)))
	return highest + 1
