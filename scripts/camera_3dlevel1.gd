extends Camera3D

@export var lock_rotation_x: bool = true
@export var fixed_pitch_angle: float = -5.0 # Inclinación leve hacia abajo en grados

func _process(_delta: float) -> void:
	# Mantiene el horizonte nivelado anulando balanceos en Z y bloqueando X
	if lock_rotation_x:
		rotation_degrees.x = fixed_pitch_angle
	rotation_degrees.z = 0.0
