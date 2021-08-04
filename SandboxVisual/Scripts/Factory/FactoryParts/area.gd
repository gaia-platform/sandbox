extends PanelContainer

export (NodePath) var count_label_path
export (NodePath) var pallet_space_path
export (NodePath) var widget_space_path

onready var count_label = get_node(count_label_path)
onready var pallet_space = get_node(pallet_space_path)
onready var widget_space = get_node(widget_space_path)
onready var widget_grid = widget_space.get_child(0)

