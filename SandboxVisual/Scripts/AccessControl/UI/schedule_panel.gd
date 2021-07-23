extends PanelContainer

# Nodes
export (PackedScene) var event_label
export (NodePath) var event_list_path
onready var event_list = get_node(event_list_path)


# Methods
func add_schedule_events(events: Dictionary, with_room_name: bool):
	pass
