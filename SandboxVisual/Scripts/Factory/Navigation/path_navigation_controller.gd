extends Node

# Exports to pick waypoint and paths
export (Array, NodePath) var nav_node_paths

export (NodePath) var test_bot_path
onready var test_bot = get_node(test_bot_path)

# Store waypoint and path nodes
var nav_nodes: Array

# Create astar navigator
onready var astar = AStar2D.new()

# Map node to location ID
var node_to_id: Dictionary


func _ready():
	# Generate array with nodes
	for nav_item_path in nav_node_paths:
		nav_nodes.append(get_node(nav_item_path))

	# Generate connections
	while owner.number_of_waypoints == -1:  # Wait until number of waypoints is calculated
		yield(get_tree(), "idle_frame")
	create_connections()
	test_bot.movement_path = get_directions(nav_nodes[3], nav_nodes[4])


### Generate astar map
func create_connections():
	# Create nav points
	for nav_node in nav_nodes:
		astar.add_point(nav_nodes.find(nav_node), nav_node.get_location())

	# Connect points. Only need to use path which will cover for waypoints
	for path_id in range(owner.number_of_waypoints, nav_nodes.size()):
		for node in nav_nodes[path_id].connected_nodes:
			astar.connect_points(path_id, nav_nodes.find(node))


# Generate array of locations to travel
func get_directions(from_node, to_node):
	# Convert nodes to ID
	var from_id = nav_nodes.find(from_node)
	var to_id = nav_nodes.find(to_node)

	# Generate ID path
	var id_pathway = astar.get_id_path(from_id, to_id)

	# Convert to location
	var location_pathway: PoolVector2Array = []
	for id in id_pathway:
		location_pathway.append(nav_nodes[id].get_location())  # Then append coordinates

	return location_pathway
