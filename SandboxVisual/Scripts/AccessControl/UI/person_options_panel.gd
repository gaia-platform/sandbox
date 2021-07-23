extends PanelContainer

# Button paths
export (NodePath) var button_one_path
export (NodePath) var button_two_path
export (NodePath) var button_three_path

# Get their nodes
onready var button_one = get_node(button_one_path)
onready var button_two = get_node(button_two_path)
onready var button_three = get_node(button_three_path)
