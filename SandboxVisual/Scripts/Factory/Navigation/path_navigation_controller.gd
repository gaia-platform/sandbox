extends Node

# Exports to pick waypoint and paths
export (Array, NodePath) var waypoint_paths
export (Array, NodePath) var path_paths

# Store waypoint and path nodes
var waypoints: Array
var paths: Array

# Create astar navigator
onready var astar = AStar2D.new()

# Map node to location ID
var node_to_id: Dictionary

func _ready():
	# Generate array with nodes
	for waypoint_path in waypoint_paths:
		waypoints.append(get_node(waypoint_path))
	for path_path in path_paths:
		paths.append(get_node(path_path))
	
	# Generate connections
	create_connections()

# Generate astar map
func create_connections():
	pass

# Generate array of locations to travel
func get_directions(from_node, to_node):
	# Convert nodes to ID
	var from_id = node_to_id.get(from_node)
	var to_id = node_to_id.get(to_node)

	# Generate ID path
	var id_pathway = astar.get_id_path(from_id, to_id)

	# Convert to location
	var location_pathway: PoolVector2Array = []
	for id in id_pathway:
		var index_of_node = node_to_id.values().find(id) # Find the index of id
		if index_of_node != -1: # Use it to get corresponding node
			location_pathway.append(node_to_id.keys()[index_of_node].get_location()) # Then append coordinates
		else: # If there's an error, return whatever is calculated
			break
	
	return location_pathway

