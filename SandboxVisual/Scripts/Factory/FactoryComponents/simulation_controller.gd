extends PanelContainer

export var speed_scale = 350
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


func _on_PauseButton_pressed():
	get_tree().paused = not get_tree().paused
	pause_button.set_text("Resume" if get_tree().paused else "Pause")


func _on_SlowerButton_pressed():
	speed_scale -= 50
	_update_speed_scale_label()


func _on_FasterButton_pressed():
	speed_scale += 50
	_update_speed_scale_label()


func _update_speed_scale_label():
	speed_scale_label.text = String(speed_scale) + "x"
	Engine.time_scale = speed_scale
