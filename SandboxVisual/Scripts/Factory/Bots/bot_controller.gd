extends KinematicBody2D

#### Variables
### Properties
export (String) var bot_id
export (int, "WidgetBot", "PalletBot") var bot_type
export (int) var max_payload_weight
export (float) var max_speed
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


func _ready():
	CommunicationManager.subscribe_to_topic("factory/%s/move_location" % bot_id)
	CommunicationManager.subscribe_to_topic("factory/%s/status_request" % bot_id)


func _physics_process(delta):
	if ! is_broken && movement_path.size() > 0:  # There is still a goal coordinate to reach
		var cur_dir = (movement_path[0] - position).normalized()  # Vector pointing towards next goal point
		var movement_step = (cur_dir * delta).clamped(max_speed * delta)  # Movement increment, clamped to max speed
		var post_movement_dir = movement_path[0] - (position + movement_step)  # Vector pointing towards goal point, but after step
		var cur_dot_post = cur_dir.dot(post_movement_dir)  # Get alignment of current direction vector and post step vector to goal

		if cur_dot_post < 0:  # If directions are pointing towards each other (meaning next step overshoots goal)
			position = movement_path[0]  # Lock to goal point
			movement_path.remove(0)  # Remove this goal point
		else:  # Otherwise, continue moving
			cur_speed_squared = movement_step.length_squared()  # Update speed

			# Move and check for collisions
			var bot_collision = move_and_collide(movement_step)
			if bot_collision != null:
				is_broken = true
	elif ! is_broken && ! movement_path.size():  # Stop at final position
		cur_speed_squared = 0
		var _stop_movement = move_and_collide(Vector2.ZERO)
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
