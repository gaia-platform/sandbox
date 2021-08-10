extends Sprite

### Properties
export (int, "Raw", "Painted", "Labeled") var state

### Elements
onready var widget_label = $WidgetLabel
onready var tween = $Tween
onready var progress_circle = $Progress

signal leaving_area


func move_to(location: Vector2, leaving = false):
	tween.remove_all()
	tween.interpolate_property(
		self,
		"position",
		position,
		location,
		0.5 * get_tree().get_current_scene().simulation_controller.speed_scale,
		Tween.TRANS_LINEAR,
		Tween.EASE_OUT_IN
	)
	tween.start()

	if leaving:
		emit_signal("leaving_area")


func paint(done = true):
	modulate = Color("#88ffff") if done else Color.white


func label(done = true):
	widget_label.visible = done


func show_processing(duration: float):
	tween.remove_all()
	tween.interpolate_property(
		progress_circle,
		"value",
		100,
		0,
		duration * get_tree().get_current_scene().simulation_controller.speed_scale,
		Tween.TRANS_LINEAR,
		Tween.EASE_OUT_IN
	)
	tween.start()
