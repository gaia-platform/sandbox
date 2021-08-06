extends Control

### Nodes
# Areas
export (NodePath) var inbound_area_path
export (NodePath) var packing_area_path
export (NodePath) var buffer_area_path
export (NodePath) var painting_area_path
export (NodePath) var labeling_area_path
export (NodePath) var outbound_area_path
export (NodePath) var charging_area_path

onready var inbound_area = get_node(inbound_area_path)
onready var packing_area = get_node(packing_area_path)
onready var buffer_area = get_node(buffer_area_path)
onready var painting_area = get_node(painting_area_path)
onready var labeling_area = get_node(labeling_area_path)
onready var outbound_area = get_node(outbound_area_path)
onready var charging_area = get_node(charging_area_path)

onready var areas = [
	inbound_area,
	packing_area,
	buffer_area,
	painting_area,
	labeling_area,
	outbound_area,
	charging_area
]
var number_of_waypoints = -1

# Properties
export (NodePath) var simulation_controller_path
onready var simulation_controller = get_node(simulation_controller_path)


func _ready():
	# Wait for everything to load in, then count number of waypoints
	yield(get_tree(), "idle_frame")
	number_of_waypoints = 0
	for area in areas:
		number_of_waypoints += area.associated_waypoints.size()
