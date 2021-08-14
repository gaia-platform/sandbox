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
	inbound_area, charging_station, buffer_area, pl_start, production_line, pl_end, outbound_area
]
var number_of_waypoints = -1

# Widgets
export (NodePath) var widgets_path
onready var widgets = get_node(widgets_path)

# To be spawned
export (PackedScene) var widget_bot_scene
export (PackedScene) var pallet_bot_scene
export (PackedScene) var widget_scene
export (PackedScene) var pallet_scene

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
export (NodePath) var start_stop_button_path
export (NodePath) var receive_order_button_path
onready var simulation_controller = get_node(simulation_controller_path)
onready var widget_bot_counter = get_node(widget_bot_counter_path)
onready var pallet_bot_counter = get_node(pallet_bot_counter_path)
onready var start_stop_button = get_node(start_stop_button_path)
onready var receive_order_button = get_node(receive_order_button_path)

### Signals
signal end_simulation


func _ready():
	# Wait for everything to load in, then count number of waypoints
	yield(get_tree(), "idle_frame")
	number_of_waypoints = 0
	for area in areas:
		number_of_waypoints += area.associated_waypoints.size()

	# Connect signals
	buffer_area.connect("new_pallet_added", self, "_show_unpack_buffer_ui")

	# Populate bots
	_generate_bots()


### Signals
# Start Stop Button
func _on_StartSimulation_pressed():
	var editable_state = widget_bot_counter.editable
	widget_bot_counter.editable = not editable_state
	pallet_bot_counter.editable = not editable_state

	if editable_state:  # If it was originally enabled (meaning the simulation was not running)
		start_stop_button.text = "End Simulation"
		_generate_bots()
	else:
		start_stop_button.text = "Start Simulation"

		# Remove everything from the simulation
		emit_signal("end_simulation")
		yield(get_tree(), "idle_frame")  # Wait for all processing to complete before deleting everything else
		for widget in widgets.get_children():
			widget.queue_free()
		for pallet in pallets.get_children():
			pallet.queue_free()
		for bot in navigation_controller.bots.get_children():
			bot.queue_free()

		# TODO: #77 send reset signal to Gaia


# Add new pallet to inbound
func _on_ReceiveOrder_pressed():
	if inbound_area.pallet_node == null:
		receive_order_button.disabled = true
		inbound_area.run_popup_progress_bar(0)
		inbound_area.tween.connect(
			"tween_all_completed", self, "_generate_new_inbound_pallet", [], CONNECT_ONESHOT
		)


func _on_BufferActionButton_pressed():
	buffer_area.run_popup_progress_bar(0)

	buffer_area.pallet_space.hide()
	buffer_area.widget_space.show()
	buffer_area.pallet_node.hide()

	while buffer_area.pallet_node.widgets.size():
		var next_widget = buffer_area.pallet_node.widgets[0]
		buffer_area.pallet_node.remove_widget(next_widget)
		if buffer_area.pallet_node.widgets.size():
			buffer_area.add_node(next_widget)
		else:
			pl_start.add_node(next_widget)

	buffer_area.pallet_node.queue_free()
	buffer_area.pallet_node = null

	CommunicationManager.publish_to_topic("factory_3_tasks/unpacked_pallet", true)


### Private methods
# Populate bots
func _generate_bots():
	for wb in widget_bot_counter.value:
		var wb_instance = widget_bot_scene.instance()
		navigation_controller.bots.add_child(wb_instance)
		wb_instance.global_position = charging_station.associated_waypoints[0].get_location()
		charging_station.add_node(wb_instance)

	for pb in pallet_bot_counter.value:
		var pb_instance = pallet_bot_scene.instance()
		navigation_controller.bots.add_child(pb_instance)
		pb_instance.global_position = charging_station.associated_waypoints[0].get_location()
		charging_station.add_node(pb_instance)


# Generate pallet on new order
func _generate_new_inbound_pallet():
	# Pallet
	var new_pallet = pallet_scene.instance()
	pallets.add_child(new_pallet)
	new_pallet.global_position = inbound_area.pallet_location.get_location() + Vector2(0, 200)  # Start it somewhere off screen below

	# Widgets
	for w in 4:
		var widget_instance = widget_scene.instance()
		widgets.add_child(widget_instance)
		widget_instance.global_position = new_pallet.global_position
		new_pallet.add_widget(widget_instance, false)

	# Move into place
	buffer_area.add_pallet(new_pallet)
	CommunicationManager.publish_to_topic("factory_3_tasks/order_arrived", true)


# Show unpack buffer
func _show_unpack_buffer_ui():
	yield(get_tree().create_timer(1 / simulation_controller.speed_scale), "timeout")
	buffer_area.show_popup_button()
