extends Node
## Música de los menús (menú principal y menú de pausa).
## Autoload único: existe un solo reproductor durante toda la ejecución, así que
## nunca se duplica ni se superpone al volver al menú. El estado se decide en
## cada frame a partir de lo que realmente se ve en pantalla, de modo que
## cualquier camino (reanudar, reiniciar, cargar partida, salir al menú, etc.)
## deja la música en el estado correcto sin tocar los scripts de los menús.

const MUSIC_PATH: String = "res://assets/sounds/menu_theme.mp3"
const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

var _player: AudioStreamPlayer
var _wanted: bool = false


func _ready() -> void:
	# Debe seguir procesándose con get_tree().paused = true (menú de pausa)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "MenuMusicPlayer"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

	var stream: AudioStream = load(MUSIC_PATH) as AudioStream
	if stream == null:
		push_error("MenuMusic: no se pudo cargar " + MUSIC_PATH)
		set_process(false)
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_player.stream = stream
	# Respaldo del bucle por si el formato no lo soporta de forma nativa
	_player.finished.connect(_on_finished)


func _process(_delta: float) -> void:
	_wanted = _is_menu_visible()
	if _wanted and not _player.playing:
		_player.play()
	elif not _wanted and _player.playing:
		_player.stop()


func _on_finished() -> void:
	if _wanted:
		_player.play()


func _is_menu_visible() -> bool:
	var tree: SceneTree = get_tree()
	var scene: Node = tree.current_scene

	# Menú principal (escena propia o MainMenu dentro de main.tscn)
	if scene != null:
		if scene.scene_file_path == MAIN_MENU_SCENE:
			return true
		var embedded_menu: Node = scene.get_node_or_null("MainMenu")
		if embedded_menu is Control and (embedded_menu as Control).visible:
			return true

	# Menú de pausa: solo cuando el juego está pausado y el menú está visible
	if tree.paused:
		for node in tree.get_nodes_in_group("pause_menu"):
			if node is CanvasLayer and (node as CanvasLayer).visible:
				return true

	return false
