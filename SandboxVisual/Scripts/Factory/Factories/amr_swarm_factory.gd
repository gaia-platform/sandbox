extends Control

### Nodes
# Areas
export (NodePath) var inbound_area_path
export (NodePath) var charging_station_path
export (NodePath) var buffer_area_path
export (NodePath) var pl_start_path
export (NodePath) var production_line_path
export (NodePath) var pl_end_path
export (NodePath) var outbound_area_path

onready var inbound_area = get_node(inbound_area_path)
onready var charging_station = get_node(charging_station_path)
onready var buffer_area = get_node(buffer_area_path)
onready var pl_start = get_node(pl_start_path)
onready var production_line = get_node(production_line_path)
onready var pl_end = get_node(pl_end_path)
onready var outbound_area = get_node(outbound_area_path)

onready var areas = [
	pl_start, pl_end, outbound_area, buffer_area, charging_station, inbound_area, production_line
]

var pallet_bots = []
var widget_bots = []
var number_of_waypoints = -1

# Widgets
export (NodePath) var widgets_path
onready var widgets = get_node(widgets_path)

# Navigation Controller
export (NodePath) var navigation_controller_path
onready var navigation_controller = get_node(navigation_controller_path)

#Pallets
export (NodePath) var pallets_path
onready var pallets = get_node(pallets_path)

# Simulation controllers and properties
export (NodePath) var simulation_controller_path
export (NodePath) var widget_bot_counter_path
export (NodePath) var pallet_bot_counter_path
export (NodePath) var change_bots_button_path
export (NodePath) var receive_order_button_path
export (NodePath) var change_bots_panel_path
export (NodePath) var apply_changed_bots_button_path
export (NodePath) var cancel_changed_bots_button_path
onready var simulation_controller = get_node(simulation_controller_path)
onready var widget_bot_counter = get_node(widget_bot_counter_path)
onready var pallet_bot_counter = get_node(pallet_bot_counter_path)
onready var change_bots_button = get_node(change_bots_button_path)
onready var receive_order_button = get_node(receive_order_button_path)
onready var change_bots_panel = get_node(change_bots_panel_path)
onready var apply_changed_bots_button = get_node(apply_changed_bots_button_path)
onready var cancel_changed_bots_button = get_node(cancel_changed_bots_button_path)

### To be spawned
export (PackedScene) var widget_bot_scene
export (PackedScene) var pallet_bot_scene
export (PackedScene) var widget_scene
export (PackedScene) var pallet_scene

### Properties
var _widget_in_pl_start = null
var _widget_in_production_line = null
var _screen_size = Vector2(930, 830)  # Set to default size at first

### Signals
signal end_simulation


func _ready():
	# Wait for everything to load in, then count number of waypoints
	yield(get_tree(), "idle_frame")
	CommunicationManager.subscribe_to_topic("running")

	CommunicationManager.subscribe_to_topic("receive_order")
	CommunicationManager.subscribe_to_topic("unpack_pallet")
	CommunicationManager.subscribe_to_topic("start_production")
	CommunicationManager.subscribe_to_topic("unload_pl")
	CommunicationManager.subscribe_to_topic("ship")

	CommunicationManager.publish_to_coordinator("project/select", "amr_swarm_template")
	var _connect_to_signal = CommunicationManager.connect("factory_running", self, "_init_app")

	number_of_waypoints = 0
	for area in areas:
		number_of_waypoints += area.associated_waypoints.size()

	# Connect signals
	buffer_area.connect("new_pallet_added", self, "_show_unpack_buffer_ui")
	pl_start.connect("new_node_added", self, "_show_start_production_ui")
	production_line.connect("new_node_added", self, "_prep_process_widget_in_production_line")
	pl_end.connect("new_node_added", self, "_handle_widget_in_pl_end")

	_connect_to_signal = CommunicationManager.connect(
		"factory_receive_order", self, "_auto_receive_order"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_unpack_pallet", self, "_auto_unpack_buffer"
	)
	_connect_to_signal = CommunicationManager.connect(
		"factory_start_production", self, "_auto_start_production"
	)
	_connect_to_signal = CommunicationManager.connect("factory_unload_pl", self, "_auto_unload_pl")
	_connect_to_signal = CommunicationManager.connect("factory_ship", self, "_auto_ship")

	# Populate bots
	_generate_bots()

	CommunicationManager.publish_to_app("ping", "running")


