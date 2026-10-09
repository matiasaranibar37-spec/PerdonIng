extends CanvasLayer
class_name MobilePointerManager

@onready var pointer_p1: Control = $Control/PointerP1
@onready var pointer_p2: Control = $Control/PointerP2
@onready var player_p1: MobilePlayer = get_parent().get_node_or_null("PlayerP1")
@onready var player_p2: MobilePlayer = get_parent().get_node_or_null("PlayerP2")
@onready var camera: Camera3D = get_parent().get_node_or_null("Camera3D")

@export var mouse_sensitivity: float = 0.0025
@export var gamepad_sensitivity: float = 9.0
@export var allow_mouse_camera: bool = true

var active_touch_for_player := {1: -1, 2: -1}
var camera_pitch: float = 0.0
var mouse_camera_enabled: bool = false
var gamepad_shooting := {1: false, 2: false}

func _ready() -> void:
	# Centra el punto de mira usando el tamaño real de cada textura.
	_center_pointer(pointer_p1)
	_center_pointer(pointer_p2)
	if camera:
		camera_pitch = camera.rotation.x
	if not DisplayServer.is_touchscreen_available() and allow_mouse_camera:
		mouse_camera_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _center_pointer(pointer: Control) -> void:
	if pointer:
		pointer.position = (get_viewport().get_visible_rect().size - pointer.size) * 0.5

func _process(_delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	if not DisplayServer.is_touchscreen_available():
		# En modo FPS el punto de mira permanece exactamente en el centro.
		_center_pointer(pointer_p1)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_shoot(1)
	_update_gamepad_pointer(pointer_p1, 0, 1, size)
	_update_gamepad_pointer(pointer_p2, 1, 2, size)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_camera_enabled = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_camera_enabled = true
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and allow_mouse_camera:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_camera_enabled = true
			return

	if event is InputEventMouseMotion and mouse_camera_enabled and camera and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * mouse_sensitivity
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-80.0), deg_to_rad(80.0))
		camera.rotation.x = camera_pitch
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			var player_id := 1 if event.position.x < get_viewport().get_visible_rect().size.x * 0.5 else 2
			active_touch_for_player[player_id] = event.index
			_set_pointer(player_id, event.position)
			_shoot(player_id)
		else:
			for player_id in [1, 2]:
				if active_touch_for_player[player_id] == event.index:
					active_touch_for_player[player_id] = -1
	elif event is InputEventScreenDrag:
		for player_id in [1, 2]:
			if active_touch_for_player[player_id] == event.index:
				_set_pointer(player_id, event.position)
				break

func _update_gamepad_pointer(pointer: Control, device: int, player_id: int, size: Vector2) -> void:
	if not Input.get_connected_joypads().has(device):
		return
	var x := Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
	var y := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	if abs(x) > 0.15 or abs(y) > 0.15:
		pointer.position += Vector2(x, y) * gamepad_sensitivity
		pointer.position.x = clampf(pointer.position.x, 0.0, size.x - pointer.size.x)
		pointer.position.y = clampf(pointer.position.y, 0.0, size.y - pointer.size.y)
	var trigger := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
	if trigger > 0.6 or Input.is_joy_button_pressed(device, JOY_BUTTON_A):
		if not gamepad_shooting[player_id]:
			_shoot(player_id)
		gamepad_shooting[player_id] = true
	else:
		gamepad_shooting[player_id] = false

func _set_pointer(player_id: int, position: Vector2) -> void:
	var pointer: Control = pointer_p1 if player_id == 1 else pointer_p2
	# El toque representa el centro del puntero, no su esquina superior izquierda.
	pointer.position = position - pointer.size * 0.5

func _shoot(player_id: int) -> void:
	if player_id == 1 and player_p1:
		player_p1.shoot_from_center() if not DisplayServer.is_touchscreen_available() else player_p1.shoot(pointer_p1.position + pointer_p1.size * 0.5)
	elif player_id == 2 and player_p2:
		player_p2.shoot(pointer_p2.position + pointer_p2.size * 0.5)
