extends PanelContainer

# Nodes
export (PackedScene) var schedule_item
export (NodePath) var schedule_list_path
onready var schedule_list = get_node(schedule_list_path)
