extends Area3D

signal completed(reward)

var reward: int = 50
var fill_time: float = 3.0
var interact_label: String = "Hold to interact"
var in_progress := false
var progress := 0.0

func start_interact():
	in_progress = true

func stop_interact():
	in_progress = false
	progress = 0.0

func update_interact(delta: float):
	if in_progress:
		progress += delta / fill_time
		if progress >= 1.0:
			in_progress = false
			progress = 0.0
			completed.emit(reward)
			GameManager.add_money(reward)
