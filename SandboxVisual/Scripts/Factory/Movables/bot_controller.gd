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
export (bool) var is_inside_area = false

### Nodes
onready var collision_shape = $CollisionShape2D
onready var tween = $Tween
onready var _factory = get_tree().get_current_scene()

### Navigation
var movement_path = []
var _movement_queue = []

### Properties
var payload_node = null
var is_pallet: bool

signal leaving_area


func _ready():
	CommunicationManager.subscribe_to_topic("factory/%s/move_location" % bot_id)
	CommunicationManager.subscribe_to_topic("factory/%s/status_request" % bot_id)


func _physics_process(delta):
	if not is_broken and movement_path.size():  # There is still a goal coordinate to reach
		var cur_dir = (movement_path[0] - position).normalized()  # Vector pointing towards next goal point
		var movement_step = cur_dir * max_speed * delta  # Movement increment
		var post_movement_dir = movement_path[0] - (position + movement_step)  # Vector pointing towards goal point, but after step
		var cur_dot_post = cur_dir.dot(post_movement_dir)  # Get alignment of current direction vector and post step vector to goal

		if cur_dot_post <= 0:  # If directions are pointing towards each other (meaning next step overshoots goal)
			position = movement_path[0]  # Lock to goal point
			movement_path.remove(0)  # Remove this goal point

			if movement_path.size():
				_animate_rotation()
		else:  # Otherwise, continue moving
			cur_speed_squared = movement_step.length_squared()  # Update speed

			# Move and check for collisions
			var bot_collision = move_and_collide(movement_step)
			if bot_collision != null:
				is_broken = true
	elif not is_broken and not movement_path.size():  # Stop at final position
		# Stop if needed
		if cur_speed_squared != 0:
			cur_speed_squared = 0
			var _stop_movement = move_and_collide(Vector2.ZERO)

		if collision_shape.disabled and not is_inside_area:
			collision_shape.disabled = false

		# Straighten bot if inside area (probabbly means charging)
		if is_inside_area:
			tween.remove_all()
			tween.interpolate_property(
				self,
				"rotation",
				null,
				Vector2.UP.angle(),
				0.2 / _factory.simulation_controller.speed_scale,
				Tween.TRANS_SINE,
				Tween.EASE_OUT
			)
			tween.start()

		# Check to see if there are more movements in the queue
		var next_movement = _movement_queue.pop_front()
		if next_movement:
			movement_path = next_movement
			_animate_rotation()
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


func move_to(location: Vector2):
	if is_inside_area and not collision_shape.disabled:
		collision_shape.disabled = true
		raise()
	_movement_queue.append([location])


func travel(path: PoolVector2Array):
	if is_inside_area:
		raise()
		move_to(path[0])  # Move to area waypoint
		path.remove(0)
		yield(get_tree(), "idle_frame")  # Wait for movement to start
		is_inside_area = false
		emit_signal("leaving_area")
	_movement_queue.append(path)


func pickup_payload(payload):
	if not payload_node:  # If there isn't already a payload registered
		var prev_global_pos = payload.global_position  # Get current global position
		payload.get_parent().remove_child(payload)  # Orphan
		add_child(payload)  # Add to this bot
		payload.global_position = prev_global_pos  # Reset position (get's messed up after parenting)
		payload.rotation = -rotation  # Also counter bot's rotation

		var payload_destination = Vector2.ZERO  # Send to center of widgit if it's a pallet
		if bot_type:  # Updates for PalletBot
			collision_shape.shape.extents = Vector2(53, 64)
			collision_shape.position = Vector2(40.5, 0)
			payload_destination = Vector2(52, 0)

		payload.move_to(payload_destination, true)  # Attach to payload
		payload_node = payload  # Register payload


func drop_payload(at_location):
	if payload_node:  # If there is a registered payload
		var prev_global_pos = payload_node.global_position  # Get global position
		remove_child(payload_node)  # Remove from bot
		payload_node.rotation = 0  # Reset rotation
		_factory.widgets.add_child(payload_node)  # Add back to widget pool
		payload_node.global_position = prev_global_pos  # Set position (get's messed up after parenting)
		if bot_type:  # Reset PalletBot
			collision_shape.shape.extents = Vector2(24, 24)
			collision_shape.position = Vector2.ZERO
			at_location.add_pallet(payload_node)  # Adds a pallet to location
		else:
			at_location.add_node(payload_node)  # Adds a widget to location
		payload_node = null  # Unregister payload


func _animate_rotation():
	tween.remove_all()
	tween.interpolate_property(
		self,
		"rotation",
		null,
		(movement_path[0] - position).angle(),
		0.2 / _factory.simulation_controller.speed_scale,
		Tween.TRANS_SINE,
		Tween.EASE_IN_OUT
	)
	tween.start()
