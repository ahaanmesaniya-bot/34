extends Control

var touch_index := -1
var player: CharacterBody3D
const SENSITIVITY := 0.006

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
		elif not event.pressed and event.index == touch_index:
			touch_index = -1
	elif event is InputEventScreenDrag and event.index == touch_index:
		if player:
			player.look_input += event.relative * SENSITIVITY
