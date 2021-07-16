extends KinematicBody2D

#### Variables
### Properties
export (int) var payload_weight
export (float) var max_speed
export (float) var speed_scale = 500
export (int) var batter_time
export (int) var charge_time
export (bool) var is_broken = false

### Navigation
var movement_path = []
var prev_distance_to_goal = -1


func _physics_process(delta):
	if ! is_broken && movement_path.size() >= 2:  # There is still a goal coordinate to reach
		var cur_distance_to_goal = position.distance_squared_to(movement_path[1])
		if prev_distance_to_goal == -1:
			prev_distance_to_goal = cur_distance_to_goal

		if cur_distance_to_goal <= prev_distance_to_goal:  # There is still distance to the next goal point
			prev_distance_to_goal = cur_distance_to_goal
			var dir = (movement_path[1] - movement_path[0]).normalized()  # Normalized direction of movement
			var frame_speed_scale = speed_scale * delta
			var vel_vector = (dir * frame_speed_scale).clamped(max_speed * frame_speed_scale)  # Speed scaled, clamped, and delta-ed movement vector

			var bot_collision = move_and_collide(vel_vector)
			if bot_collision != null:
				print(bot_collision.collider_id)
				is_broken = true
		else:
			var _stop_movement = move_and_collide(Vector2.ZERO)  # Stop movement
			prev_distance_to_goal = -1
			movement_path.remove(0)
	elif ! is_broken && movement_path.size() && position != movement_path[0]:
		position = movement_path[0]
	elif is_broken:
		if modulate != Color.red:
			var _stop_movement = move_and_collide(Vector2.ZERO)  # Stop movement
			modulate = Color.red  # Modulate to red
