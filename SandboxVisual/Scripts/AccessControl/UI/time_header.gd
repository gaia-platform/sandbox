extends PanelContainer

# Settings
export (String) var label_prefix = "Location at time:"
export (int) var minutes = 480  # 8 am

# Nodes
export (NodePath) var time_label_path
onready var time_label = get_node(time_label_path)


func _ready():
	_display_time_label()


func _on_FastForwardButton_pressed():
	minutes += 30
	_display_time_label()

	var data_send = {"time": minutes}
	var as_json = to_json(data_send)
	# TODO implement data send


func _display_time_label():
	time_label.text = label_prefix + _minutes_to_string()


func _minutes_to_string():
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
