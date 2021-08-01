extends Control

export (int, "-", "|", "+", "T", "-|", "|-", "T-Up", "L", "_|", "r", "r-left") var path_shape


func _ready():
	_on_PathContainer_resized()


func _on_PathContainer_resized():
	# Get reference to path line
	var path_line = $PathLine

	# Reset path line for recalculation
	path_line.clear_points()

	# Get new container size
	var container_size = get_size()
	var container_size_half_y = container_size.y / 2
	var container_size_half_x = container_size.x / 2

	var center_vector = Vector2(container_size_half_x, container_size_half_y)
	var left_vector = Vector2(0, container_size_half_y)
	var right_vector = Vector2(container_size.x, container_size_half_y)
	var up_vector = Vector2(container_size_half_x, 0)
	var down_vector = Vector2(container_size_half_x, container_size.y)

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
