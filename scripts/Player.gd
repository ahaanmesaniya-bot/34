extends CharacterBody3D

const SPEED = 4.0
const GRAVITY = 9.8
const MOUSE_SENSITIVITY = 0.003

var camera: Camera3D
var move_input := Vector2.ZERO
var look_input := Vector2.ZERO

func _ready():
	camera = get_node("Camera3D")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# Apply look rotation (from touch drag or mouse)
	rotate_y(-look_input.x)
	camera.rotate_x(-look_input.y)
	camera.rotation.x = clamp(camera.rotation.x, -1.3, 1.3)
	look_input = Vector2.ZERO

	# Keyboard fallback for desktop testing in the editor
	var kb_vec := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		kb_vec.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		kb_vec.y += 1
	if Input.is_physical_key_pressed(KEY_A):
		kb_vec.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		kb_vec.x += 1
	if kb_vec.length() > 0.1:
		kb_vec = kb_vec.normalized()

	var final_move = move_input if move_input.length() > 0.1 else kb_vec

	var direction = (transform.basis * Vector3(final_move.x, 0, final_move.y)).normalized()
	if direction.length() > 0.1:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_input.x += event.relative.x * MOUSE_SENSITIVITY
		look_input.y += event.relative.y * MOUSE_SENSITIVITY
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