### Signals
func _init_app():
	var robot_types = [
		{"id": "pallet_bot", "pallet_capacity": 1, "widget_capacity": 0},
		{"id": "widget_bot", "pallet_capacity": 0, "widget_capacity": 1}
	]
	var areas_by_type = {
		"pallet_area":
		{
			"id": "pallet_area",
			"pallet_capacity": 1,
			"widget_capacity": 0,
			"robot_capacity": 1,
			"areas": []
		},
		"widget_area":
		{
			"id": "widget_area",
			"pallet_capacity": 0,
			"widget_capacity": 4,
			"robot_capacity": 1,
			"areas": []
		},
		"charging_station":
		{
			"id": "charging_station",
			"pallet_capacity": 0,
			"widget_capacity": 0,
			"robot_capacity": 9,
			"areas": []
		}
	}
	for area in areas:
		var new_area = {"id": area.id, "bots": {}}
		if area.id == "charging":
			new_area["bots"] = {"pallet_bot": pallet_bots, "widget_bot": widget_bots}
		areas_by_type[area.area_type]["areas"].append(new_area)

	CommunicationManager.publish_to_app(
		"factory_data", to_json({"robot_types": robot_types, "areas_by_type": areas_by_type})
	)

	yield(get_tree().create_timer(0.1), "timeout")  # Slight delay to wait for factory data to be processed

	# Create a new one outside the frame and move it in
	_generate_new_outbound_pallet(true)


# Use screen location proportions to approximate screen size adjusted position for nodes
func _on_FloorPath_resized():
	# Recalculate bot positions
	for bot in navigation_controller.bots.get_children():
		var bot_position_fraction = bot.position / _screen_size
		bot.position = rect_size * bot_position_fraction

	# Recalculate pallet positions
	for pallet in pallets.get_children():
		var pallet_position_fraction = pallet.position / _screen_size
		pallet.position = rect_size * pallet_position_fraction

	# Recalculate widget positions
	for widget in widgets.get_children():
		var widget_position_fraction = widget.position / _screen_size
		widget.position = rect_size * widget_position_fraction

	# Update screen size variable to new size
	_screen_size = rect_size


### Factory flow
## Change factory bots
# Button pressed to open change bots window
func _on_ChangeBotsButton_pressed():
	change_bots_panel.show()


func _on_ApplyButton_pressed():
	change_bots_panel.hide()

	# Remove everything from the simulation
	emit_signal("end_simulation")
	yield(get_tree(), "idle_frame")  # Wait for all processing to complete before deleting everything else
	for widget in widgets.get_children():  # Delete all remaining widgets
		widget.queue_free()
	for pallet in pallets.get_children():  # All remaining pallets
		pallet.queue_free()
	for bot in navigation_controller.bots.get_children():  # All remaining bots
		bot.queue_free()

	# Generate stuff
	_generate_bots()
	# _generate_new_outbound_pallet(true)

	# Reset inbound area
	receive_order_button.disabled = false
	inbound_area.pallet_node = null

	CommunicationManager.publish_to_app("ping", "running")


func _on_CancelButton_pressed():
	change_bots_panel.hide()


# Function to populate factory with new bots
func _generate_bots():
	var id_number = 0
	pallet_bots = []
	widget_bots = []
	for wb in widget_bot_counter.value:  # For the number of widget bots requested
		var wb_instance = widget_bot_scene.instance()  # Create instance

		wb_instance.global_position = charging_station.associated_waypoints[0].get_location()  # Set position to be the charging station waypoint
		# Set bot_id
		wb_instance.bot_id = String(id_number)
		id_number += 1
		# Set goal location to be the charging station (where they spawn)
		wb_instance.goal_location = 4
		# Disable success reporting
		wb_instance.report_success = false
		# Register in navigation controller
		navigation_controller.id_to_bot[wb_instance.bot_id] = wb_instance

		navigation_controller.bots.add_child(wb_instance)  # Add to navigation controller bots
		charging_station.add_node(wb_instance)  # Add to charging station
		widget_bots.append({"id": wb_instance.bot_id})

	for pb in pallet_bot_counter.value:  # For number of pallet bots requested
		var pb_instance = pallet_bot_scene.instance()

		pb_instance.global_position = charging_station.associated_waypoints[0].get_location()

		pb_instance.bot_id = String(id_number)
		id_number += 1

		pb_instance.goal_location = 4

		pb_instance.report_success = false

		navigation_controller.id_to_bot[pb_instance.bot_id] = pb_instance

		navigation_controller.bots.add_child(pb_instance)
		charging_station.add_node(pb_instance)
		pallet_bots.append({"id": pb_instance.bot_id})


## Bringing pallets to inbound
# Button pressed to start the process to get a new pallet in inbound
func _on_ReceiveOrderButton_pressed():
	if inbound_area.pallet_node == null:  # If there isn't already something there
		receive_order_button.disabled = true  # Disable the button
		inbound_area.run_popup_progress_bar(2)  # Show 2 second loading bar for inbound pallets
		# inbound_area.run_popup_progress_bar(0) # Set loading to 0 for testing

		# Create the pallet once the loading bar has completed
		inbound_area.tween.connect(
			"tween_all_completed", self, "_generate_new_inbound_pallet", [], CONNECT_ONESHOT
		)


