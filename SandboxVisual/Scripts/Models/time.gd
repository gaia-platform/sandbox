# Properties
var hour: int
var minute: int
var is_am: bool


func to_string():
	return "%d:%d %s" % [hour, minute, "am" if is_am else "pm"]
