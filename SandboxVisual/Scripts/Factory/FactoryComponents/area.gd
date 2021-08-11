extends PanelContainer

export (NodePath) var count_label_path
export (NodePath) var pallet_space_path
export (NodePath) var widget_space_path
export (Array, NodePath) var associated_waypoint_paths
export (NodePath) var popup_path
export (NodePath) var popup_action_button_path

onready var count_label = get_node(count_label_path)
onready var pallet_space = get_node(pallet_space_path)
onready var pallet_location = pallet_space.get_child(0)
onready var widget_space = get_node(widget_space_path)
onready var widget_grid = widget_space.get_child(0)
onready var popup = get_node(popup_path)
onready var popup_action_button = get_node(popup_action_button_path)
var associated_waypoints: Array


func _ready():
	for associated_waypoint_path in associated_waypoint_paths:
		associated_waypoints.append(get_node(associated_waypoint_path))


func add_node(node):
	if widget_space.visible:
		widget_grid.add_node(node)


func add_pallet(pallet):
	if pallet_space.visible:
		var half_size = pallet_location.rect_size.x / 2
		var location = Vector2(
			pallet_location.rect_global_position.x + half_size,
			pallet_location.rect_global_position.y + half_size
		)
		pallet.move_to(location)


func show_popup(show = true, button_text = ""):
	if show and not popup.visible:
		popup.rect_global_position = rect_global_position
		popup.rect_size = rect_size
		popup_action_button.text = button_text
		popup.show()
	elif not show and popup.visible:
		popup.hide()


func _on_ActionButton_pressed():
	popup.hide()