func _auto_receive_order():
	receive_order_button.emit_signal("pressed")


# Generate pallet once loading animation finishes
func _generate_new_inbound_pallet():
	# Pallet
	var pallet_data = {"id": CommunicationManager.generate_uuid(), "widgets": []}
	var new_pallet = pallet_scene.instance()
	new_pallet.payload_id = pallet_data["id"]
	pallets.add_child(new_pallet)
	new_pallet.global_position = inbound_area.pallet_location.get_location() + Vector2(0, 200)  # Start it somewhere off screen below

	# Widgets
	for w in 4:
		var widget_instance = widget_scene.instance()
		widget_instance.payload_id = CommunicationManager.generate_uuid()
		pallet_data["widgets"].append({"id": widget_instance.payload_id})
		widgets.add_child(widget_instance)
		widget_instance.global_position = new_pallet.global_position
		new_pallet.add_widget(widget_instance, false)

	# Move into place
	inbound_area.add_pallet(new_pallet)
	# buffer_area.add_pallet(new_pallet)

	# Tell Gaia a new order has arrived
	CommunicationManager.publish_to_app("station/inbound/pallet", to_json(pallet_data))


## Handle unpacking pallets in Buffer
# Show unpack button on pallet arrival signal
func _show_unpack_buffer_ui():
	yield(get_tree().create_timer(1 / simulation_controller.speed_scale), "timeout")  # Slight delay for animation effect
	buffer_area.show_popup_button()


# MQTT driven signal to press button
func _auto_unpack_buffer():
	buffer_area.popup_action_button.emit_signal("pressed")


# Unpack button pressed
func _on_BufferActionButton_pressed():
	buffer_area.run_popup_progress_bar(1)  # Run 1 second loading
	# buffer_area.run_popup_progress_bar(0) # Run for 0 seconds for test

	# Switch to showing the widget space and hide the buffered pallet
	buffer_area.pallet_space.hide()
	buffer_area.widget_space.show()
	buffer_area.pallet_node.hide()

	# Unload widgets
	for wi in 4 - buffer_area.pallet_node.widgets.count(null):
		var next_widget = buffer_area.pallet_node.widgets[wi]  # Get reference to widget
		buffer_area.pallet_node.remove_widget(next_widget)  # Remove it from the pallet
		buffer_area.add_node(next_widget)  # Add it to the buffer area

		# For testing, add one to PL Start to start production line
		# if wi < 3:
		# 	buffer_area.add_node(next_widget)
		# else:
		# 	pl_start.add_node(next_widget)

		# Make sure to check if this is the last widget
		next_widget.connect(
			"leaving_area", self, "_check_to_reset_buffer_area", [], CONNECT_ONESHOT
		)

	# Tell Gaia there are new unpacked widgets
	CommunicationManager.publish_to_app("unpacked_pallet", buffer_area.pallet_node.payload_id)

	# Remove pallet after unloading
	buffer_area.pallet_node.queue_free()
	buffer_area.pallet_node = null


# For each widget that leaves the area, check if the buffer is empty and is ready for next pallet
func _check_to_reset_buffer_area():
	yield(get_tree(), "idle_frame")  # Wait for node removal process to finish
	if not buffer_area.widget_grid.node_to_spaces.size():
		buffer_area.pallet_space.show()
		buffer_area.widget_space.hide()


# MQTT driven signal to press button
func _auto_start_production():
	pl_start.popup_action_button.emit_signal("pressed")


## Widgets arrive at PL Start
# Show start production button on widget arrival
func _show_start_production_ui(widget):
	yield(get_tree().create_timer(1 / simulation_controller.speed_scale), "timeout")
	pl_start.show_popup_button()
	_widget_in_pl_start = widget  # Assign to pl_start widget reference on arrival
	CommunicationManager.publish_to_app("production_start_ready", widget.payload_id)


# Start production button pressed
func _on_PLStartActionButton_pressed():
	if not _widget_in_production_line:  # If there's no widget in the production line
		pl_start.widget_grid.remove_node(_widget_in_pl_start)  # Remove the widget from PL Start
		production_line.add_node(_widget_in_pl_start)  # Move it to the production line
		_widget_in_pl_start = null  # Remove pl_start reference to it
		pl_start.show_popup_button(false)  # Close the popup


## Widget arrives at production line
# Prepare to process widget by adding it to the production line widget reference then waiting for widget moving animation to finish
func _prep_process_widget_in_production_line(widget):
	_widget_in_production_line = widget
	widget.tween.connect(
		"tween_all_completed", self, "_process_widget_in_production_line", [], CONNECT_ONESHOT
	)


