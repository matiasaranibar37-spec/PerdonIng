extends PathFollow3D

@export var speed: float = 1.5  # velocidad

# Configuración del Balanceo 
var bob_freq: float = 5  # velocidad de paso
var bob_amp_vertical: float = 0.045 # mov arr aba
var bob_amp_horizontal: float = 0.25 # mov izq der
var bob_amp_tilt: float = 0.1    # inclinacion

var time_passed: float = 0.0

# Altura base de la cámara sobre el riel (el balanceo se suma a este valor).
# En el nivel 1 es 0; level_2.gd la sube para que la cámara no vaya a ras de suelo.
@export var altura_camara: float = 0.0

# level_1.gd lo pone en false cuando un zombie está atacando de cerca
var moving: bool = true

@onready var camera = $Camera3D 

func _process(delta):
	if not moving:
		return
	
	progress += speed * delta
	
	time_passed += delta * bob_freq
	
	var move_y = sin(time_passed) * bob_amp_vertical
	var move_x = cos(time_passed / 2.0) * bob_amp_horizontal
	
	var tilt_z = cos(time_passed) * bob_amp_tilt
	
	camera.transform.origin.y = altura_camara + move_y
	camera.transform.origin.x = move_x

	camera.rotation.z = tilt_z
