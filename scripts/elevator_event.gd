extends Node3D
## Evento del ascensor (final del nivel 1).
##
## Secuencia:
##  1. Código correcto -> CINEMÁTICA 1 (animación "zombie_ambush"): se abren las puertas,
##     el zombie nos mira y grita, la cámara recorre los objetos y aparece el mensaje
##     "Elige un objeto para defenderte del zombie".
##  2. Los jugadores eligen un objeto (disparándole) y recién ahí el zombie ataca: PELEA.
##  3. Al morir el zombie -> CINEMÁTICA 2 (animación "elevator_fall"): el ascensor tiembla
##     y cae, aparece "Nivel uno superado", la pantalla se oscura y pasamos al siguiente nivel.

# Referencias a los nodos de la escena
@onready var door_left: Node3D = get_node_or_null("DoorLeft")
@onready var door_right: Node3D = get_node_or_null("DoorRight")
@onready var zombie_emboscada: Node3D = _buscar_zombie()
@onready var puzzle_ui: CanvasLayer = get_node_or_null("InteractivePuzzle")  # Teclado numérico
@onready var puzzle_objects: Node3D = get_node_or_null("PuzzleObjects")      # Objetos 3D interactivos a elegir
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var camara_cinematica: Camera3D = get_node_or_null("Camera3D")

# Interfaz
@onready var capa_ui: CanvasLayer = get_node_or_null("CanvasLayer")
@onready var label_mensaje: Label = get_node_or_null("CanvasLayer/LabelMensaje")
@onready var label_nivel_superado: Label = get_node_or_null("CanvasLayer/LabelMensaje2")
@onready var color_rect_fade: ColorRect = get_node_or_null("CanvasLayer/ColorRectFade")

# Textos (sin signos ni tildes especiales porque la fuente 28 Days Later no los tiene)
@export var mensaje_elegir_objeto: String = "Choose an object to defend yourself against the zombie"
@export var mensaje_nivel_superado: String = "Level One Completed"

# Tiempos editables desde el Inspector
@export var espera_tras_muerte_zombie: float = 1.5  # Deja ver la animación de muerte del zombie
@export var duracion_oscurecer: float = 1.2         # Cuánto tarda la pantalla en quedar negra
@export var espera_pantalla_negra: float = 1.5      # Pausa en negro antes de cambiar de nivel
## Si es true, durante las cinemáticas se usa la Camera3D del ascensor (la de la animación).
@export var usar_camara_cinematica: bool = true

# Enumeración de los 3 objetos de la emboscada
enum Objeto { EXTINTOR, TUBO_PLASTICO, PLUMON }
const OBJETO_CORRECTO = Objeto.EXTINTOR

var secuencia_iniciada: bool = false
var combate_activo: bool = false      # true mientras se espera que elijan un objeto
var pelea_activa: bool = false
var evento_completado: bool = false
var objeto_elegido: int = -1
var camara_juego: Camera3D = null     # La cámara normal del nivel (la del riel)


func _buscar_zombie() -> Node3D:
	# En la escena el zombie se llama "CharacterBody3D"; también aceptamos "ZombieEmboscada"
	var z: Node3D = get_node_or_null("ZombieEmboscada")
	if z == null:
		z = get_node_or_null("CharacterBody3D")
	return z


