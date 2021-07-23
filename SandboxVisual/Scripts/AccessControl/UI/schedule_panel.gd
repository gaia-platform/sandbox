extends PanelContainer

# Nodes
export (PackedScene) var event_label
export (NodePath) var event_list_path
onready var event_list = get_node(event_list_path)


### Methods
## Add events/items to the schedule listing
func add_schedule_events(events: Array, with_room_name: bool = false):
	if events.size() != 0:
		for event in events:
			var new_event = event_label.instance()  # Create new event line
			event_list.add_child(new_event)

			# Read and combine time stamps and event name
			var time_and_event_string = (
				"%s - %s : %s"
				% [
					minutes_to_string(event["start_timestamp"]),
					minutes_to_string(event["end_timestamp"]),
					event["name"]
				]
			)

			# Append room name if necessary, then set label
			var event_string: String
			if with_room_name:
				event_string = "%s in %s" % [time_and_event_string, event["room_name"]]
			else:
				event_string = time_and_event_string
			new_event.set_deferred("text", event_string)
	else:
		hide()



## Convert minutes into a time stamp
func minutes_to_string(minutes: int):
	# Hours
	var hours = floor(minutes / 60.0)
	var hours_mod = int(hours) % 12
	hours = "12" if hours_mod == 0 else String(hours_mod)  # 12 hour time

	# Minutes
	var str_minutes: String
	var minutes_mod = minutes % 60
	if minutes_mod == 0:  # 00 for 0 minutes
		str_minutes = "00"
	elif minutes_mod < 10:  # Add 0 in front of single digit time
		str_minutes = "0%d" % (minutes_mod)
	else:  # Put whole number otherwise
		str_minutes = String(minutes_mod)

	# Append AM/PM
	var am_pm = "pm" if int(hours) >= 12 else "am"

	return "%s:%s %s" % [hours, str_minutes, am_pm]