# Show widget processing animation while in production line
func _process_widget_in_production_line():
	_widget_in_production_line.show_processing(2)
	# _widget_in_production_line.show_processing(0)

	# Show production line UI once processing is complete
	_widget_in_production_line.tween.connect(
		"tween_all_completed",
		self,
		"_show_complete_production_ui",
		[_widget_in_production_line],
		CONNECT_ONESHOT
	)


# Show complete production button and "processed" widget
func _show_complete_production_ui(widget):
	# Show the widget has changed
	widget.paint()
	widget.label()

	# Display button
	production_line.show_popup_button()
	CommunicationManager.publish_to_app(
		"production_finished", _widget_in_production_line.payload_id
	)


# MQTT driven signal to press button
func _auto_unload_pl():
	production_line.popup_action_button.emit_signal("pressed")


# Complete production button pressed
func _on_ProductionLineActionButton_pressed():
	if not pl_end.widget_grid.node_to_spaces.size():  # If there is no widget in PL End
		production_line.widget_grid.remove_node(_widget_in_production_line)  # Remove widget from production line
		pl_end.add_node(_widget_in_production_line)  # Move to PL End
		_widget_in_production_line = null
		production_line.show_popup_button(false)


## Widget arrives at PL End
# Handle when widget enters PL End
func _handle_widget_in_pl_end(_widget):
	# Tell Gaia a widget has arrived
	CommunicationManager.publish_to_app("processed_widget", _widget.payload_id)

	# Test method to automatically move widget to outbound
	# widget.tween.connect(
	# 	"tween_all_completed", self, "_move_to_outbound", [widget], CONNECT_ONESHOT
	# )


# Test method to handle moving to outbound
func _move_to_outbound(widget):
	var next_open_space = outbound_area.pallet_node.widgets.find(null)
	if next_open_space != -1:
		pl_end.widget_grid.remove_node(widget)
		outbound_area.pallet_node.add_widget(widget)


## Widget is added to the outbound pallet
# Method to check if outbound pallet is ready for shipment
func _check_if_ready_to_ship(space_left):
	if space_left == 0:  # Show "ship" button if there is no space left
		outbound_area.show_popup_button()


# MQTT driven signal to press button
func _auto_ship():
	outbound_area.popup_action_button.emit_signal("pressed")


# When the shipping button is pressed
func _on_OutboundActionButton_pressed():
	outbound_area.run_popup_progress_bar(1)

	#
	outbound_area.tween.connect(
		"tween_all_completed", self, "_do_shipment", [outbound_area.pallet_node], CONNECT_ONESHOT
	)


# Run shipment animation
func _do_shipment(outbound_pallet):
	outbound_pallet.move_to(outbound_pallet.position + Vector2(200, 0), true)

	# Complete shipment technicalities once the pallet is off screen
	outbound_pallet.tween.connect(
		"tween_all_completed", self, "_complete_shipment", [outbound_pallet], CONNECT_ONESHOT
	)


# Shipment pallet management
func _complete_shipment(old_outbound_pallet):
	# Remove the old pallet node
	old_outbound_pallet.queue_free()

	# Create a new one outside the frame and move it in
	_generate_new_outbound_pallet()


# Generate outbound pallet
func _generate_new_outbound_pallet(with_test_widget = false):
	## Create outbound pallet with 3 widgets inside for testing
	# Create a new one outside the frame and move it in
	var pallet_data = {"id": CommunicationManager.generate_uuid(), "widgets": []}
	var outbound_pallet = pallet_scene.instance()
	outbound_pallet.payload_id = pallet_data["id"]
	outbound_pallet.global_position = outbound_area.pallet_location.get_location()
	outbound_area.pallet_node = outbound_pallet
	pallets.add_child(outbound_pallet)

	# Move into place
	outbound_area.add_pallet(outbound_pallet)

	if with_test_widget:
		# For testing: Auto-populate it with 3 widgets
		for w in 3:
			var outbound_widget = widget_scene.instance()
			outbound_widget.payload_id = CommunicationManager.generate_uuid()
			pallet_data["widgets"].append({"id": outbound_widget.payload_id})
			outbound_widget.global_position = outbound_pallet.global_position
			widgets.add_child(outbound_widget)
			outbound_pallet.add_widget(outbound_widget)

	outbound_pallet.connect("widget_added", self, "_check_if_ready_to_ship")  # Connect to signal to check if ready to ship

	# Tell Gaia a new pallet is in outbound
	CommunicationManager.publish_to_app("station/outbound/pallet", to_json(pallet_data))