func _ready() -> void:
	# Los objetos 3D y el interruptor encuentran este nodo por el grupo
	add_to_group("elevator_event")

	# El interruptor del teclado brilla al apuntarlo (hasta que empieza la secuencia)
	var interruptor: Node = get_node_or_null("Elevator_switch")
	if interruptor:
		interruptor.add_to_group("interactuable")

	# --- El zombie empieza "dormido": invisible, quieto, sin colisión y sin sonido ---
	if zombie_emboscada:
		zombie_emboscada.hide()
		zombie_emboscada.set_physics_process(false)
		_set_colision_zombie(false)
		if "audio_player" in zombie_emboscada and zombie_emboscada.audio_player:
			zombie_emboscada.audio_player.stop()
		if "run_audio_player" in zombie_emboscada and zombie_emboscada.run_audio_player:
			zombie_emboscada.run_audio_player.stop()

	if puzzle_objects:
		puzzle_objects.hide()

	# --- Interfaz: por encima del HUD, sin bloquear clics ---
	if capa_ui:
		capa_ui.layer = 50
	if label_mensaje:
		label_mensaje.hide()
		label_mensaje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if label_nivel_superado:
		label_nivel_superado.hide()
		label_nivel_superado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color_rect_fade:
		color_rect_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect_fade.self_modulate = Color(1, 1, 1, 0)  # Transparente al inicio
		color_rect_fade.show()

	# Escuchar cuando se resuelva la clave de 3 dígitos
	if puzzle_ui:
		puzzle_ui.hide()
		if puzzle_ui.has_signal("codigo_correcto"):
			if not puzzle_ui.codigo_correcto.is_connected(abrir_puertas):
				puzzle_ui.codigo_correcto.connect(abrir_puertas)


# Función llamada por el interruptor para desplegar la UI
func activar_teclado_puzzle() -> void:
	if puzzle_ui and not secuencia_iniciada:
		puzzle_ui.show()


# ==========================================
# 1. CINEMÁTICA 1: PUERTAS + ZOMBIE + OBJETOS
# ==========================================
# Se llama cuando el jugador acierta el código del teclado numérico
func abrir_puertas() -> void:
	if secuencia_iniciada:
		return
	secuencia_iniciada = true
	var interruptor_usado: Node = get_node_or_null("Elevator_switch")
	if interruptor_usado:
		interruptor_usado.remove_from_group("interactuable")
	print("Código correcto: empieza la cinemática del ascensor.")

	if puzzle_ui:
		puzzle_ui.hide()

	# Los objetos se ven durante la cinemática (la animación los baja al suelo)
	if puzzle_objects:
		puzzle_objects.show()

	_usar_camara_cinematica(true)

	if anim_player and anim_player.has_animation("zombie_ambush"):
		anim_player.play("zombie_ambush")
		# La cinemática termina cuando acaba la animación
		await anim_player.animation_finished
	else:
		push_warning("No se encontró la animación 'zombie_ambush'. Usando alternativa.")
		if zombie_emboscada:
			zombie_emboscada.show()
		await get_tree().create_timer(1.0).timeout

	_usar_camara_cinematica(false)
	_iniciar_fase_eleccion()


func _iniciar_fase_eleccion() -> void:
	combate_activo = true
	_marcar_objetos_interactuables(true)

	if label_mensaje:
		label_mensaje.text = mensaje_elegir_objeto
		label_mensaje.show()

	if puzzle_objects:
		puzzle_objects.show()
		# Si no hay animación que baje los objetos al suelo, lo hacen ellos mismos
		var anim_ya_los_movio := anim_player and anim_player.has_animation("zombie_ambush")
		if not anim_ya_los_movio:
			for objeto in puzzle_objects.get_children():
				if objeto.has_method("iniciar_efecto_flotacion"):
					objeto.iniciar_efecto_flotacion()


# ==========================================
# 2. ELECCIÓN DEL OBJETO Y PELEA
# ==========================================
# Lo llaman los objetos 3D cuando un jugador les dispara
func seleccionar_objeto(objeto_elegido_tipo: Objeto) -> void:
	if not combate_activo:
		return

	combate_activo = false
	_marcar_objetos_interactuables(false)
	objeto_elegido = objeto_elegido_tipo

	if label_mensaje:
		label_mensaje.hide()
	if puzzle_objects:
		puzzle_objects.hide()

	print("Objeto elegido: ", objeto_elegido, ". ¡El zombie ataca!")
	_iniciar_pelea()


