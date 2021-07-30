extends Node

export var speed_scale = 500
export (String, FILE) var scene_picker_scene
export (NodePath) var pause_button_path
export (NodePath) var speed_scale_label_path

onready var pause_button = get_node(pause_button_path)
onready var speed_scale_label = get_node(speed_scale_label_path)

const locations = [
	Vector2(484, 520),  # WS Start
	Vector2(125, 424),  # Production Line
	Vector2(486, 368),  # WS End
	Vector2(813, 337),  # Packaging Line
	Vector2(659, 243),  # Inbound
	Vector2(1025, 464),  # Buffer Area 0/1
	Vector2(1090, 464),  # Buffer Area 2/3
	Vector2(816, 497),  # Kitting Area 0/1
	Vector2(816, 568),  # Kitting Area 2/3
	Vector2(620, 520),  # Charging Area 0
	Vector2(685, 520),  # Charging Area 1
]

enum stop_names {
	WS_START,
	PRODUCTION_LINE,
	WS_END,
	PACKAGING_LINE,
	INBOUND,
	BUFFER_AREA_0,
	BUFFER_AREA_1,
	KITTING_AREA_0,
	KITTING_AREA_1,
	CHARGING_AREA_0,
	CHARGING_AREA_1
}


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
