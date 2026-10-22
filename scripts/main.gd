#extends Node3D
#
#@onready var main_menu: Control = $MainMenu
#@onready var pause_menu: CanvasLayer = $PauseMenu
#@onready var hud: CanvasLayer = $HUD
#
#func _ready() -> void:
	## Si arrancamos el juego en main.tscn, mostramos el Menú Principal
	#if main_menu:
		#main_menu.show()
		## Ocultamos la interfaz del juego y pausamos el mundo
		#if hud:
			#hud.hide()
		#if pause_menu:
			#pause_menu.hide()
			#
		## Mantenemos el puntero del SO activo y congelamos el juego 3D de fondo
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		#get_tree().paused = true
#
#func start_game() -> void:
	#if main_menu:
		#main_menu.hide()
	#if hud:
		#hud.show()
	#
	## Despausamos el juego para que los zombies y el jugador se muevan
	#get_tree().paused = false
	#Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

extends Node3D

@onready var main_menu: Control = get_node_or_null("MainMenu")
@onready var pause_menu: CanvasLayer = get_node_or_null("PauseMenu")
@onready var hud: CanvasLayer = get_node_or_null("HUD")

func _ready() -> void:
	# Nos aseguramos de que PauseMenu pueda procesar entradas siempre
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu.hide()

	# Si iniciamos desde el Menú Principal en la escena main
	if main_menu:
		main_menu.show()
		if hud:
			hud.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		# Si se carga el nivel directamente para pruebas
		start_game()

func start_game() -> void:
	if main_menu:
		main_menu.hide()
	if hud:
		hud.show()
	if pause_menu:
		pause_menu.hide()
	
	# Despausamos el juego globalmente para que se muevan enemigos y jugadores
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
