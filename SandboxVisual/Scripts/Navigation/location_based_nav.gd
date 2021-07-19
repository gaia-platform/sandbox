extends Navigation2D

#### Variables
### Nodes
export (NodePath) var bots_node_path
onready var bots_node = get_node(bots_node_path)
onready var bots = bots_node.get_children()

export (NodePath) var floorplan_meta_path
onready var floorplan_meta = get_node(floorplan_meta_path)

### Member variables
export var location_index = 0


func _ready():
	bots[0].position = floorplan_meta.locations[0]  #_factory_locations[_factory_stop.WS_START]


func _physics_process(_delta):
	if CommunicationManager.is_working:
		var loc = CommunicationManager.read_variable("robot_location")
		if loc != location_index && loc >= 0 && loc < floorplan_meta.locations.size():
			location_index = loc
			_update_navigation_path(bots[0], location_index)


func _input(event):
	if event.is_action_pressed("ui_accept"):
		location_index += 1
		if location_index == floorplan_meta.locations.size():
			location_index = 0

		_update_navigation_path(bots[0], location_index)


# Navigation functions
func _update_navigation_path(bot, loc_index):
	var movement_path = get_simple_path(bot.position, floorplan_meta.locations[loc_index])

	# Set bot's movement path and properties
	bot.movement_path = movement_path
	bot.location = loc_index
