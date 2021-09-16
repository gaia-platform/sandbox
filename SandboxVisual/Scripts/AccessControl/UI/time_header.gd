extends PanelContainer
# Handle and show simulation time

# Settings and nodes
export(String) var label_prefix = "Location at time: "
export(int) var minutes = 480  # 8 am
export(NodePath) var time_label_path

# Time label node
onready var time_label = get_node(time_label_path)


func _ready():
	_display_time_label()


# Increment the time forward by 30 minutes
func _on_FastForwardButton_pressed():
	minutes += 30
	_display_time_label()

	CommunicationManager.publish_to_app("access_control/time", minutes)


func _display_time_label():
	time_label.text = label_prefix + _minutes_to_string()


# Convert minutes into a time stamp
func _minutes_to_string():
	# Format hours
	var hours = floor(minutes / 60.0)
	var hours_mod = int(hours) % 12
	hours = "12" if hours_mod == 0 else String(hours_mod)

	# Format minutes
	var str_minutes: String
	var minutes_mod = minutes % 60
	if minutes_mod == 0:
		str_minutes = "00"
	elif minutes_mod < 10:
		str_minutes = "0%d" % (minutes_mod)
	else:
		str_minutes = String(minutes_mod)

	# Append AM/PM
	var am_pm = "pm" if int(hours) >= 12 else "am"

	return "%s:%s %s" % [hours, str_minutes, am_pm]
