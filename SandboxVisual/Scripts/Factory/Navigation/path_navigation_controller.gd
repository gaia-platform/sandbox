extends Node

### Exports and nodes
# Waypoints and paths
export (Array, NodePath) var nav_node_paths
var nav_nodes: Array

# Bots
export (NodePath) var bots_node_path
onready var bots_node = get_node(bots_node_path)
onready var bots = bots_node.get_children()

# Create astar navigator
onready var astar = AStar2D.new()

### Member variables
var _location_index: int
var id_to_bot: Dictionary  # Map bot IDs to bot nodes
var _screen_size = Vector2(930, 830)  # Set to default size at first


func _ready():
	# Generate array with nodes
	for nav_item_path in nav_node_paths:
		nav_nodes.append(get_node(nav_item_path))
	# Link bots to IDs
	for bot in bots:
		id_to_bot[bot.bot_id] = bot

	# Connect to MQTT Signals
	var _connect_to_signal = CommunicationManager.connect(
		"factory_move_location", self, "_move_location"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_status_request", self, "_bot_status_request"
	)

	# Generate connections
	while owner.number_of_waypoints == -1:  # Wait until number of waypoints is calculated
		yield(get_tree(), "idle_frame")
	create_connections()

	# Setup test bot
	_location_index = 3  # Test bot starts in charging area
	bots[0].goal_location = _location_index


func _input(event):
	if event.is_action_pressed("ui_accept"):
		_location_index += 1
		if _location_index == owner.number_of_waypoints:
			_location_index = 0
		_update_navigation_path(bots[0], _location_index)


### Signal functions
func _move_location(bot_id: String, location: int):
	if location >= 0 && location < owner.number_of_waypoints:
		_update_navigation_path(id_to_bot[bot_id], location)


func _bot_status_request(bot_id: String, status_item: String):
	var target_bot = id_to_bot[bot_id]
	target_bot.publish_status_item(status_item)


# Recalculate connections on resize
func _on_FloorPath_resized():
	# Recalculate paths
	yield(get_tree(), "idle_frame")  # Wait for resizing
	create_connections()

	# Recalculate bot positions
	for bot in bots:
		var bot_position_fraction = bot.position / _screen_size
		bot.position = owner.rect_size * bot_position_fraction
	_screen_size = owner.rect_size


### Public Functions
## Generate astar map
func create_connections():
	# Reset astar
	astar.clear()

	# Create nav points
	for nav_node in nav_nodes:
		astar.add_point(nav_nodes.find(nav_node), nav_node.get_location())

	# Connect points. Only need to use path which will cover for waypoints
	for path_id in range(owner.number_of_waypoints, nav_nodes.size()):
		for node in nav_nodes[path_id].connected_nodes:
			astar.connect_points(path_id, nav_nodes.find(node))


## Generate array of locations to travel
func get_directions(from_node, to_node):
	# Convert nodes to ID
	var from_id = nav_nodes.find(from_node)
	var to_id = nav_nodes.find(to_node)

	# Get raw points
	var point_path = astar.get_point_path(from_id, to_id)

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

	return point_path


### Private functions
## Navigation functions
func _update_navigation_path(bot, loc_index):
	var movement_path = get_directions(nav_nodes[bot.goal_location], nav_nodes[loc_index])

	# Set bot's movement path and properties
	if bot.position == movement_path[0]:
		movement_path.remove(0)
	bot.movement_path = movement_path
	bot.goal_location = loc_index
