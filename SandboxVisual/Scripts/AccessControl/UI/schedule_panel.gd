extends PanelContainer

# Nodes
export (PackedScene) var event_label
export (NodePath) var event_list_path
onready var event_list = get_node(event_list_path)


# Methods
func add_schedule_events(events: Array, with_room_name: bool):
	for event in events:
		var new_event = event_label.instance()

		var time_and_event_string = (
			"%s - %s : %s"
			% [
				minutes_to_string(event["start_timestamp"]),
				minutes_to_string(event["end_timestamp"]),
				event["name"]
			]
		)
		if with_room_name:
			new_event.text = "%s in %s" % [time_and_event_string, event["room_name"]]
		else:
			new_event.text = time_and_event_string
		
		event_list.add_child(new_event)


func minutes_to_string(minutes: int):
	var hours = floor(minutes / 60.0)
	var hours_mod = hours % 12
	hours = "12" if hours_mod == 0 else String(hours_mod)

	var str_minutes: String
	var minutes_mod = minutes % 60
	if minutes_mod == 0:
		str_minutes = "00"
	elif minutes_mod < 10:
		str_minutes = "0%d" % (minutes_mod)
	else:
		str_minutes = String(minutes_mod)

	var am_pm = "pm" if hours >= 12 else "am"

	return "%s:%s %s" % [hours, str_minutes, am_pm]
