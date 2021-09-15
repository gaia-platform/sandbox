extends Label

# Item properties
export(int) var start_hour
export(int) var start_minute
export(bool) var start_is_am
export(int) var end_hour
export(int) var end_minute
export(bool) var end_is_am
export(String) var event_name


func _ready():
	text = (
		"%d:%d %s - %d:%d %s : %s"
		% [
			start_hour,
			start_minute,
			_return_am_string(start_is_am),
			end_hour,
			end_minute,
			_return_am_string(end_is_am),
			event_name
		]
	)


func _return_am_string(am: bool):
	return "am" if am else "pm"
