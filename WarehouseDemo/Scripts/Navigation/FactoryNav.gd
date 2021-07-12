extends Navigation2D

#### Variables
### Nodes
export (NodePath) var bots_node_path
onready var bots_node = get_node(bots_node_path)
onready var bots = bots_node.get_children()

### Member variables
export var location_index = 0

const _factory_locations = [
	Vector2(485, 496),  # WS Start
	Vector2(120, 440),  # Production Line
	Vector2(485, 384),  # WS End
	Vector2(784, 336),  # Packaging Line
	Vector2(664, 264),  # Inbound
	Vector2(1024, 440),  # Buffer Area 0/1
	Vector2(1096, 440),  # Buffer Area 2/3
	Vector2(792, 496),  # Kitting Area 0/1
	Vector2(792, 568),  # Kitting Area 2/3
	Vector2(624, 496),  # Charging Area 0
	Vector2(688, 496),  # Charging Area 1
]
enum _factory_stop {
	WS_START,
	PRODUCTION_LINE,
	WS_END,
	PACKAGING_LINE,
	INBOUND,
	BUFFER_AREA_0,
	BUFFER_AREA_1,
	KITTING_AREA_0,
	KITTING_AREA_1,
	CHARGING_AREA_0,
	CHARGING_AREA_1
}


func _ready():
	bots[0].position = _factory_locations[_factory_stop.WS_START]
	# bots[1].position = _factory_locations[_factory_stop.CHARGING_AREA_0]
	# bots[2].position = _factory_locations[_factory_stop.BUFFER_AREA_1]


func _input(event):
	if event.is_action_pressed("ui_accept"):
		location_index += 1
		if location_index == _factory_locations.size():
			location_index = 0

		_update_navigation_path(bots[0], _factory_locations[location_index])

		# var index_shift = 0
		# for bot in bots:
		# 	_update_navigation_path(bot, _factory_locations[location_index])


# Navigation functions
func _update_navigation_path(bot, end_position):
	# get_simple_path is part of the Navigation2D class.
	# It returns a PoolVector2Array of points that lead you
	# from the start_position to the end_position.
	var movement_path = get_simple_path(bot.position, end_position, true)

	# Set bot's movement path
	bot.movement_path = movement_path
