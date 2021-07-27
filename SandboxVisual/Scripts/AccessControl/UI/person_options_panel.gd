extends PanelContainer

# Button paths
export (NodePath) var options_label_path
export (NodePath) var button_container_path
export (NodePath) var button_one_path
export (NodePath) var button_two_path
export (NodePath) var button_three_path

# Get their nodes
onready var options_label = get_node(options_label_path)
onready var button_container = get_node(button_container_path)
onready var button_one = get_node(button_one_path)
onready var button_two = get_node(button_two_path)
onready var button_three = get_node(button_three_path)

# Buttons as an array
onready var buttons = button_container.get_children()
