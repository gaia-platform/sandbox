extends KinematicBody2D

#### Variables
### Properties
export (String) var bot_id
export (int, "Bumblebee", "Bumblebee Stacker") var bot_type
export (int) var max_payload_weight
export (float) var max_speed
export (float) var speed_scale = 500
export (int) var battery_time
export (int) var charge_time

### State
export (int) var goal_location
export (float) var cur_speed_squared
export (float) var charge_level = 100
export (bool) var is_charging = false
export (bool) var is_broken = false

### Navigation
var movement_path = []
var _prev_distance_to_goal = -1
var _prev_recorded_seconds = -1


func _ready():
	CommunicationManager.subscribe_to_topic("factory/%s/move_location" % bot_id)
	CommunicationManager.subscribe_to_topic("factory/%s/status_request" % bot_id)


func _physics_process(delta):
	### Handle Movement
	if ! is_broken && movement_path.size() >= 2:  # There is still a goal coordinate to reach
		var cur_distance_to_goal = position.distance_squared_to(movement_path[1])
		if _prev_distance_to_goal == -1:
			_prev_distance_to_goal = cur_distance_to_goal

		if cur_distance_to_goal <= _prev_distance_to_goal:  # There is still distance to the next goal point
			_prev_distance_to_goal = cur_distance_to_goal
			var dir = (movement_path[1] - movement_path[0]).normalized()  # Normalized direction of movement
			var frame_speed_scale = speed_scale * delta
			var vel_vector = (dir * frame_speed_scale).clamped(max_speed * frame_speed_scale)  # Speed scaled, clamped, and delta-ed movement vector

			# Update status values
			cur_speed_squared = vel_vector.length_squared()

			var bot_collision = move_and_collide(vel_vector)
			if bot_collision != null:
				print(bot_collision.collider_id)
				is_broken = true
		else:
			var _stop_movement = move_and_collide(Vector2.ZERO)  # Stop movement
			_prev_distance_to_goal = -1
			cur_speed_squared = 0
			movement_path.remove(0)
	elif ! is_broken && movement_path.size() && position != movement_path[0]:
		position = movement_path[0]
	elif is_broken:
		if modulate != Color.red:
			var _stop_movement = move_and_collide(Vector2.ZERO)  # Stop movement
			modulate = Color.red  # Modulate to red


## Signal methods
# Status item
func publish_status_item(item: String):
	var payload
	match item:
		"id":
			payload = bot_id
		"type":
			payload = bot_type
		"goal_location":
			payload = goal_location
		"world_location":
			payload = position
		"charge_level":
			payload = charge_level
		"is_charging":
			payload = charge_level
		"speed_squared":
			payload = cur_speed_squared
		"is_broken":
			payload = is_broken
		_:
			print("Unknown status item request")

	CommunicationManager.publish_to_topic("factory/%s/%s" % [bot_id, item], payload)
