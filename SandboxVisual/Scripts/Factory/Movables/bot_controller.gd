extends KinematicBody2D
# WidgetBot and PalletBot main controller
# Handles actions and signals

signal departed_area

# Properties
export(String) var bot_id
export(int, "WidgetBot", "PalletBot") var bot_type
export(int) var max_payload_weight
export(float) var max_speed
export(float) var battery_time  # In seconds
export(float) var charge_time  # In seconds

# State
export(int) var goal_location
export(float) var cur_speed_squared
export(bool) var is_charging: bool
export(bool) var is_inside_area: bool

# Properties
var payload_node = null
var is_pallet: bool
var bot_collision: KinematicCollision2D
var report_success = true
var disabled_point = -1
var battery_used_time = 0
var disabled_out_of_battery = false
var reported_charged = false

# Navigation
var movement_path = []
var _movement_queue = []

# Nodes
onready var collision_shape = $CollisionShape2D
onready var tween = $Tween
onready var _factory = get_tree().get_current_scene()


func _ready():
	# Wait for any external init to complete
	yield(get_tree(), "idle_frame")

	# Then subscribe to topics
	CommunicationManager.subscribe_to_topic("bot/%s/move_location" % bot_id)
	CommunicationManager.subscribe_to_topic("bot/%s/charge" % bot_id)
	CommunicationManager.subscribe_to_topic("bot/%s/pickup_payload" % bot_id)
	CommunicationManager.subscribe_to_topic("bot/%s/drop_payload" % bot_id)
	CommunicationManager.subscribe_to_topic("bot/%s/status_request" % bot_id)


func _physics_process(delta):
	if movement_path.size() and not bot_collision and battery_used_time != battery_time:
		var cur_dir = (movement_path[0] - position).normalized()
		var movement_step = cur_dir * max_speed * delta
		var post_movement_dir = movement_path[0] - (position + movement_step)
		var cur_dot_post = cur_dir.dot(post_movement_dir)

		# Check if making a step will overshoot goal
		if cur_dot_post <= 0:
			position = movement_path[0]
			movement_path.remove(0)

			if movement_path.size():
				_animate_rotation()
		else:
			cur_speed_squared = movement_step.length_squared()

			# Unmodulate the color if it was previously changed (from collision)
			if modulate != Color.white:
				modulate = Color.white

			# Move and check for collisions
			bot_collision = move_and_collide(movement_step)

			# Add to battery used time
			battery_used_time += delta
			if battery_used_time > battery_time:
				battery_used_time = battery_time
	elif not movement_path.size() and not bot_collision and battery_used_time != battery_time:
		# Get reference to navigation; will use later
		var navigation_astar = _factory.navigation_controller.astar

		# Stop if needed
		if cur_speed_squared != 0:
			cur_speed_squared = 0
			var _stop_movement = move_and_collide(Vector2.ZERO)

			# Disable the navigation at this location (only if at waypoint)
			if not is_inside_area:
				disabled_point = navigation_astar.get_closest_point(position)
				navigation_astar.set_point_disabled(disabled_point)

			# Report success
			if report_success and not is_charging:
				CommunicationManager.publish_to_app(
					"bot/%s/arrived" % bot_id,
					_factory.navigation_controller.location_id(
						navigation_astar.get_closest_point(position, true)
					)
				)
			else:
				report_success = true

		# Handle charging
		if is_charging and is_inside_area:
			if battery_used_time > 0:
				if reported_charged:
					reported_charged = false
				battery_used_time -= delta * battery_time / charge_time
			elif battery_used_time <= 0:
				battery_used_time = 0
				if not reported_charged:
					CommunicationManager.publish_to_app("bot/is_charged", bot_id)
					reported_charged = true

		# Check to make sure collision shape is properly set
		if collision_shape.disabled and not is_inside_area:
			collision_shape.disabled = false

		# Straighten bot if inside area (probably means charging)
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
			# Set it as the new movement
			movement_path = next_movement
			_animate_rotation()

			# Re-enable the disabled point in navigation
			if not is_inside_area:
				if disabled_point != -1:
					navigation_astar.set_point_disabled(disabled_point, false)
					disabled_point = -1
	elif bot_collision or battery_used_time == battery_time:
		if modulate == Color.white:
			var _stop_movement = move_and_collide(Vector2.ZERO)  # Stop movement
			movement_path.resize(0)
			_movement_queue.clear()

			if disabled_point != -1:
				_factory.navigation_controller.astar.set_point_disabled(disabled_point, false)
				disabled_point = -1
		if bot_collision and modulate.g != 0:
			# Modulate to red without changing alpha
			modulate.r = 1
			modulate.g = 0
			modulate.b = 0

			CommunicationManager.publish_to_app(
				"bot/%s/crashed" % bot_id, _factory.navigation_controller.location_id(goal_location)
			)
		elif (
			battery_used_time == battery_time
			and modulate.a != 0.3
			and not disabled_out_of_battery
		):
			modulate.a = 0.3
			CommunicationManager.publish_to_app(
				"bot/%s/out_of_battery" % bot_id,
				_factory.navigation_controller.location_id(goal_location)
			)
			disabled_out_of_battery = true
			_factory.bot_ran_out_of_battery(self)


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
			payload = 1 - battery_used_time / battery_time
		"is_charging":
			payload = is_charging
		"speed_squared":
			payload = cur_speed_squared
		_:
			print("Unknown status item request")

	CommunicationManager.publish_to_app("bot/%s/info/%s" % [bot_id, item], payload)


