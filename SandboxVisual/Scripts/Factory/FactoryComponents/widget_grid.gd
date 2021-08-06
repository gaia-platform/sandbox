extends GridContainer

export (bool) var for_widgets
export (int) var capacity_limit

var node_to_spaces: Dictionary


func add_node(node):
	if ! capacity_limit || node_to_spaces.size() + 1 <= capacity_limit:
		var space = Control.new()
		if for_widgets:
			space.rect_min_size = Vector2(32, 32)
		else:
			space.rect_min_size = Vector2(48, 48)

		add_child(space)
		_resize_grid()
		yield(get_tree(), "idle_frame")
		_recalculate_node_locations(node)

		node_to_spaces[node] = space

		var half_size = space.rect_size.x / 2
		var location = Vector2(
			space.rect_global_position.x + half_size, space.rect_global_position.y + half_size
		)

		node.is_inside_area = true
		node.move_to(location)


func remove_node(node):
	var _erase = node_to_spaces.erase(node)
	_resize_grid()


func _resize_grid():
	var target_columns = 1
	while target_columns * target_columns < get_child_count():
		target_columns += 1
	columns = target_columns


func _recalculate_node_locations(excluding):
	for node in node_to_spaces:
		if node == excluding:
			print("Skipping")
			continue
		var space = node_to_spaces[node]
		var half_size = space.rect_size.x / 2
		node.position = Vector2(
			space.rect_global_position.x + half_size, space.rect_global_position.y + half_size
		)
