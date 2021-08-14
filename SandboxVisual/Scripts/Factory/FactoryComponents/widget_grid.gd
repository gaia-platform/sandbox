extends GridContainer

### Properties
export (bool) var for_widgets
export (int) var capacity_limit

# Map widgets or bots to their assigned spaces
var node_to_spaces: Dictionary


func _ready():
	var _end_simulation_signal = get_tree().get_current_scene().connect(
		"end_simulation", self, "_remove_all_nodes"
	)


# Move a node into the area
func add_node(node):
	if not capacity_limit or node_to_spaces.size() + 1 <= capacity_limit:  # If there's no capacity or if you're still under it once a new node is added
		# Create new Control widget as a spacer; Set size accordingly
		var space = Control.new()
		if for_widgets:
			space.rect_min_size = Vector2(32, 32)
		else:
			space.rect_min_size = Vector2(48, 48)

		add_child(space)
		_resize_grid()
		yield(get_tree(), "idle_frame")  # Wait for grid to actually resize
		_recalculate_node_locations()  # Rearrange exsisting nodes

		node_to_spaces[node] = space  # Register this new node and its new space

		# Calculate position of space
		var half_size = space.rect_size.x / 2
		var location = Vector2(
			space.rect_global_position.x + half_size, space.rect_global_position.y + half_size
		)

		# Move the node to this location
		node.set("is_inside_area", true)
		node.connect("leaving_area", self, "remove_node", [node], CONNECT_ONESHOT)
		node.move_to(location)


# Remove node and space from grid
func remove_node(node):
	if node_to_spaces.has(node):
		node_to_spaces[node].queue_free()  # Delete space
		var _erase = node_to_spaces.erase(node)  # Remove from map
		_resize_grid()
		yield(get_tree(), "idle_frame")  # Wait for grid to actually resize
		_recalculate_node_locations()  # Rearrange exsisting nodes


# Try to make the grid a square
func _resize_grid():
	var target_columns = 1
	while target_columns * target_columns < get_child_count():  # Continue to add columns until its square can accomodate all children
		target_columns += 1
	columns = target_columns


# After grid is resized, need to move nodes to new positions
func _recalculate_node_locations():
	for node in node_to_spaces:
		var space = node_to_spaces[node]
		var half_size = space.rect_size.x / 2

		node.move_to(
			Vector2(
				space.rect_global_position.x + half_size, space.rect_global_position.y + half_size
			)
		)


func _remove_all_nodes():
	node_to_spaces.clear()
	for space in get_children():
		space.queue_free()
	_resize_grid()
