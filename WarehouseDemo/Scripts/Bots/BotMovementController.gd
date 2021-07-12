extends KinematicBody2D

#### Variables
### Properties
export (int) var payload_weight
export (float) var max_speed
export (float) var speed_scale = 500
export (int) var batter_time
export (int) var charge_time

### Navigation
var movement_path = []


func _physics_process(delta):
	if movement_path.size() >= 2:  # There is still a goal coordinate to reach
		if position.distance_squared_to(movement_path[1]) > 25:  # There is still distance to the next goal point
			var dir = (movement_path[1] - movement_path[0]).normalized()  # Normalized direction of movement
			var frame_speed_scale = speed_scale * delta
			var vel_vector = (dir * frame_speed_scale).clamped(max_speed * frame_speed_scale)  # Speed scaled, clamped, and delta-ed movement vector

			var _bot_collision = move_and_collide(vel_vector)
		else:
			var _stop_movement = move_and_collide(Vector2.ZERO)  # Stop movement
			movement_path.remove(0)
	else:
		if movement_path.size() && position != movement_path[0]:
			position = movement_path[0]
