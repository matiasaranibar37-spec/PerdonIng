extends Node
## Autoload "RankingManager": guarda y lee el ranking arcade en user://ranking.json.
## Cada partida confirmada se guarda como un registro nuevo; la tabla muestra los 5 mejores.

const RANKING_PATH: String = "user://ranking.json"
const CORRUPT_BACKUP_PATH: String = "user://ranking_corrupt_backup.json"
const TABLE_SIZE: int = 5
const INITIALS_LENGTH: int = 3
const RESULT_WIN: String = "VICTORIA"
const RESULT_LOSS: String = "DERROTA"

## Ruta del archivo; se puede cambiar solo en pruebas automáticas.
var ranking_path: String = RANKING_PATH


# ==========================================================
# AÑADIR RESULTADO
# ==========================================================
## Guarda un registro nuevo. Devuelve el puesto (1 = mejor) que ocupa en la tabla
## o -1 si no se pudo guardar (iniciales inválidas o error de escritura).
func add_entry(initials: String, score: int, kills: int, time_seconds: int, result: String) -> int:
	var clean: String = sanitize_initials(initials)
	if clean.length() != INITIALS_LENGTH:
		push_error("RankingManager: las iniciales deben ser exactamente %d letras A-Z." % INITIALS_LENGTH)
		return -1

	var entries: Array = load_entries()
	var previous: Array = entries.duplicate()
	var entry: Dictionary = {
		"initials": clean,
		"score": maxi(score, 0),
		"kills": maxi(kills, 0),
		"time": maxi(time_seconds, 0),
		"result": result if result == RESULT_WIN else RESULT_LOSS,
		"date": Time.get_datetime_string_from_system(false, true)
	}
	entries.append(entry)
	if not _write_entries(entries):
		return -1

	# Puesto = 1 + cantidad de registros anteriores que son mejores que este
	var rank: int = 1
	for old_entry in previous:
		if _is_better(old_entry, entry):
			rank += 1
	return rank


# ==========================================================
# LEER / ORDENAR
# ==========================================================
## Devuelve hasta 5 registros ordenados (puntos desc, kills desc, tiempo asc).
func get_top() -> Array:
	var sorted_entries: Array = get_sorted(load_entries())
	if sorted_entries.size() > TABLE_SIZE:
		sorted_entries.resize(TABLE_SIZE)
	return sorted_entries


func get_sorted(entries: Array) -> Array:
	var copy: Array = entries.duplicate()
	copy.sort_custom(_is_better)
	return copy


func _is_better(a: Dictionary, b: Dictionary) -> bool:
	var score_a: int = int(a.get("score", 0))
	var score_b: int = int(b.get("score", 0))
	if score_a != score_b:
		return score_a > score_b
	var kills_a: int = int(a.get("kills", 0))
	var kills_b: int = int(b.get("kills", 0))
	if kills_a != kills_b:
		return kills_a > kills_b
	# Menor tiempo primero; un tiempo desconocido (-1, registros antiguos) va al final
	var time_a: int = int(a.get("time", -1))
	var time_b: int = int(b.get("time", -1))
	if time_a < 0:
		time_a = 2147483647
	if time_b < 0:
		time_b = 2147483647
	return time_a < time_b


## Lee todos los registros guardados. Nunca devuelve datos ficticios.
func load_entries() -> Array:
	if not FileAccess.file_exists(ranking_path):
		return []
	var file: FileAccess = FileAccess.open(ranking_path, FileAccess.READ)
	if file == null:
		push_error("RankingManager: no se pudo abrir %s (error %d)." % [ranking_path, FileAccess.get_open_error()])
		return []
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return []

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array):
		push_error("RankingManager: ranking.json está dañado. Se conserva una copia de seguridad.")
		_backup_corrupt_file(text)
		return []

	var result: Array = []
	for item in parsed:
		if item is Dictionary:
			result.append(_normalize_entry(item))
	return result


# Acepta también registros del formato antiguo (campo "name", sin tiempo)
func _normalize_entry(raw: Dictionary) -> Dictionary:
	var initials: String = sanitize_initials(str(raw.get("initials", raw.get("name", ""))))
	if initials.length() > INITIALS_LENGTH:
		initials = initials.substr(0, INITIALS_LENGTH)
	while initials.length() < INITIALS_LENGTH:
		initials += "-"
	var result: String = str(raw.get("result", ""))
	return {
		"initials": initials,
		"score": int(raw.get("score", 0)),
		"kills": int(raw.get("kills", 0)),
		"time": int(raw.get("time", -1)),
		"result": result if (result == RESULT_WIN or result == RESULT_LOSS) else "",
		"date": str(raw.get("date", ""))
	}


# ==========================================================
# UTILIDADES
# ==========================================================
## Solo letras A-Z en mayúsculas (sin tildes, números ni símbolos).
func sanitize_initials(text: String) -> String:
	var out: String = ""
	for ch in text.to_upper():
		var code: int = ch.unicode_at(0)
		if code >= 65 and code <= 90:
			out += ch
	return out


## MM:SS, o HH:MM:SS si supera una hora. Un tiempo desconocido se muestra como --:--.
func format_time(total_seconds: int) -> String:
	if total_seconds < 0:
		return "--:--"
	var hours: int = floori(total_seconds / 3600.0)
	var minutes: int = floori((total_seconds % 3600) / 60.0)
	var seconds: int = total_seconds % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func _write_entries(entries: Array) -> bool:
	var file: FileAccess = FileAccess.open(ranking_path, FileAccess.WRITE)
	if file == null:
		push_error("RankingManager: no se pudo escribir %s (error %d)." % [ranking_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(entries, "\t"))
	file.close()
	return true


func _backup_corrupt_file(text: String) -> void:
	var backup: FileAccess = FileAccess.open(CORRUPT_BACKUP_PATH, FileAccess.WRITE)
	if backup:
		backup.store_string(text)
		backup.close()
