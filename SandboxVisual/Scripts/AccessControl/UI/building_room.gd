extends PanelContainer

# Properties
export (String) var room_name
export (NodePath) var schedule_panel_path
onready var schedule_panel = get_node(schedule_panel_path)


func _ready():
	pass
