extends Node3D

const PlayerScript = preload("res://scripts/Player.gd")
const InteractableScript = preload("res://scripts/Interactable.gd")
const MoveJoystickScript = preload("res://scripts/MoveJoystick.gd")
const LookPadScript = preload("res://scripts/LookPad.gd")

# Real asset models
const FuelPumpModel = preload("res://models/props/fuel_pump.glb")
const ChipsBoxModel = preload("res://models/products/chips_box.gltf")
const WaferBoxModel = preload("res://models/products/wafer_box.gltf")
const CharacterAModel = preload("res://models/characters/character_a.fbx")
const CharacterBModel = preload("res://models/characters/character_b.fbx")

# Tweak these if a real model looks too big/small once you see it in-game
const FUEL_PUMP_SCALE := 1.0
const PRODUCT_BOX_SCALE := 0.18
const CHARACTER_SCALE := 1.0

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

	var prompt_panel = prompt_label.get_meta("panel")
	if message_timer > 0:
		message_timer -= delta
		prompt_panel.visible = true
		prompt_label.text = message_text
	elif current_interactable:
		prompt_panel.visible = true
		prompt_label.text = current_interactable.interact_label
	else:
		prompt_panel.visible = false
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
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.95, 0.82)
	sun.shadow_enabled = true
	add_child(sun)

	# Desert sand ground
	var ground = StaticBody3D.new()
	var ground_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground_mesh.mesh = plane
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.82, 0.68, 0.45)
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	var ground_col = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(200, 0.1, 200)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.05, 0)
	ground.add_child(ground_col)
	add_child(ground)

	# Highway running past the station (runs along X axis, station sits just off it)
	var road = StaticBody3D.new()
	var road_mesh = MeshInstance3D.new()
	var road_plane = PlaneMesh.new()
	road_plane.size = Vector2(200, 14)
	road_mesh.mesh = road_plane
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.15, 0.15, 0.16)
	road_mesh.material_override = road_mat
	road.position = Vector3(0, 0.02, 20)
	road.add_child(road_mesh)
	var road_col = CollisionShape3D.new()
	var road_shape = BoxShape3D.new()
	road_shape.size = Vector3(200, 0.05, 14)
	road_col.shape = road_shape
	road.add_child(road_col)
	add_child(road)

	# Dashed center line on the highway
	for i in range(-90, 91, 8):
		_add_box(Vector3(i, 0.05, 20), Vector3(3, 0.02, 0.3), Color(0.9, 0.85, 0.3), false)

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

	# Customers standing near the shop
	_create_customer(Vector3(9, 0, -2), CharacterAModel, 200)
	_create_customer(Vector3(11, 0, -2), CharacterBModel, 160)

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
	var pump_visual = FuelPumpModel.instantiate()
	pump_visual.position = pos
	pump_visual.scale = Vector3.ONE * FUEL_PUMP_SCALE
	add_child(pump_visual)

	# Simple collision box around the pump so the player can't walk through it
	var pump_body = StaticBody3D.new()
	var pump_col = CollisionShape3D.new()
	var pump_shape = BoxShape3D.new()
	pump_shape.size = Vector3(0.8, 1.8, 0.6)
	pump_col.shape = pump_shape
	pump_col.position = pos + Vector3(0, 0.9, 0)
	pump_body.add_child(pump_col)
	add_child(pump_body)

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

	var label = Label3D.new()
	label.text = "⛽ Pump %d" % index
	label.position = pos + Vector3(0, 3, 0)
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _create_shelf(pos: Vector3, index: int):
	_add_box(pos + Vector3(0, 0.9, 0), Vector3(1.5, 1.8, 0.5), Color(0.6, 0.4, 0.2), true)

	# Decorative product boxes arranged on the shelf front (real models with our labels)
	var product_models = [ChipsBoxModel, WaferBoxModel]
	var box_spacing = 0.35
	for row in range(2):
		for col in range(2):
			var product = product_models[(row + col + index) % product_models.size()]
			var item = product.instantiate()
			item.scale = Vector3.ONE * PRODUCT_BOX_SCALE
			item.position = pos + Vector3(-0.35 + col * box_spacing * 2, 1.25 + row * box_spacing, 0.4)
			add_child(item)

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

func _create_customer(pos: Vector3, model: PackedScene, facing_degrees: float):
	var character = model.instantiate()
	character.position = pos
	character.rotation_degrees.y = facing_degrees
	character.scale = Vector3.ONE * CHARACTER_SCALE
	add_child(character)
	# Play whichever animation came bundled with the character, if any
	var anim_player = _find_animation_player(character)
	if anim_player and anim_player.get_animation_list().size() > 0:
		anim_player.play(anim_player.get_animation_list()[0])

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result
	return null

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

	# ---- Top money panel ----
	var money_panel = Panel.new()
	money_panel.position = Vector2(24, 24)
	money_panel.size = Vector2(200, 64)
	money_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.55), 16))
	canvas.add_child(money_panel)

	money_label = Label.new()
	money_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 34)
	money_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	money_panel.add_child(money_label)

	# ---- Prompt panel (bottom center) ----
	var prompt_panel = Panel.new()
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.position = Vector2(-220, -240)
	prompt_panel.size = Vector2(440, 60)
	prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.55), 14))
	canvas.add_child(prompt_panel)

	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false
	prompt_label.set_meta("panel", prompt_panel)

	# ---- Progress bar ----
	progress_bar = ProgressBar.new()
	progress_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	progress_bar.position = Vector2(-150, -170)
	progress_bar.size = Vector2(300, 30)
	progress_bar.max_value = 100
	progress_bar.show_percentage = false
	var pb_bg = _panel_style(Color(0, 0, 0, 0.5), 10)
	var pb_fill = _panel_style(Color(1, 0.7, 0.1, 1), 10)
	progress_bar.add_theme_stylebox_override("background", pb_bg)
	progress_bar.add_theme_stylebox_override("fill", pb_fill)
	canvas.add_child(progress_bar)

	# ---- Move joystick (bottom left, big) ----
	var joystick = Control.new()
	joystick.size = Vector2(220, 220)
	var joy_base = Panel.new()
	joy_base.size = Vector2(220, 220)
	joy_base.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.18), 110))
	joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.add_child(joy_base)
	var knob = Panel.new()
	knob.name = "Knob"
	knob.size = Vector2(100, 100)
	knob.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.55), 50))
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.add_child(knob)
	joystick.set_script(MoveJoystickScript)
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(50, -280)
	canvas.add_child(joystick)
	move_joystick = joystick

	# ---- Interact button (bottom right, big circular) ----
	var interact_btn = Button.new()
	interact_btn.text = "HOLD\nTO WORK"
	interact_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_btn.position = Vector2(-210, -280)
	interact_btn.size = Vector2(170, 170)
	interact_btn.add_theme_font_size_override("font_size", 22)
	interact_btn.add_theme_stylebox_override("normal", _panel_style(Color(0.85, 0.15, 0.15, 0.85), 85))
	interact_btn.add_theme_stylebox_override("hover", _panel_style(Color(0.9, 0.2, 0.2, 0.9), 85))
	interact_btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.6, 0.1, 0.1, 0.95), 85))
	interact_btn.button_down.connect(_on_interact_down)
	interact_btn.button_up.connect(_on_interact_up)
	canvas.add_child(interact_btn)

func _panel_style(color: Color, corner_radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style

func _on_interact_down():
	if current_interactable:
		current_interactable.start_interact()

func _on_interact_up():
	if current_interactable:
		current_interactable.stop_interact()

func _on_money_changed(amount):
	money_label.text = "💰 ₹%d" % amount
