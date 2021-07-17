extends Navigation2D

#### Variables
### Nodes
export (NodePath) var bots_node_path
onready var bots_node = get_node(bots_node_path)
onready var bots = bots_node.get_children()

### Member variables
export var location_index = 0

const _factory_locations = [
	Vector2(484, 520),  # WS Start
	Vector2(125, 424),  # Production Line
	Vector2(486, 368),  # WS End
	Vector2(813, 337),  # Packaging Line
	Vector2(659, 243),  # Inbound
	Vector2(1025, 464),  # Buffer Area 0/1
	Vector2(1090, 464),  # Buffer Area 2/3
	Vector2(816, 497),  # Kitting Area 0/1
	Vector2(816, 568),  # Kitting Area 2/3
	Vector2(620, 520),  # Charging Area 0
	Vector2(685, 520),  # Charging Area 1
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


func _physics_process(_delta):
	if CommunicationManager.is_working:
		var loc = CommunicationManager.read_variable("robot_location")
		if loc != location_index && loc >= 0 && loc < _factory_locations.size():
			location_index = loc
			_update_navigation_path(bots[0], location_index)


func _input(event):
	if event.is_action_pressed("ui_accept"):
		location_index += 1
		if location_index == _factory_locations.size():
			location_index = 0

		_update_navigation_path(bots[0], location_index)


# Navigation functions
func _update_navigation_path(bot, loc_index):
	var movement_path = get_simple_path(bot.position, _factory_locations[loc_index])

	# Set bot's movement path and properties
	bot.movement_path = movement_path
	bot.location = loc_index
