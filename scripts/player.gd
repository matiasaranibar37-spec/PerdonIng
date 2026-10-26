extends Node3D
class_name MobilePlayer

@export var player_id: int = 1
@export var camera_path: NodePath
@export var ray_length: float = 100.0
@export var damage: int = 1
@export var points_per_hit: int = 10
@export var tracer_duration: float = 0.09
@export var tracer_color: Color = Color(1.0, 0.72, 0.2, 1.0)

@onready var camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var raycast: RayCast3D = get_node_or_null("RayCast3D") as RayCast3D
var shot_audio: AudioStreamPlayer
var shot_sound: AudioStream = preload("res://assets/sounds/disparo.wav")

func _ready() -> void:
	# Sonido local de disparo, compartido por los controles de este jugador.
	shot_audio = AudioStreamPlayer.new()
	shot_audio.name = "ShotAudio"
	shot_audio.stream = shot_sound
	shot_audio.volume_db = -3.0
	add_child(shot_audio)
	if raycast:
		raycast.enabled = true
		raycast.collision_mask = 1
		raycast.collide_with_areas = true
		raycast.collide_with_bodies = true

func shoot(screen_position: Vector2) -> void:
	if shot_audio != null:
		shot_audio.stop()
		shot_audio.play()
	if camera == null or raycast == null:
		push_warning("Jugador %s: falta Camera3D o RayCast3D." % player_id)
		return
	var viewport_size := get_viewport().get_visible_rect().size
	screen_position.x = clampf(screen_position.x, 0.0, viewport_size.x)
	screen_position.y = clampf(screen_position.y, 0.0, viewport_size.y)
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position).normalized()
	var end_point := ray_origin + ray_direction * ray_length
	raycast.global_position = ray_origin
	raycast.global_basis = Basis.looking_at(ray_direction, Vector3.UP)
	raycast.target_position = Vector3(0.0, 0.0, -ray_length)
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		end_point = raycast.get_collision_point()
		var target: Object = raycast.get_collider()
		if target:
			var hit_enemy := false
			# Identificador del jugador convertido a texto ("1" o "2")
			var pid_str: String = str(player_id)
			
			# Compatibilidad con zombies y enemigos generales
			# Enemigos que necesitan saber DÓNDE los golpeó el disparo (puntos débiles del jefe)
			if target.has_method("recibir_disparo_en_punto"):
				target.call("recibir_disparo_en_punto", pid_str, end_point)
				hit_enemy = true
			elif target.has_method("recibir_disparo"):
				target.call("recibir_disparo", pid_str)
				hit_enemy = true
			elif target.has_method("recibir_dano"):
				target.call("recibir_dano", damage)
				hit_enemy = true
			elif target.has_method("take_damage"):
				target.call("take_damage", damage)
				hit_enemy = true

			# Sumar puntos globales al impacto
			if hit_enemy and get_node_or_null("/root/GameManager"):
				GameManager.add_score(points_per_hit)
	
	_create_shot_effect(ray_origin, end_point, raycast.is_colliding())

func shoot_from_center() -> void:
	shoot(get_viewport().get_visible_rect().size * 0.5)

func _create_shot_effect(from: Vector3, to: Vector3, hit: bool) -> void:
	# Trazador brillante visible durante unos fotogramas.
	var mesh_instance := MeshInstance3D.new()
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate.surface_add_vertex(from)
	immediate.surface_add_vertex(to)
	immediate.surface_end()
	mesh_instance.mesh = immediate
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tracer_color if hit else Color(1.0, 0.9, 0.55, 0.8)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.no_depth_test = true
	mesh_instance.material_override = material
	get_tree().current_scene.add_child(mesh_instance)
	# Pequeño destello en el punto de impacto.
	if hit:
		_create_impact_flash(to)
	await get_tree().create_timer(tracer_duration).timeout
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()

func _create_impact_flash(point: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	flash.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.55, 0.12, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.25, 0.03, 1.0)
	flash.material_override = material
	get_tree().current_scene.add_child(flash)
	flash.global_position = point
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ZERO, 0.12)
	tween.tween_callback(flash.queue_free)
