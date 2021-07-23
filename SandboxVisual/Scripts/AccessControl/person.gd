extends PanelContainer

# Element Paths
export (NodePath) var name_label_path
export (NodePath) var building_options_path
export (NodePath) var other_options_path
export (NodePath) var schedule_panel_path

# Get their nodes
onready var name_label = get_node(name_label_path)
onready var building_options = get_node(building_options_path)
onready var other_options = get_node(other_options_path)
onready var schedule_panel = get_node(schedule_panel_path)

# Properties
var person_id: int


### Methods
## Set person properties
func set_person_properties(person: Dictionary, room: Dictionary = {}):
	# Set name label
	var name_text_suffix = (
		"Employee"
		if person["employee"]
		else "Visitor" if person["visitor"] else "Stranger" if person["stranger"] else ""
	)

	name_label.text = "%s - %s" % [person["first_name"], name_text_suffix]

	# TODO: Room stuff?
	if room != {}:
		pass

	# Options
	set_button_options_states(person)

	# Schedule
	schedule_panel.add_schedule_events(person["events"], true)


## Set building title label
func set_building_options_label(building: Dictionary):
	building_options.options_label.text = "%s door" % building["name"]


## Set button options state
func set_button_options_states(person: Dictionary):
	if person["parked"]:
		other_options.button_one.press_button()
	if person["on_wifi"]:
		other_options.button_two.press_button()

	# Badge
	if person["stranger"]:
		building_options.button_one.hide()
	elif person["badged"]:
		building_options.button_one.press_button()
