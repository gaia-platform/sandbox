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

### To be spawned
export (PackedScene) var widget_bot_scene
export (PackedScene) var pallet_bot_scene
export (PackedScene) var widget_scene
export (PackedScene) var pallet_scene

### Properties
var _widget_in_pl_start = null
var _widget_in_production_line = null
var _widget_in_pl_end = null

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
	pl_start.connect("new_node_added", self, "_show_start_production_ui")
	production_line.connect("new_node_added", self, "_prep_process_widget_in_production_line")
	pl_end.connect("new_node_added", self, "_handle_widget_in_pl_end")

	# Create outbound pallet
	var outbound_pallet = pallet_scene.instance()
	outbound_pallet.global_position = outbound_area.pallet_location.get_location()
	pallets.add_child(outbound_pallet)
	outbound_area.add_pallet(outbound_pallet)

	# For testing: Auto-populate it with 3 widgets
	for w in 3:
		var outbound_wiget = widget_scene.instance()
		outbound_wiget.global_position = outbound_pallet.global_position
		widgets.add_child(outbound_wiget)
		outbound_pallet.add_widget(outbound_wiget)

	# Populate bots
	_generate_bots()


### Signals and Factory flow
## Start-Stop factory
# Button pressed to stop factory or start and spawn new bots
func _on_StartSimulation_pressed():
	var editable_state = widget_bot_counter.editable

	# Toggle counter editability
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

# Function to populate factory with new bots
func _generate_bots():
	for wb in widget_bot_counter.value: # For the number of widget bots requested
		var wb_instance = widget_bot_scene.instance() # Create instance
		navigation_controller.bots.add_child(wb_instance) # Add to navigation controller bots
		wb_instance.global_position = charging_station.associated_waypoints[0].get_location() # Set position to be the charging station waypoint
		charging_station.add_node(wb_instance) # Add to charging station

	for pb in pallet_bot_counter.value: # For number of pallet bots requested
		var pb_instance = pallet_bot_scene.instance()
		navigation_controller.bots.add_child(pb_instance)
		pb_instance.global_position = charging_station.associated_waypoints[0].get_location()
		charging_station.add_node(pb_instance)

## Bringing pallets to inbound
# Button pressed to start the process to get a new pallet in inbound
func _on_ReceiveOrder_pressed():
	if inbound_area.pallet_node == null:  # If there isn't already something there
		receive_order_button.disabled = true  # Disable the button
		inbound_area.run_popup_progress_bar(2)  # Show 2 second loading bar for inbound pallets
		# inbound_area.run_popup_progress_bar(0) # Set loading to 0 for testing

		# Create the pallet once the loading bar has completed
		inbound_area.tween.connect(
			"tween_all_completed", self, "_generate_new_inbound_pallet", [], CONNECT_ONESHOT
		)

# Generate pallet once loading animation finishes
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
	inbound_area.add_pallet(new_pallet)
	# buffer_area.add_pallet(new_pallet)
	CommunicationManager.publish_to_app("order_arrived", true)

func _on_BufferActionButton_pressed():
	buffer_area.run_popup_progress_bar(1)  # Run 1 second loading
	# buffer_area.run_popup_progress_bar(0) # Run for 0 seconds for test

	# Switch to showing the widget space and hide the buffered pallet
	buffer_area.pallet_space.hide()
	buffer_area.widget_space.show()
	buffer_area.pallet_node.hide()

	# Unload widgets (4 of them)
	for wi in 4:
		var next_widget = buffer_area.pallet_node.widgets[wi]  # Get reference to widget
		buffer_area.pallet_node.remove_widget(next_widget)  # Remove it from the pallet
		buffer_area.add_node(next_widget) # Add it to the buffer area

		# For testing, add one to PL Start to start production line
		# if wi < 3:
		# 	buffer_area.add_node(next_widget)
		# else:
		# 	pl_start.add_node(next_widget)

		# Make sure to check if this is the last widget
		next_widget.connect(
			"leaving_area", self, "_check_to_reset_buffer_area", [], CONNECT_ONESHOT
		)

	# Remove pallet after unloading
	buffer_area.pallet_node.queue_free()
	buffer_area.pallet_node = null

	# Tell Gaia there are new unpacked widgets
	CommunicationManager.publish_to_app("unpacked_pallet", true)


