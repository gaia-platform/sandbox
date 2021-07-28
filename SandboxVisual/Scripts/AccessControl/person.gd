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
var room_id: int
var building_id: int


func _ready():
	for button in building_options.buttons + other_options.buttons:
		button.connect("pressed", self, "_person_option_selected", [button])


### Signal Methods
func _person_option_selected(button: Button):
	# Detect what kind
	var texture_path = button.get_button_icon().get_path()
	var scan_type_value: String

	if "badge" in texture_path:
		scan_type_value = "badge"
	elif "laugh" in texture_path:
		scan_type_value = "face"
	elif "sign" in texture_path:
		scan_type_value = "leaving"
	elif "parking" in texture_path:
		scan_type_value = "vehicle_departing" if button.selected else "vehicle_entering"  # If selected, user is pressing to deselect
	elif "wifi" in texture_path:
		scan_type_value = "leaving_wifi" if button.selected else "joining_wifi"

	# Create message
	var publish_dict = {
		"scan_type": scan_type_value,
		"person_id": person_id,
		"building_id": building_id,
		"room_id": room_id
	}
	CommunicationManager.publish_to_topic("access_control/scan", to_json(publish_dict))


### Methods
## Set person properties
func set_person_init_properties(
	person: Dictionary, building: Dictionary, room: Dictionary = {}, inside_building: bool = true
):
	# Set name label
	var name_text_suffix = (
		"Employee"
		if person["employee"]
		else "Visitor" if person["visitor"] else "Stranger" if person["stranger"] else ""
	)

	name_label.text = "%s - %s" % [person["first_name"], name_text_suffix]

	# ID
	person_id = person["person_id"]
	building_id = building["building_id"]
	if not room.empty():
		room_id = room["room_id"]

	# Building option label
	building_options.options_label.text = building["name"]

	# Building options state
	building_options.button_one.visible = not person["stranger"] or not inside_building  # Don't show if inside or if stranger
	if building_options.button_one.visible:  # Set state if still visible
		building_options.button_one.set_state(person["badged"])

	building_options.button_three.visible = inside_building  # Show exit button if inside room or building

	# Other options state
	other_options.button_one.set_state(person["parked"])
	other_options.button_two.set_state(person["on_wifi"])

	# Schedule
	schedule_panel.add_schedule_events(person["events"], true)