func _iniciar_pelea() -> void:
	pelea_activa = true

	if zombie_emboscada == null:
		push_warning("No hay zombie en el ascensor; se salta la pelea.")
		_on_zombie_muerto()
		return

	zombie_emboscada.show()
	_set_colision_zombie(true)

	# El zombie debe perseguir a la cámara del juego (no a la cinemática)
	var cam := camara_juego if is_instance_valid(camara_juego) else get_viewport().get_camera_3d()
	if cam:
		zombie_emboscada.set("target_node", cam)

	# Despertamos al zombie: ya nos ha detectado y ataca
	zombie_emboscada.set("is_player_detected", true)
	zombie_emboscada.set("can_attack", true)
	zombie_emboscada.set_physics_process(true)

	# Avisa cuando muere
	if zombie_emboscada.has_signal("died"):
		if not zombie_emboscada.is_connected("died", _on_zombie_muerto):
			zombie_emboscada.connect("died", _on_zombie_muerto, CONNECT_ONE_SHOT)
	else:
		_vigilar_muerte_zombie()


# Alternativa por si el zombie no tiene la señal "died"
func _vigilar_muerte_zombie() -> void:
	while is_instance_valid(zombie_emboscada) and not zombie_emboscada.get("is_dead"):
		await get_tree().create_timer(0.2).timeout
	_on_zombie_muerto()


func _set_colision_zombie(activa: bool) -> void:
	if zombie_emboscada == null:
		return
	var shape := zombie_emboscada.get_node_or_null("CollisionShape3D")
	if shape:
		shape.set_deferred("disabled", not activa)


# ==========================================
# 3. CINEMÁTICA 2: EL ASCENSOR CAE Y PANTALLA NEGRA
# ==========================================
func _on_zombie_muerto() -> void:
	if evento_completado:
		return
	evento_completado = true
	pelea_activa = false
	print("Zombie eliminado: empieza la cinemática de caída.")

	# Dejamos ver la animación de muerte del zombie
	await get_tree().create_timer(espera_tras_muerte_zombie).timeout

	_usar_camara_cinematica(false)

	if anim_player and anim_player.has_animation("elevator_fall"):
		anim_player.play("elevator_fall")
		await anim_player.animation_finished
	else:
		await get_tree().create_timer(2.0).timeout

	await _mostrar_nivel_superado_y_oscurecer()
	_ir_al_siguiente_nivel()


func _mostrar_nivel_superado_y_oscurecer() -> void:
	if label_nivel_superado:
		label_nivel_superado.text = mensaje_nivel_superado
		label_nivel_superado.show()

	if color_rect_fade:
		color_rect_fade.show()
		# La animación deja la pantalla a medias (alpha ~0.6): la llevamos a negro total
		var tween := create_tween()
		tween.tween_property(color_rect_fade, "self_modulate:a", 1.0, duracion_oscurecer)
		await tween.finished

	await get_tree().create_timer(espera_pantalla_negra).timeout


func _ir_al_siguiente_nivel() -> void:
	var nivel := get_parent()
	if nivel and nivel.has_method("ir_al_siguiente_nivel"):
		nivel.ir_al_siguiente_nivel()
	else:
		push_warning("El nivel no tiene ir_al_siguiente_nivel().")


# ==========================================
# CÁMARA DE LA CINEMÁTICA
# ==========================================
func _usar_camara_cinematica(activar: bool) -> void:
	if not usar_camara_cinematica or camara_cinematica == null:
		return
	if activar:
		camara_juego = get_viewport().get_camera_3d()
		camara_cinematica.make_current()
	elif is_instance_valid(camara_juego):
		camara_juego.make_current()


# Los 3 objetos (extintor, tubo, plumón) brillan al apuntarlos solo mientras se puede elegir uno
func _marcar_objetos_interactuables(activo: bool) -> void:
	if puzzle_objects == null:
		return
	for objeto in puzzle_objects.get_children():
		if activo:
			objeto.add_to_group("interactuable")
		else:
			objeto.remove_from_group("interactuable")
