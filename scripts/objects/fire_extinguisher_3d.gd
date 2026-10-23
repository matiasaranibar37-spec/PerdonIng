extends Area3D

enum Objeto { EXTINTOR, TUBO_PLASTICO, PLUMON }
@export var tipo_objeto: Objeto = Objeto.EXTINTOR

var posicion_inicial: Vector3

func _ready() -> void:
	# Nos aseguramos de que el área esté lista para detectar colisiones
	monitoring = true
	monitorable = true
	posicion_inicial = position

# Esta función se llama cuando se abren las puertas del ascensor
func iniciar_efecto_flotacion() -> void:
	var tween = create_tween().set_parallel(true)
	
	# Restamos una distancia menor (ejemplo: -0.3 m en lugar de -0.6 m)
	# para que descanse sobre la cara superior del suelo del ascensor
	var pos_suelo_y = posicion_inicial.y - 0.35
	
	# 1. Caída suave hacia la superficie del suelo
	tween.tween_property(self, "position:y", pos_suelo_y, 0.35)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	
	# 2. Inclinación tumbada (acostado de lado)
	tween.tween_property(self, "rotation_degrees:z", 85.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

# 1. Función llamada si los jugadores (PlayerP1 / PlayerP2) usan raycast directo al disparar
func recibir_disparo(_jugador_id: String = "") -> void:
	_al_recibir_disparo()

func recibir_dano(_cantidad: int = 1) -> void:
	_al_recibir_disparo()

# 2. Detección alternativa mediante las coordenadas del puntero en pantalla
func _input(_event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if Input.is_action_just_pressed("p1_fire") or Input.is_action_just_pressed("p2_fire"):
		var pos_mira = get_viewport().get_mouse_position()
		
		if get_node_or_null("/root/GameManager") and GameManager.p1_pointer_position != Vector2.ZERO:
			pos_mira = GameManager.p1_pointer_position

		_verificar_impacto_pantalla(pos_mira)

func _verificar_impacto_pantalla(screen_pos: Vector2) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_normal = camera.project_ray_normal(screen_pos)
	var ray_end = ray_origin + ray_normal * 1000.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	
	# Habilitar explícitamente colisión con Áreas y Cuerpos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("Raycast de pantalla tocó: ", result.collider.name)
		if result.collider == self:
			_al_recibir_disparo()

func _al_recibir_disparo() -> void:
	print("¡EXTINTOR SELECCIONADO CORRECTAMENTE!")
	
	# Notificar a la escena del ascensor
	var elevador = get_tree().get_first_node_in_group("elevator_event")
	if elevador and elevador.has_method("seleccionar_objeto"):
		elevador.seleccionar_objeto(tipo_objeto)
	else:
		print("ERROR: No se encontró la escena 'elevator_event' en los grupos.")
		
