extends PanelContainer

export (NodePath) var count_label_path
export (NodePath) var pallet_space_path
export (NodePath) var widget_space_path
export (Array, NodePath) var associated_waypoint_paths

onready var count_label = get_node(count_label_path)
onready var pallet_space = get_node(pallet_space_path)
onready var widget_space = get_node(widget_space_path)
onready var widget_grid = widget_space.get_child(0)
var associated_waypoints: Array

func _ready():
	for associated_waypoint_path in associated_waypoint_paths:
		associated_waypoints.append(get_node(associated_waypoint_path))
