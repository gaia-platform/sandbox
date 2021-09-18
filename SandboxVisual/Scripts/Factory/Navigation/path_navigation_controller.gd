extends Node
# A* based navigation controller and bot signal handler
# Handles generating nav paths and delegating bot commands

# Waypoints and paths
export(Array, NodePath) var nav_node_paths
export(NodePath) var test_widget_path
export(NodePath) var test_pallet_path
export(NodePath) var bots_path

# Registry of nodes or bots
var nav_nodes: Array
var id_to_bot: Dictionary

var _location_index: int

onready var bots = get_node(bots_path)
onready var astar = AStar2D.new()
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
	_connect_to_signal = CommunicationManager.connect("factory_charge", self, "_bot_charge")
	_connect_to_signal = CommunicationManager.connect(
		"factory_pickup_payload", self, "_bot_pickup_payload"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_drop_payload", self, "_bot_drop_payload"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_status_request", self, "_bot_status_request"
	)

	# Generate connections after waypoints are calculated
	while _factory.number_of_waypoints == -1:
		yield(get_tree(), "idle_frame")
	create_connections()


func _input(event):
	if event.is_action_pressed("ui_accept"):
		_location_index += 1
		if _location_index == _factory.number_of_waypoints:
			_location_index = 0
		_navigate_bot(bots[0], _location_index)


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


func _bot_move_location(bot_id: String, location: String):
	var location_index = location_index(location)
	if location_index >= 0 && location_index < _factory.number_of_waypoints:
		var bot = id_to_bot[bot_id]
		bot.bot_collision = null
		_navigate_bot(bot, location_index)


func _bot_charge(bot_id: String):
	var bot = id_to_bot[bot_id]  # Get the bot
	var success: bool
	if bot.goal_location == location_index("charging") and not bot.is_inside_area:
		_factory.charging_station.add_node(bot)
		if bot.disabled_point != -1:
			astar.set_point_disabled(bot.disabled_point, false)
			bot.disabled_point = -1
		success = true
		bot.is_charging = true
	CommunicationManager.publish_to_app("bot/%s/charging" % bot_id, success)


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
	if (
		bot
		and area
		and bot.payload_node
		and (
			not area.widget_grid.capacity_limit
			or area.widget_grid.node_to_spaces.size() != area.widget_grid.capacity_limit
		)
	):
		bot.drop_payload(area)
	else:
		CommunicationManager.publish_to_app("bot/%s/payload_dropped" % bot_id, false)


func _bot_status_request(bot_id: String, status_item: String):
	var target_bot = id_to_bot[bot_id]
	target_bot.publish_status_item(status_item)


# Recalculate connections on resize
func _on_FloorPath_resized():
	# Recalculate paths
	yield(get_tree(), "idle_frame")  # Wait for resizing
	create_connections()


func _navigate_bot(bot, loc_index):
	# Configure start point
	var from_id: int
	if bot.is_inside_area:
		from_id = astar.get_closest_point(bot.position, true)
	else:
		from_id = bot.goal_location

	# Check if path is blocked
	var id_path = astar.get_id_path(from_id, loc_index)

	var path_clear = true
	for id in id_path:
		if id == from_id:
			continue
		if astar.is_point_disabled(id):
			path_clear = false
			break

	if not id_path.size():
		CommunicationManager.publish_to_app("bot/%s/cant_navigate" % bot.bot_id, "cant_find_path")
		return
	if not path_clear:
		CommunicationManager.publish_to_app("bot/%s/cant_navigate" % bot.bot_id, "path_not_clear")
		return

	# If all clear, get raw path
	var point_path = astar.get_point_path(from_id, loc_index)

	# Optimize path by removing colinear points
	var path_index = 0  # Base index
	while path_index < point_path.size() - 2:
		var inner_index = path_index + 1
		while inner_index < point_path.size() - 1:
			var base_dir = (point_path[inner_index] - point_path[path_index]).normalized()
			var next_dir = (point_path[inner_index + 1] - point_path[path_index]).normalized()

			if base_dir.dot(next_dir) > 0.99:
				point_path.remove(inner_index)
			else:
				break
		path_index += 1

	# For a bot collision, adjust for closest point between first and second points
	if bot.modulate == Color.red:
		var tempAstar = AStar2D.new()
		tempAstar.add_point(0, point_path[0])
		tempAstar.add_point(1, point_path[1])
		tempAstar.connect_points(0, 1)
		point_path[0] = tempAstar.get_closest_position_in_segment(bot.position)

	# Set bot movement path and properties
	if bot.position == point_path[0]:
		point_path.remove(0)

	bot.goal_location = loc_index
	bot.is_charging = false
	bot.travel(point_path)
	CommunicationManager.publish_to_app("bot/%s/moving_to" % bot.bot_id, location_id(loc_index))  # Send signal to Gaia that bot started moving