func move_to(location: Vector2):
	if is_inside_area and not collision_shape.disabled:
		collision_shape.disabled = true
		raise()
	_movement_queue.append([location])


func travel(path: PoolVector2Array):
	if is_inside_area:
		raise()
		report_success = false

		move_to(path[0])
		path.remove(0)

		yield(get_tree(), "idle_frame")
		is_inside_area = false

		emit_signal("departed_area")
	_movement_queue.append(path)


func pickup_payload(payload):
	var succeed: bool
	if not payload_node and payload and payload.is_pallet == (bot_type == 1):
		var prev_global_pos = payload.global_position
		payload.get_parent().remove_child(payload)
		add_child(payload)
		payload.global_position = prev_global_pos
		payload.rotation = -rotation

		# Position payload in center (ZERO) if widget bot, otherwise shift it
		var payload_destination = Vector2.ZERO
		if bot_type:
			payload_destination = Vector2(52, 0)

		payload.move_to(payload_destination, true)
		payload_node = payload

		succeed = true

		if goal_location == _factory.navigation_controller.location_index("buffer"):
			_factory.receive_order_button.disabled = false

	CommunicationManager.publish_to_app(
		"bot/%s/payload_picked_up" % bot_id, payload.payload_id if succeed else false
	)


func drop_payload(area):
	var prev_global_pos = payload_node.global_position
	remove_child(payload_node)
	payload_node.rotation = 0

	if bot_type:
		_factory.pallets.add_child(payload_node)
		payload_node.global_position = prev_global_pos
		area.add_pallet(payload_node)
	else:
		_factory.widgets.add_child(payload_node)
		payload_node.global_position = prev_global_pos
		area.add_node(payload_node)
	payload_node = null

	# Tell Gaia the payload as been moved
	CommunicationManager.publish_to_app("bot/%s/payload_dropped" % bot_id, area.id)


func _animate_rotation():
	# Calculate correct angle for turning
	var goal_angle = (movement_path[0] - position).angle()
	if goal_angle - rotation > PI:
		goal_angle -= 2 * PI

	tween.remove_all()
	tween.interpolate_property(
		self, "rotation", null, goal_angle, 0.2, Tween.TRANS_SINE, Tween.EASE_IN_OUT
	)
	tween.start()
