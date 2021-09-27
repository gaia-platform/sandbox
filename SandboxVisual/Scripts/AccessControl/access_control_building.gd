extends Control
# Access Control demo main controller
# Manages setup of sim and gather all components together

# Node paths
export(NodePath) var error_panel_path
export(NodePath) var time_header_path
export(NodePath) var place_container_path
export(NodePath) var people_container_path
export(PackedScene) var building_node
export(PackedScene) var person_node
export(String, FILE) var scene_picker_scene

# Meta properties
var id_to_building: Dictionary
var id_to_room: Dictionary  # Two layers: building -> room
var id_to_person: Dictionary

# Get nodes
onready var error_panel = get_node(error_panel_path)
onready var time_header = get_node(time_header_path)
onready var place_container = get_node(place_container_path)
onready var people_container = get_node(people_container_path)


func _ready():
	# Subscribe to topics
	CommunicationManager.subscribe_to_topic("access_control/init")

	# Connect to signals
	var _connection_var = CommunicationManager.connect("ac_init", self, "_init_setup")
	_connection_var = CommunicationManager.connect(
		"ac_move_to_building", self, "_move_person_to_building"
	)
	_connection_var = CommunicationManager.connect("ac_move_to_room", self, "_move_person_to_room")

	CommunicationManager.select_project("access_control_template")


# Generate demo using data sent from Gaia
func _init_setup(setup_data):
	if setup_data != null:
		# Add buildings
		for building in setup_data["buildings"]:
			var new_building = building_node.instance()
			place_container.add_child(new_building)

			# Run setup deferred (to give time for item to load)
			new_building.call_deferred("set_building_init_properties", building, self)

			# Add location to ID dictionary
			id_to_building[String(building["building_id"])] = new_building.room_container

		# Add people
		for person in setup_data["people"]:
			var new_person = person_node.instance()
			people_container.add_child(new_person)

			# Run setup deferred (to give time for item to load)
			new_person.call_deferred(
				"set_person_init_properties", person, self, setup_data["buildings"][0], {}, false
			)

			# Add person to ID dictionary
			id_to_person[String(person["person_id"])] = new_person

		# Close the error panel (deferred) once everything runs
		error_panel.call_deferred("hide")


func _on_ExitButton_pressed():
	var change_scene_status = get_tree().change_scene(scene_picker_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)
	CommunicationManager.exit_project()


# Move person into a building. Moves them outside if no building is specified
func _move_person_to_building(person_id: String, building_id: String):
	var person = id_to_person[person_id]
	var target_location = (
		id_to_building[building_id]
		if id_to_building.has(building_id)
		else people_container
	)

	person.get_parent().remove_child(person)
	target_location.add_child(person)
	target_location.move_child(person, 0)

	person.update_options_for_inside_building(target_location != people_container)


# Moves person into a room in a given building
func _move_person_to_room(person_id: String, building_id: String, room_id: String):
	var person = id_to_person[person_id]
	var room = id_to_room[building_id][room_id]

	person.get_parent().remove_child(person)
	room.add_child(person)
	room.move_child(person, 0)

	person.update_options_for_inside_building(true)
