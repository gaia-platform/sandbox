extends Node

### Exports and nodes
# Waypoints and paths
export (Array, NodePath) var nav_node_paths
var nav_nodes: Array

export (NodePath) var test_widget_path
# onready var test_widget = get_node(test_widget_path)

export (NodePath) var test_pallet_path
# onready var test_pallet = get_node(test_pallet_path)

# Bots
export (NodePath) var bots_path
onready var bots = get_node(bots_path)

# Create astar navigator
onready var astar = AStar2D.new()

### Member variables
var _location_index: int
var id_to_bot: Dictionary  # Map bot IDs to bot nodes
onready var _factory = get_tree().get_current_scene()


func _ready():
	# Generate array with nodes
	for nav_item_path in nav_node_paths:
		nav_nodes.append(get_node(nav_item_path))
	# Link bots to IDs
	for bot in bots.get_children():
		id_to_bot[bot.bot_id] = bot

	# Connect to MQTT Signals
	var _connect_to_signal = CommunicationManager.connect(
		"factory_move_location", self, "_bot_move_location"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_pickup_payload", self, "_bot_pickup_payload"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_drop_payload", self, "_bot_drop_payload"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_status_request", self, "_bot_status_request"
	)

	# Generate connections
	while _factory.number_of_waypoints == -1:  # Wait until number of waypoints is calculated
		yield(get_tree(), "idle_frame")
	create_connections()

	# Setup Demo
	# _location_index = 3  # Test bot starts in charging area
	# for bot in bots:
	# 	bot.goal_location = _location_index
	# 	_factory.charging_area.add_node(bot)
	# 	yield(get_tree(), "idle_frame")  # Important to add this to prevent data collision

	# _factory.buffer_area.add_node(test_widget)
	# _factory.inbound_area.add_pallet(test_pallet)
	# test_pallet.add_widget(_factory.widgets.get_children()[1])


func _input(event):
	if event.is_action_pressed("ui_accept"):
		_location_index += 1
		if _location_index == _factory.number_of_waypoints:
			_location_index = 0
		_navigate_bot(bots[0], _location_index)
	# elif event is InputEventKey and event.pressed:
	# 	match event.scancode:
	# 		KEY_1:  # Move PalletBot to Inbound Area
	# 			_move_location(id_to_bot.keys()[1], 4)
	# 			test_widget.show_processing(2)
	# 			test_widget.tween.connect(
	# 				"tween_all_completed", test_widget, "paint", [], CONNECT_ONESHOT
	# 			)
	# 		KEY_2:  # PalletBot pickup pallet
	# 			bots[1].pickup_payload(test_pallet)
	# 		KEY_3:
	# 			_move_location(id_to_bot.keys()[1], 5)
	# 		KEY_4:
	# 			bots[1].drop_payload(_factory.packing_area)
	# 		KEY_5:
	# 			_move_location(id_to_bot.keys()[1], 3)
	# 		KEY_6:
	# 			_factory.charging_area.add_node(bots[1])
	# 		KEY_7:
	# 			_move_location(id_to_bot.keys()[0], 6)
	# 		KEY_8:
	# 			bots[0].pickup_payload(test_widget)
	# 		KEY_9:
	# 			_move_location(id_to_bot.keys()[0], 2)
	# 		KEY_0:
	# 			bots[0].drop_payload(_factory.painting_area)


### Signal functions
func _bot_move_location(bot_id: String, location: String):
	var location_index = location_index(location)
	if location_index >= 0 && location_index < _factory.number_of_waypoints:
		var bot = id_to_bot[bot_id]
		bot.bot_collision = null
		_navigate_bot(bot, location_index)


func _bot_pickup_payload(bot_id: String, location: String):
	var location_index = location_index(location)
	var bot = id_to_bot[bot_id] if id_to_bot.has(bot_id) else null
	var next_payload = (
		_factory.areas[location_index].get_next_payload()
		if location_index < _factory.areas.size()
		else null
	)
	if bot and next_payload:
		bot.pickup_payload(next_payload)


func _bot_drop_payload(bot_id: String, location: String):
	var location_index = location_index(location)
	var bot = id_to_bot[bot_id] if id_to_bot.has(bot_id) else null
	var area = _factory.areas[location_index] if location_index >= 0 else null
	if bot and area and bot.payload_node:
		bot.drop_payload(area)


func _bot_status_request(bot_id: String, status_item: String):
	var target_bot = id_to_bot[bot_id]
	target_bot.publish_status_item(status_item)


# Recalculate connections on resize
func _on_FloorPath_resized():
	# Recalculate paths
	yield(get_tree(), "idle_frame")  # Wait for resizing
	create_connections()


### Public Functions
func location_index(location: String):
	var result: int = 0
	for area in _factory.areas:
		if area.id == location:
			return result
		result += 1
	return -1


func location_id(location: int):
	if location < _factory.areas.size():
		return _factory.areas[location].id
	return null


## Generate astar map
func create_connections():
	# Reset astar
	astar.clear()

	# Create nav points
	for nav_node in nav_nodes:
		astar.add_point(nav_nodes.find(nav_node), nav_node.get_location())

	# Connect points. Only need to use path which will cover for waypoints
	for path_id in range(_factory.number_of_waypoints, nav_nodes.size()):
		for node in nav_nodes[path_id].connected_nodes:
			astar.connect_points(path_id, nav_nodes.find(node))


### Private functions
## Generate navigation path for bot to location
func _navigate_bot(bot, loc_index):
	# Configure start point
	var from_id: int
	if bot.is_inside_area:
		from_id = astar.get_closest_point(bot.position, true)  # Start with closest navigation point
	else:
		from_id = astar.get_closest_point(bot.position)

	# Check if path is blocked
	var id_path = astar.get_id_path(from_id, loc_index)

	var path_clear = true
	for id in id_path:
		if astar.is_point_disabled(id):
			path_clear = false
			break
	if not id_path.size() or not path_clear:
		CommunicationManager.publish_to_app(
			"bots/%s/cant_navigate" % bot.bot_id, location_id(loc_index)
		)
		return

	# If all clear, get raw path
	var point_path = astar.get_point_path(from_id, loc_index)

	# Optimize path
	var path_index = 0  # Base index
	while path_index < point_path.size() - 2:  # Loop while comparing against next two points
		var inner_index = path_index + 1  # Search index
		while inner_index < point_path.size() - 1:  # Loop while can add one more
			var base_dir = (point_path[inner_index] - point_path[path_index]).normalized()  # From base to immediate next point
			var next_dir = (point_path[inner_index + 1] - point_path[path_index]).normalized()  # From base to the one after that

			if base_dir.dot(next_dir) > 0.99:  # If the movement base to two steps ahead are basically the same as one step ahead...
				point_path.remove(inner_index)  # Remove the next goal location and go directly to the one after that
			else:  # If not, stop searching
				break
		path_index += 1  # Move onto next point

	# Set bot movement path and properties
	if bot.position == point_path[0]:
		point_path.remove(0)
	bot.goal_location = loc_index
	bot.travel(point_path)
