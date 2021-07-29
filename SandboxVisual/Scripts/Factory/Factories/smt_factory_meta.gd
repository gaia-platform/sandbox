extends Node

export (String, FILE) var scene_picker_scene

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


func _on_ExitButton_pressed():
	var change_scene_status = get_tree().change_scene(scene_picker_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)
