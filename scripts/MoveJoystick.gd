extends Control

var touch_index := -1
var center := Vector2.ZERO
var output := Vector2.ZERO
const RADIUS := 55.0

@onready var knob: ColorRect = $Knob

func _ready():
	center = size / 2
	knob.position = center - knob.size / 2
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			_update(event.position)
		elif not event.pressed and event.index == touch_index:
			touch_index = -1
			output = Vector2.ZERO
			knob.position = center - knob.size / 2
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update(event.position)
	# Mouse fallback so it's also testable in the Godot editor
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_index = 1000
			_update(event.position)
		else:
			touch_index = -1
			output = Vector2.ZERO
			knob.position = center - knob.size / 2
	elif event is InputEventMouseMotion and touch_index == 1000:
		_update(event.position)

func _update(pos: Vector2):
	var offset = pos - center
	if offset.length() > RADIUS:
		offset = offset.normalized() * RADIUS
	output = offset / RADIUS
	knob.position = center + offset - knob.size / 2
