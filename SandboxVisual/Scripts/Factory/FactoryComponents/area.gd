extends PanelContainer

### Nodes
export (NodePath) var count_label_path
export (NodePath) var pallet_space_path
export (NodePath) var widget_space_path
export (Array, NodePath) var associated_waypoint_paths
export (NodePath) var popup_path
export (NodePath) var popup_action_button_path
export (NodePath) var popup_action_progress_path

onready var count_label = get_node(count_label_path)
onready var pallet_space = get_node(pallet_space_path)
onready var pallet_location = pallet_space.get_child(0)
onready var widget_space = get_node(widget_space_path)
onready var widget_grid = widget_space.get_child(0)
onready var popup = get_node(popup_path)
onready var popup_action_button = get_node(popup_action_button_path)
onready var popup_action_progress = get_node(popup_action_progress_path)

onready var tween = $Tween

### Properties
var associated_waypoints: Array
var pallet_node = null

### Signals
signal new_pallet_added
signal new_node_added(node)


func _ready():
	for associated_waypoint_path in associated_waypoint_paths:
		associated_waypoints.append(get_node(associated_waypoint_path))


func add_node(node):
	if widget_space.visible:
		widget_grid.add_node(node)
		emit_signal("new_node_added", node)
	else:
		if pallet_node != null:
			pallet_node.add_widget(node)


func add_pallet(pallet):
	if pallet_space.visible and not pallet_node:
		pallet.move_to(pallet_location.get_location())
		pallet_node = pallet
		pallet.connect("leaving_area", self, "_cleanup_pallet", [], CONNECT_ONESHOT)
		emit_signal("new_pallet_added")


func show_popup_button(show = true, hide_delay = 0):
	if show and not popup.visible:
		popup.rect_global_position = rect_global_position
		popup.rect_size = rect_size
		popup.show()
	elif not show and popup.visible:
		if hide_delay > 0:
			yield(
				get_tree().create_timer(
					hide_delay / get_tree().get_current_scene().simulation_controller.speed_scale
				),
				"timeout"
			)
		popup.hide()


func run_popup_progress_bar(duration: float):
	if not popup.visible:
		# Set popup position and size
		popup.rect_global_position = rect_global_position
		popup.rect_size = rect_size
		popup_action_button.hide()
		popup.show()

	# Run progress bar
	popup_action_progress.show()
	tween.remove_all()
	tween.interpolate_property(
		popup_action_progress,
		"value",
		0,
		100,
		duration / get_tree().get_current_scene().simulation_controller.speed_scale,
		Tween.TRANS_SINE,
		Tween.EASE_IN_OUT
	)
	tween.connect("tween_all_completed", self, "show_popup_button", [false, 1], CONNECT_ONESHOT)
	tween.start()


func get_next_payload():
	if pallet_node:
		return pallet_node
	if widget_grid.node_to_spaces.size():
		return widget_grid.node_to_spaces.keys()[0]
	return null


### Private methods
func _cleanup_pallet():
	pallet_node = null
