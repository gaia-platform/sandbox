extends PanelContainer

export (float) var speed_scale = 1
export (String, FILE) var scene_picker_scene
export (NodePath) var level_name_label_path
export (NodePath) var pause_button_path
export (NodePath) var speed_scale_label_path

onready var level_name_label = get_node(level_name_label_path)
onready var pause_button = get_node(pause_button_path)
onready var speed_scale_label = get_node(speed_scale_label_path)


func _ready():
	_update_speed_scale_label()


func _on_ExitButton_pressed():
	# Cleanup
	Engine.time_scale = 1  # Reset speed

	# Switch scenes
	var change_scene_status = get_tree().change_scene(scene_picker_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)

	# Does this really belong here? Doesn't seem to fire
	CommunicationManager.publish_to_coordinator("project/exit", "simulation")


func _on_PauseButton_pressed():
	get_tree().paused = not get_tree().paused
	pause_button.set_text("Resume" if get_tree().paused else "Pause")


func _on_SlowerButton_pressed():
	speed_scale -= 0.25 if speed_scale > 0.25 else 0.0
	_update_speed_scale_label()


func _on_FasterButton_pressed():
	speed_scale += 0.25
	_update_speed_scale_label()


func _update_speed_scale_label():
	speed_scale_label.text = String(speed_scale) + "x"
	Engine.time_scale = speed_scale
