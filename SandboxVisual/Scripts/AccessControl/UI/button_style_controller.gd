extends Button

# Settings
export (Color, RGB) var base_color = Color.black
export (bool) var stays_selected = false

# State
var selected = false  # Don't use pressed to keep track of state as this will interfere with signals
var _prev_color: Color


# Signals
func _on_Button_mouse_entered():
	if not (stays_selected and selected):
		_prev_color = modulate
		modulate = Color("#AD9BF6")  # Highlighted color


func _on_Button_mouse_exited():
	if not (stays_selected and selected):
		modulate = _prev_color


# Public methods
func set_state(state: bool):
	selected = state
	modulate = Color("#583BC6") if state else base_color

	# Disable/enable badge-in button
	if "badge" in get_button_icon().get_path():
		set_button_mask(0 if state else 1)
