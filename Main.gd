extends Node3D

const PlayerScript = preload("res://scripts/Player.gd")
const InteractableScript = preload("res://scripts/Interactable.gd")
const MoveJoystickScript = preload("res://scripts/MoveJoystick.gd")
const LookPadScript = preload("res://scripts/LookPad.gd")

var player: CharacterBody3D
var current_interactable: Area3D = null
var move_joystick: Control

var money_label: Label
var progress_bar: ProgressBar
var prompt_label: Label

var message_text := ""
var message_timer := 0.0

func _ready():
	GameManager.money_changed.connect(_on_money_changed)
	_build_environment()
	_build_player()
	_build_ui()
	_on_money_changed(GameManager.money)

func _process(delta):
	if player and move_joystick:
		player.move_input = move_joystick.output

	for node in get_tree().get_nodes_in_group("interactable"):
		if node.in_progress:
			node.update_interact(delta)
			if node == current_interactable:
				progress_bar.value = node.progress * 100.0

	if message_timer > 0:
		message_timer -= delta
		prompt_label.visible = true
		prompt_label.text = message_text
	elif current_interactable:
		prompt_label.visible = true
		prompt_label.text = current_interactable.interact_label
	else:
		prompt_label.visible = false
		progress_bar.value = 0.0

# ---------- WORLD BUILDING ----------

func _build_environment():
	var env_node = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env_node.environment = environment
	add_child(env_node)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	# Ground
	var ground = StaticBody3D.new()
	var ground_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground_mesh.mesh = plane
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.35, 0.35, 0.38)
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	var ground_col = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(60, 0.1, 60)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.05, 0)
	ground.add_child(ground_col)
	add_child(ground)

	# Canopy over the pumps
	_add_box(Vector3(0, 3.5, 0), Vector3(14, 0.3, 8), Color(0.8, 0.2, 0.2), false)
	for i in range(4):
		_add_box(Vector3(-6 + i * 4, 1.75, -3), Vector3(0.3, 3.5, 0.3), Color(0.7, 0.7, 0.7), true)

	# Fuel pumps
	var pump_positions = [Vector3(-4, 0, 0), Vector3(0, 0, 0), Vector3(4, 0, 0)]
	for i in range(pump_positions.size()):
		_create_fuel_pump(pump_positions[i], i + 1)

	# Shop building + shelves
	_add_box(Vector3(10, 1.5, -6), Vector3(8, 3, 6), Color(0.9, 0.8, 0.4), true)
	_create_shelf(Vector3(8, 0, -6), 1)
	_create_shelf(Vector3(12, 0, -6), 2)

func _add_box(pos: Vector3, size: Vector3, color: Color, collide: bool) -> Node3D:
	var body
	if collide:
		body = StaticBody3D.new()
	else:
		body = Node3D.new()
	body.position = pos
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	if collide:
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	add_child(body)
	return body

func _create_fuel_pump(pos: Vector3, index: int):
	var pump_visual = _add_box(pos + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.4), Color(1, 1, 1), true)

	var nozzle = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 0.6
	nozzle.mesh = cyl
	nozzle.position = Vector3(0.35, 0.3, 0)
	nozzle.rotation_degrees = Vector3(0, 0, 80)
	var nmat = StandardMaterial3D.new()
	nmat.albedo_color = Color(0.9, 0.1, 0.1)
	nozzle.material_override = nmat
	pump_visual.add_child(nozzle)

	# Waiting car
	_add_box(pos + Vector3(0, 0.5, 2.5), Vector3(1.8, 1, 4), Color(0.2, 0.4, 0.8), true)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.add_to_group("interactable")
	area.position = pos + Vector3(0, 1, 1.2)
	var acol = CollisionShape3D.new()
	var ashape = BoxShape3D.new()
	ashape.size = Vector3(2, 2, 3)
	acol.shape = ashape
	area.add_child(acol)
	add_child(area)
	area.reward = 30
	area.fill_time = 2.5
	area.interact_label = "Fuel bharne ke liye button dabaye rakho (Pump %d)" % index
	area.completed.connect(func(reward): _on_task_completed("Pump %d bhara! +₹%d" % [index, reward]))
	area.area_entered.connect(func(a): pass)

	var label = Label3D.new()
	label.text = "⛽ Pump %d" % index
	label.position = pos + Vector3(0, 3, 0)
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _create_shelf(pos: Vector3, index: int):
	_add_box(pos + Vector3(0, 0.9, 0), Vector3(1.5, 1.8, 0.5), Color(0.6, 0.4, 0.2), true)

	var area = Area3D.new()
	area.set_script(InteractableScript)
	area.add_to_group("interactable")
	area.position = pos + Vector3(0, 1, 1)
	var acol = CollisionShape3D.new()
	var ashape = BoxShape3D.new()
	ashape.size = Vector3(2.2, 2, 2.5)
	acol.shape = ashape
	area.add_child(acol)
	add_child(area)
	area.reward = 60
	area.fill_time = 4.0
	area.interact_label = "Shelf restock karne ke liye button dabaye rakho (Shelf %d)" % index
	area.completed.connect(func(reward): _on_task_completed("Shelf %d restock hua! +₹%d" % [index, reward]))

	var label = Label3D.new()
	label.text = "🛒 Shelf %d" % index
	label.position = pos + Vector3(0, 3, 0)
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _on_task_completed(message: String):
	message_text = message
	message_timer = 1.5

