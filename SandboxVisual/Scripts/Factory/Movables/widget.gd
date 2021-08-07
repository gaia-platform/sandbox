extends Sprite

### Properties
export (int, "Raw", "Painted", "Labeled") var state
export (bool) var is_inside_area

### Elements
export (NodePath) var widget_label_path
export (NodePath) var tween_path

onready var widget_label = get_node(widget_label_path)
onready var tween = get_node(tween_path)

signal leaving_area


func move_to(location: Vector2, leaving = false):
	tween.remove_all()
	tween.interpolate_property(
		self,
		"position",
		position,
		location,
		0.5 * owner.simulation_controller.speed_scale,
		Tween.TRANS_LINEAR,
		Tween.EASE_OUT_IN
	)
	tween.start()

	if leaving:
		emit_signal("leaving_area")

func painted(done=true):
	modulate = Color("#88ffff") if done else Color.white

func labeled(done=true):
	widget_label.visible = done
