extends Camera3D

@export var lock_rotation_x: bool = true
@export var fixed_pitch_angle: float = -5.0 # Inclinación leve hacia abajo en grados

@export_group("Seguimiento del jefe (LookAt dinámico)")
@export var boss_ref: Node3D
## Qué tan rápido gira la cámara hacia el jefe (más alto = más pegada al jefe)
@export var look_smooth_speed: float = 4.0
## El origen del jefe está en sus pies; esto sube el punto de mira hacia su pecho
@export var look_height_offset: float = 1.4

var tracking_boss: bool = false

var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0


func _process(delta: float) -> void:
	if tracking_boss and is_instance_valid(boss_ref):
		# La cámara se queda en su punto del riel pero gira sobre sus ejes para
		# mantener al jefe en el centro de la pantalla.
		var focus: Vector3 = boss_ref.global_position + Vector3(0.0, look_height_offset, 0.0)
		if focus.distance_to(global_position) > 0.1:
			var gt: Transform3D = global_transform
			var target_basis: Basis = gt.looking_at(focus, Vector3.UP).basis
			var weight: float = 1.0 - exp(-look_smooth_speed * delta)
			gt.basis = gt.basis.orthonormalized().slerp(target_basis, weight)
			global_transform = gt
	else:
		# Mantiene el horizonte nivelado estándar cuando no rastrea al jefe
		if lock_rotation_x:
			rotation_degrees.x = fixed_pitch_angle
		rotation_degrees.z = 0.0
	_update_shake(delta)


func start_tracking_boss(boss_node: Node3D) -> void:
	boss_ref = boss_node
	tracking_boss = true

func stop_tracking_boss() -> void:
	tracking_boss = false

func is_tracking_boss() -> bool:
	return tracking_boss


# Sacudida de cámara (cuando el jefe conecta su embestida)
func shake(strength: float = 0.25, duration: float = 0.35) -> void:
	_shake_strength = strength
	_shake_duration = maxf(duration, 0.01)
	_shake_time = _shake_duration

func _update_shake(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var k: float = maxf(_shake_time, 0.0) / _shake_duration
		h_offset = randf_range(-1.0, 1.0) * _shake_strength * k
		v_offset = randf_range(-1.0, 1.0) * _shake_strength * k
	elif h_offset != 0.0 or v_offset != 0.0:
		h_offset = 0.0
		v_offset = 0.0