# ---------- PLAYER ----------

func _build_player():
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = Vector3(0, 0.5, 8)

	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	player.add_child(collision)

	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 1.6, 0)
	camera.current = true
	player.add_child(camera)

	var interact_zone = Area3D.new()
	interact_zone.name = "InteractZone"
	var izcol = CollisionShape3D.new()
	var izshape = SphereShape3D.new()
	izshape.radius = 2.2
	izcol.shape = izshape
	interact_zone.add_child(izcol)
	interact_zone.position = Vector3(0, 1, -1.2)
	interact_zone.area_entered.connect(_on_zone_entered)
	interact_zone.area_exited.connect(_on_zone_exited)
	player.add_child(interact_zone)

	add_child(player)

func _on_zone_entered(area):
	if area.is_in_group("interactable"):
		current_interactable = area

func _on_zone_exited(area):
	if area == current_interactable:
		current_interactable = null

# ---------- UI ----------

func _build_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	# Full-screen look drag pad (added first so buttons/joystick sit on top)
	var look_pad = Control.new()
	look_pad.set_script(LookPadScript)
	look_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_pad.player = player
	canvas.add_child(look_pad)

	# Money label
	money_label = Label.new()
	money_label.position = Vector2(20, 20)
	money_label.add_theme_font_size_override("font_size", 28)
	canvas.add_child(money_label)

	# Prompt label (bottom center)
	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-160, -170)
	prompt_label.custom_minimum_size = Vector2(320, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	canvas.add_child(prompt_label)

	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	progress_bar.position = Vector2(-100, -140)
	progress_bar.size = Vector2(200, 20)
	progress_bar.max_value = 100
	canvas.add_child(progress_bar)

	# Move joystick (bottom left)
	var joystick = Control.new()
	joystick.size = Vector2(120, 120)
	var joy_base = ColorRect.new()
	joy_base.color = Color(1, 1, 1, 0.2)
	joy_base.size = Vector2(120, 120)
	joystick.add_child(joy_base)
	var knob = ColorRect.new()
	knob.name = "Knob"
	knob.color = Color(1, 1, 1, 0.5)
	knob.size = Vector2(50, 50)
	joystick.add_child(knob)
	joystick.set_script(MoveJoystickScript)
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(40, -160)
	canvas.add_child(joystick)
	move_joystick = joystick

	# Interact button (bottom right)
	var interact_btn = Button.new()
	interact_btn.text = "HOLD\nTO WORK"
	interact_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_btn.position = Vector2(-160, -160)
	interact_btn.size = Vector2(120, 100)
	interact_btn.add_theme_font_size_override("font_size", 16)
	interact_btn.button_down.connect(_on_interact_down)
	interact_btn.button_up.connect(_on_interact_up)
	canvas.add_child(interact_btn)

func _on_interact_down():
	if current_interactable:
		current_interactable.start_interact()

func _on_interact_up():
	if current_interactable:
		current_interactable.stop_interact()

func _on_money_changed(amount):
	money_label.text = "💰 ₹%d" % amount
