extends PanelContainer

# Node paths and room name
export (NodePath) var room_name_label_path
export (NodePath) var people_container_path
export (NodePath) var schedule_panel_path
export (PackedScene) var person_node

# Get their nodes
onready var room_name_label = get_node(room_name_label_path)
onready var people_container = get_node(people_container_path)
onready var schedule_panel = get_node(schedule_panel_path)


### Methods
## Set building properties
func set_building_room_properties(room: Dictionary):
	# Room name
	room_name_label.text = room["name"]

	# Add people
	for person in room["people"]:
		# Create and setup instance
		var new_person = person_node.instance()
		new_person.set_person_properties(person, room)

		# Add to top of list
		people_container.add_child(new_person)
		people_container.move_child(new_person, 0)

	# Add schedule
	schedule_panel.add_schedule_events(room["events"])