# Start production button pressed
func _on_PLStartActionButton_pressed():
	if not _widget_in_production_line: # If there's no widget in the production line
		pl_start.widget_grid.remove_node(_widget_in_pl_start) # Remove the widget from PL Start
		production_line.add_node(_widget_in_pl_start) # Move it to the production line
		_widget_in_pl_start = null # Remove pl_start reference to it
		pl_start.show_popup_button(false) # Close the popup


# Complete production button pressed
func _on_ProductionLineActionButton_pressed():
	if not _widget_in_pl_end: # If there is no widget in PL End
		production_line.widget_grid.remove_node(_widget_in_production_line) # Remove widget from production line
		pl_end.add_node(_widget_in_production_line) # Move to PL End
		_widget_in_pl_end = _widget_in_production_line
		_widget_in_production_line = null
		production_line.show_popup_button(false)


func _on_OutboundActionButton_pressed():
	outbound_area.run_popup_progress_bar(1)
	outbound_area.tween.connect("tween_all_completed", self, "_do_shipment", [], CONNECT_ONESHOT)


### Private methods






# Show unpack buffer
func _show_unpack_buffer_ui():
	yield(get_tree().create_timer(1 / simulation_controller.speed_scale), "timeout")
	buffer_area.show_popup_button()

	# Cleanup inbound
	receive_order_button.disabled = false
	inbound_area.pallet_node = null


func _check_to_reset_buffer_area():
	yield(get_tree(), "idle_frame")  # Wait for node removal process to finish
	if not buffer_area.widget_grid.node_to_spaces.size():
		buffer_area.pallet_space.show()
		buffer_area.widget_space.hide()


# Show start production UI
func _show_start_production_ui(widget):
	yield(get_tree().create_timer(1 / simulation_controller.speed_scale), "timeout")
	pl_start.show_popup_button()
	_widget_in_pl_start = widget


# Process widget in production line
func _prep_process_widget_in_production_line(widget):
	_widget_in_production_line = widget
	widget.tween.connect(
		"tween_all_completed", self, "_process_widget_in_production_line", [], CONNECT_ONESHOT
	)


func _process_widget_in_production_line():
	_widget_in_production_line.show_processing(2)
	# _widget_in_production_line.show_processing(0)
	_widget_in_production_line.tween.connect(
		"tween_all_completed",
		self,
		"_show_complete_production_ui",
		[_widget_in_production_line],
		CONNECT_ONESHOT
	)


func _show_complete_production_ui(widget):
	widget.paint()
	widget.label()
	production_line.show_popup_button()


# Handle when widget enters PL End
func _handle_widget_in_pl_end(_widget):
	CommunicationManager.publish_to_app("processed_widget", true)
	# widget.tween.connect(
	# 	"tween_all_completed", self, "_move_to_outbound", [widget], CONNECT_ONESHOT
	# )


# Handle outbound packing
func _move_to_outbound(widget):
	var next_open_space = outbound_area.pallet_node.widgets.find(null)
	if next_open_space != -1:
		pl_end.widget_grid.remove_node(widget)
		outbound_area.pallet_node.add_widget(widget)
		_widget_in_pl_end = null

		# If this was the last space, show shipping button
		if next_open_space == 3:
			outbound_area.show_popup_button()


func _do_shipment():
	outbound_area.pallet_node.move_to(outbound_area.pallet_node.position + Vector2(200, 0), true)
	outbound_area.pallet_node.tween.connect(
		"tween_all_completed", self, "_complete_shipment", [], CONNECT_ONESHOT
	)


func _complete_shipment():
	outbound_area.pallet_node.queue_free()
	outbound_area.pallet_node = null
	var outbound_pallet = pallet_scene.instance()
	outbound_pallet.global_position = outbound_area.pallet_location.get_location() + Vector2(200, 0)
	pallets.add_child(outbound_pallet)
	outbound_area.add_pallet(outbound_pallet)
