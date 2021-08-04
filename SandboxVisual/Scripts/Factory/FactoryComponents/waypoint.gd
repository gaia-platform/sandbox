extends Panel

export (Array, NodePath) var connected_node_paths
var connected_nodes: Array


func _ready():
	# Generate list of connected nodes
	for node_path in connected_node_paths:
		connected_nodes.append(get_node(node_path))


# Return center point
func get_location():
	var half_size = rect_size.x / 2
	return Vector2(rect_global_position.x + half_size, rect_global_position.y + half_size)
