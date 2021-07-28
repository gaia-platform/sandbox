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

# Properties
var building_id: int
var room_id: int


### Methods
## Set building properties
func set_building_room_init_properties(room: Dictionary, building: Dictionary, ac_reference):
	# Room properties
	room_name_label.text = room["name"]
	building_id = building["building_id"]
	room_id = room["room_id"]

	# Add people
	for person in room["people"]:
		# Create and add instance to top of list
		var new_person = person_node.instance()
		people_container.add_child(new_person)
		people_container.move_child(new_person, 0)
		new_person.call_deferred("set_person_init_properties", person, building, room)

		# Add person to ID dictionary
		ac_reference.id_to_person[person["person_id"]] = new_person

	# Add schedule
	schedule_panel.add_schedule_events(room["events"])
