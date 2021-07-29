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
var id_to_bot: Dictionary


func _ready():
	for bot in bots:
		id_to_bot[bot.bot_id] = bot

		# Subscriptions
		CommunicationManager.subscribe_to_topic("factory/%s/move_location" % bot.bot_id)

	bots[0].position = floorplan_meta.locations[0]  #_factory_locations[_factory_stop.WS_START]

	var _move_location_signal_connect = CommunicationManager.connect(
		"factory_move_location", self, "_move_location"
	)


### Signal methods
func _input(event):
	if event.is_action_pressed("ui_accept"):
		location_index += 1
		if location_index == floorplan_meta.locations.size():
			location_index = 0

		_update_navigation_path(bots[0], location_index)


func _move_location(bot_id: String, location: int):
	if location >= 0 && location < floorplan_meta.locations.size():
		_update_navigation_path(id_to_bot[bot_id], location)


# Navigation functions
func _update_navigation_path(bot, loc_index):
	var movement_path = get_simple_path(bot.position, floorplan_meta.locations[loc_index])

	# Set bot's movement path and properties
	bot.movement_path = movement_path
	bot.location = loc_index
