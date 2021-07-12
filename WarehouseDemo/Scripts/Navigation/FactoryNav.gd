extends Navigation2D

#### Variables
### Nodes
export (NodePath) var bots_node_path
onready var bots_node = get_node(bots_node_path)
onready var bots = bots_node.get_children()

### Member variables
export var location_index = 0
export var bot_speed = 400

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

var _movement_path = []

func _ready():
	bots[0].position = _factory_locations[location_index]

func _process(delta):
	var walk_distance = bot_speed * delta
	move_along_path(walk_distance)


func _input(event):
	if event.is_action_pressed("ui_accept"):
		location_index+=1
		if location_index == _factory_locations.size():
			location_index = 0

		_update_navigation_path(bots[0].position, _factory_locations[location_index])

# Navigation functions
func move_along_path(distance):
	var last_point = bots[0].position
	while _movement_path.size():
		var distance_between_points = last_point.distance_to(_movement_path[0])
		# The position to move to falls between two points.
		if distance <= distance_between_points:
			bots[0].position = last_point.linear_interpolate(_movement_path[0], distance / distance_between_points)
			return
		# The position is past the end of the segment.
		distance -= distance_between_points
		last_point = _movement_path[0]
		_movement_path.remove(0)
	# The character reached the end of the path.
	bots[0].position = last_point
	set_process(false)


func _update_navigation_path(start_position, end_position):
	# get_simple_path is part of the Navigation2D class.
	# It returns a PoolVector2Array of points that lead you
	# from the start_position to the end_position.
	_movement_path = get_simple_path(start_position, end_position, true)
	# The first point is always the start_position.
	# We don't need it in this example as it corresponds to the character's position.
	_movement_path.remove(0)
	set_process(true)
