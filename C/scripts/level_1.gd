extends Node3D

@export var interruptores_necesarios: int = 3
@export_file("*.tscn") var siguiente_nivel: String = "res://level/level_2.tscn"

var interruptores_activados: int = 0
var nivel_completado := false

@onready var hud = $HUD

func _ready() -> void:
	# Busca todos los nodos agregados al grupo "switches" (o cilindros/interactuables del nivel)
	var interruptores = get_tree().get_nodes_in_group("switches")
	
	for interruptor in interruptores:
		if interruptor.has_signal("activado"):
			# Verifica si no está conectado antes para evitar conexiones dobles
			if not interruptor.activado.is_connected(_on_interruptor_activado):
				interruptor.activado.connect(_on_interruptor_activado)

func _on_interruptor_activado() -> void:
	interruptores_activados += 1
	print("Interruptores activados: ", interruptores_activados, "/", interruptores_necesarios)

	if interruptores_activados >= interruptores_necesarios:
		completar_nivel_1()

func completar_nivel_1() -> void:
	if nivel_completado:
		return
	nivel_completado = true

	# Notifica al HUD si la función existe
	if hud and hud.has_method("mostrar_mensaje_transicion"):
		hud.mostrar_mensaje_transicion("¡Acertijo resuelto! Pasando al Nivel 2...")

	await get_tree().create_timer(2.0).timeout

	# Cambia de nivel utilizando el GameManager Autoload o la carga directa
	if get_node_or_null("/root/GameManager"):
		GameManager.change_level(siguiente_nivel)
	elif ResourceLoader.exists(siguiente_nivel):
		get_tree().change_scene_to_file(siguiente_nivel)
	else:
		print("Crea la escena del siguiente nivel en la ruta: ", siguiente_nivel)
