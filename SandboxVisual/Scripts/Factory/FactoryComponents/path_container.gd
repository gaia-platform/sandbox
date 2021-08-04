extends Control

export (int, "-", "|", "+", "T", "-|", "|-", "T-Up", "L", "_|", "r", "r-left") var path_shape
export (Array, NodePath) var connected_node_paths

var connected_nodes: Array


func _ready():
	# Generate list of connected nodes
	for node_path in connected_node_paths:
		connected_nodes.append(get_node(node_path))

	# Run init shape creation
	_on_PathContainer_resized()


func _on_PathContainer_resized():
	# Get reference to path line
	var path_line = $PathLine

	# Reset path line for recalculation
	path_line.clear_points()

	# Get new container size
	var container_size = get_size()

	# Calculate used points
	var center_vector = container_size / 2
	var left_vector = Vector2(-20, center_vector.y)
	var right_vector = Vector2(container_size.x + 20, center_vector.y)
	var up_vector = Vector2(center_vector.x, -20)
	var down_vector = Vector2(center_vector.x, container_size.y + 20)

	match path_shape:
		0:  # -
			path_line.set_points(PoolVector2Array([right_vector, left_vector]))
		1:  # |
			path_line.set_points(PoolVector2Array([up_vector, down_vector]))
		2:  # +
			path_line.set_points(
				PoolVector2Array([up_vector, down_vector, center_vector, right_vector, left_vector])
			)
		3:  # T
			path_line.set_points(
				PoolVector2Array([down_vector, center_vector, right_vector, left_vector])
			)
		4:  # -|
			path_line.set_points(
				PoolVector2Array([left_vector, center_vector, up_vector, down_vector])
			)
		5:  # |-
			path_line.set_points(
				PoolVector2Array([right_vector, center_vector, up_vector, down_vector])
			)
		6:  # T-Up
			path_line.set_points(
				PoolVector2Array([up_vector, center_vector, right_vector, left_vector])
			)
		7:  # L
			path_line.set_points(PoolVector2Array([up_vector, center_vector, right_vector]))
		8:  # _|
			path_line.set_points(PoolVector2Array([left_vector, center_vector, up_vector]))
		9:  # r
			path_line.set_points(PoolVector2Array([right_vector, center_vector, down_vector]))
		10:  # r-left
			path_line.set_points(PoolVector2Array([left_vector, center_vector, down_vector]))
		_:
			print("Unknown size requested")


func get_location():
	var half_dim = rect_size / 2
	return Vector2(rect_global_position.x + half_dim.x, rect_global_position.y + half_dim.y)
