extends Navigation2D

#### Variables
### Nodes
export (NodePath) var bots_node_path
onready var bots_node = get_node(bots_node_path)
onready var bots = bots_node.get_children()

export (NodePath) var floorplan_meta_path
onready var floorplan_meta = get_node(floorplan_meta_path)

### Member variables
export var _location_index = 0
var id_to_bot: Dictionary


func _ready():
	for bot in bots:
		id_to_bot[bot.bot_id] = bot

	bots[0].position = floorplan_meta.locations[0]  #_factory_locations[_factory_stop.WS_START]

	var _connect_to_signal = CommunicationManager.connect(
		"factory_move_location", self, "_move_location"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_status_request", self, "_bot_status_request"
	)


### Signal methods
func _input(event):
	if event.is_action_pressed("ui_accept"):
		_location_index += 1
		if _location_index == floorplan_meta.locations.size():
			_location_index = 0

		_update_navigation_path(bots[0], _location_index)


func _move_location(bot_id: String, location: int):
	if location >= 0 && location < floorplan_meta.locations.size():
		_update_navigation_path(id_to_bot[bot_id], location)


func _bot_status_request(bot_id: String, status_item: String):
	var target_bot = id_to_bot[bot_id]
	target_bot.publish_status_item(status_item)


# Navigation functions
func _update_navigation_path(bot, loc_index):
	var movement_path = get_simple_path(bot.position, floorplan_meta.locations[loc_index])

	# Set bot's movement path and properties
	bot.movement_path = movement_path
	bot.goal_location = loc_index
