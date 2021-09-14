extends Node

var is_working = true
var _is_still_processing = false

### Signals
## AMR
signal factory_running
signal factory_move_location(bot_id, location)
signal factory_charge_bot(bot_id)
signal factory_pickup_payload(bot_id, payload)
signal factory_drop_payload(bot_id, location)
signal factory_status_request(bot_id, status_item)
signal factory_receive_order
signal factory_unpack_pallet
signal factory_start_production
signal factory_unload_pl
signal factory_ship

## Access Control
signal ac_init(init_data)
signal ac_error(error_message)
signal ac_move_to_building(person_id, building_id)
signal ac_move_to_room(person_id, building_id, room_id)
signal ac_option(option_value)


func _ready():
	# Cancel process if no JavaScript
	if not OS.has_feature("JavaScript"):
		print("No JavaScript! Can't run communications")
		is_working = false
		return


func _physics_process(_delta):
	if is_working && not _is_still_processing:
		while JavaScript.eval("parent.unreadMessages;"):  # Read and process while there are unread
			if not _is_still_processing:
				_is_still_processing = true

			# Read MQTT data
			var message = JavaScript.eval("parent.readNextMessage();")
			var message_decoded = JSON.parse(message)  # Parse
			if message_decoded.error:  # Ignore this message if there was a parsing error
				continue
			var topic = message_decoded.result.topic
			var payload = message_decoded.result.payload

			var time_in_ms = OS.get_system_time_msecs()
			var time_in_s = String(time_in_ms % 60000)
			print(
				(
					"[%s.%s] Message received topic:%s payload:%s"
					% [time_in_s.substr(0, 2), time_in_s.substr(2), topic, payload]
				)
			)

			## Detect who to send to
			var topic_extract = topic.split("/")
			match get_tree().get_current_scene().get_name():
				"AMRSwarmFactory":
					match topic_extract[-1]:  # Look at last item in topic path
						"running":  # AMR factory running, ready for initialization
							emit_signal("factory_running")
						"move_location":  # Set destination location of a bot
							emit_signal("factory_move_location", topic_extract[-2], payload)  # Send bot_ID and payload
						"charge":  # Tell bot to charge
							emit_signal("factory_charge_bot", topic_extract[-2])
						"pickup_payload":  # Pickup payload at location
							emit_signal("factory_pickup_payload", topic_extract[-2], payload)
						"drop_payload":  # Drop payload at location
							emit_signal("factory_drop_payload", topic_extract[-2], payload)
						"status_request":  # Get info about a bot
							emit_signal("factory_status_request", topic_extract[-2], payload)
						"receive_order":
							emit_signal("factory_receive_order")
						"unpack_pallet":
							emit_signal("factory_unpack_pallet")
						"start_production":
							emit_signal("factory_start_production")
						"unload_pl":
							emit_signal("factory_unload_pl")
						"ship":
							emit_signal("factory_ship")
						_:
							print("Unknown factory topic")
				"AccessControlBuilding":
					match topic_extract[-1]:
						"init":  # Verbose database output for setting up
							emit_signal("ac_init", payload)
						"alert":  # Error message
							emit_signal("ac_error", payload)
						"move_to_building":  # Moves buildings
							emit_signal("ac_move_to_building", topic_extract[-2], payload)
						"move_to_room":  # Moves rooms
							var data_split = payload.split(",")  # Divides into building_ID and room_ID
							emit_signal(
								"ac_move_to_room", topic_extract[-2], data_split[0], data_split[1]
							)
						"scan":  # Person option state change
							emit_signal("ac_option", int(topic_extract[-2]), payload)
						_:
							print("Unknown access control topic")
				_:
					print("Unknown Demo")

		if _is_still_processing:
			_is_still_processing = false


### Methods
func generate_uuid():
	if is_working:
		return JavaScript.eval("parent.generateUUID();")


func read_variable(variable_name):
	if is_working:
		return JavaScript.eval("parent." + variable_name + ";")


func subscribe_to_topic(topic: String):
	if is_working:
		JavaScript.eval("parent.subscribeToTopic('%s');" % topic)


func publish_to_app(topic: String, payload):
	if is_working:
		var time_in_ms = OS.get_system_time_msecs()
		var time_in_s = String(time_in_ms % 60000)
		print(
			(
				"[%s.%s] Message published topic:%s payload:%s"
				% [time_in_s.substr(0, 2), time_in_s.substr(2), topic, payload]
			)
		)
		JavaScript.eval(
			(
				"parent.publishToApp('%s', '%s');"
				% [topic, payload if typeof(payload) == TYPE_STRING else String(payload)]
			)
		)
	else:
		print("%s: %s" % [topic, payload])


func publish_to_coordinator(topic, payload):
	if is_working:
		JavaScript.eval(
			(
				"parent.publishToCoordinator('%s', '%s');"
				% [topic, payload if typeof(payload) == TYPE_STRING else String(payload)]
			)
		)
	else:
		print("%s: %s" % [topic, payload])


func cleanup():
	if is_working:
		JavaScript.eval("parent.mqttCleanup();")


func get_setup_data():
	var sample_json_file = File.new()
	sample_json_file.open("res://Labs/sample_json.tres", File.READ)
	if sample_json_file.is_open():
		var json_as_text = sample_json_file.get_as_text()
		var json_parse = JSON.parse(json_as_text)
		if !json_parse.error:
			return json_parse.result

	return null
