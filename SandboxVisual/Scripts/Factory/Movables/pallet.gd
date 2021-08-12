extends Sprite

# Get Widget grid
export (NodePath) var widget_grid_path
onready var widget_grid = get_node(widget_grid_path)
onready var widget_spaces = widget_grid.get_children()

# Get Tween
onready var tween = $Tween

# Get WidgetHolder
onready var widget_holder = $WidgetHolder

# Widgets
var widgets = [null, null, null, null]

# Get factory
onready var _factory = get_tree().get_current_scene()


func move_to(location: Vector2, _leaving = null):
	tween.remove_all()  # Reset all
	# Linearly move to location in 0.5 seconds
	tween.interpolate_property(
		self,
		"position",
		position,
		location,
		0.5 / get_tree().get_current_scene().simulation_controller.speed_scale,
		Tween.TRANS_SINE,
		Tween.EASE_IN_OUT
	)
	tween.start()


func add_widget(widget):
	# Find empty space
	var first_empty = widgets.find(null)
	if first_empty > -1:  # There's an open space on the pallet
		# Add to next open location
		widgets[first_empty] = widget

		# Reparent
		var widget_glob_pos = widget.global_position
		widget.get_parent().remove_child(widget)
		add_child(widget)
		widget.global_position = widget_glob_pos

		# Calculate position of space
		var space = widget_spaces[first_empty]
		var half_size = space.rect_size.x / 2
		var location = Vector2(
			space.rect_global_position.x + half_size, space.rect_global_position.y + half_size
		)
		var local_loc = to_local(location)

		# Move the node to this location
		widget.set("is_inside_area", true)
		widget.connect("leaving_area", self, "remove_widget", [widget])
		widget.move_to(local_loc)


func remove_widget(widget):
	var index_of_widget = widgets.find(widget)
	if index_of_widget > -1:
		widgets.remove(index_of_widget)

		# Reparent
		var widget_glob_pos = widget.global_position
		remove_child(widget_glob_pos)
		_factory.widgets.add_child(widget)
		widget.global_position = widget_glob_pos

		widget.disconnect("leaving_area", self, "remove_widget")
