extends PanelContainer

# Settings
export (String) var label_prefix = "Location at time:"
export (int) var hour = 8
export (int) var minute = 0
export (bool) var is_am = true

# Nodes
export (NodePath) var time_label_path
onready var time_label = get_node(time_label_path)


func _ready():
	_display_time_label()


func _on_FastForwardButton_pressed():
	minute += 30

	if minute >= 60:
		hour += 1
		minute -= 60

	if hour >= 12:
		if hour == 12 and minute == 0:
			is_am = not is_am
		elif hour > 12:
			hour -= 12

	_display_time_label()


func _display_time_label():
	var minute_text = minute
	if minute < 10:
		minute_text = "0%d" % minute

	time_label.text = "%s %d:%s %s" % [label_prefix, hour, minute_text, "am" if is_am else "pm"]
