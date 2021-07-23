extends Control

# Node paths
export (NodePath) var error_panel_path
export (NodePath) var time_header_path
export (NodePath) var place_container_path
export (NodePath) var people_container_path
export (PackedScene) var building_node
export (PackedScene) var person_node

# Get their nodes
onready var error_panel = get_node(error_panel_path)
onready var time_header = get_node(time_header_path)
onready var place_container = get_node(place_container_path)
onready var people_container = get_node(people_container_path)


func _ready():
	var setup_data = CommunicationManager.get_setup_data()
	if setup_data != null:
		print("Running root")
		# Add buildings
		for building in setup_data["buildings"]:
			var new_building = building_node.instance()
			place_container.add_child(new_building)
			# Run setup deferred (to give time for item to load)
			new_building.call_deferred("set_building_properties", building)

		# Add people
		for person in setup_data["people"]:
			var new_person = person_node.instance()
			people_container.add_child(new_person)

			# Run setup deferred (to give tiem for item to load)
			new_person.call_deferred("set_person_properties", person)

		# Close the error panel (deferred) once everything runs
		error_panel.call_deferred("_on_CloseButton_pressed")
