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

## Methods
# Set state of other options buttons
func set_other_options(person: Dictionary):
    if !person["parked"]:
        other_options.button_one.hide()
    if !person["on_wifi"]:
        other_options.button_two.hide()