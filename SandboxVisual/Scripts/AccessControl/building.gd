extends PanelContainer

# Node paths
export (NodePath) var building_name_label_path
export (NodePath) var room_container_path
export (PackedScene) var building_room_node
export (PackedScene) var person_node

# Get their nodes
onready var building_name_label = get_node(building_name_label_path)
onready var room_container = get_node(room_container_path)


### Methods
## Set building properties
func set_building_init_properties(building: Dictionary):
	# Set building name
	building_name_label.text = building["name"]

	# Populate with people
	for person in building["people"]:
		var new_person = person_node.instance()
		room_container.add_child(new_person)
		new_person.call_deferred("set_person_init_properties", person, building, {}, true)

	# Populate with rooms
	for room in building["rooms"]:
		var new_room = building_room_node.instance()
		room_container.add_child(new_room)
		new_room.call_deferred("set_building_room_init_properties", room, building)
