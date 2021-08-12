extends Control

### Nodes
# Areas
export (NodePath) var inbound_area_path
export (NodePath) var charging_station_path
export (NodePath) var buffer_area_path
export (NodePath) var pl_start_path
export (NodePath) var production_line_path
export (NodePath) var pl_end_path
export (NodePath) var outbound_area_path

onready var inbound_area = get_node(inbound_area_path)
onready var charging_station = get_node(charging_station_path)
onready var buffer_area = get_node(buffer_area_path)
onready var pl_start = get_node(pl_start_path)
onready var production_line = get_node(production_line_path)
onready var pl_end = get_node(pl_end_path)
onready var outbound_area = get_node(outbound_area_path)

onready var areas = [
	inbound_area, charging_station, buffer_area, pl_start, production_line, pl_end, outbound_area
]
var number_of_waypoints = -1

# Widgets
export (NodePath) var widgets_path
onready var widgets = get_node(widgets_path)

# To be spawned
export (PackedScene) var widget_bot_scene
export (PackedScene) var pallet_bot_scene
export (PackedScene) var widget_scene
export (PackedScene) var pallet_scene

# Bots
export (NodePath) var bots_path
onready var bots = get_node(bots_path)

#Pallets
export (NodePath) var pallets_path
onready var pallets = get_node(pallets_path)

# Properties
export (NodePath) var simulation_controller_path
export (NodePath) var widget_bot_counter_path
export (NodePath) var pallet_bot_counter_path
onready var simulation_controller = get_node(simulation_controller_path)
onready var widget_bot_counter = get_node(widget_bot_counter_path)
onready var pallet_bot_counter = get_node(pallet_bot_counter_path)

func _ready():
	# Wait for everything to load in, then count number of waypoints
	yield(get_tree(), "idle_frame")
	number_of_waypoints = 0
	for area in areas:
		number_of_waypoints+=area.associated_waypoints.size()

	# Populate bots
	# print(get_tree().get_current_scene().simulation_controller.speed_scale)
	_generate_bots()

### Private methods
# Populate bots
func _generate_bots():
	for wb in widget_bot_counter.value:
		var wb_instance = widget_bot_scene.instance()
		bots.add_child(wb_instance)
		wb_instance.global_position = charging_station.associated_waypoints[0].get_location()
		charging_station.add_node(wb_instance)

	for pb in pallet_bot_counter.value:
		var pb_instance = pallet_bot_scene.instance()
		bots.add_child(pb_instance)
		pb_instance.global_position = charging_station.associated_waypoints[0].get_location()
		charging_station.add_node(pb_instance)
