extends Button
# Sets highlighting and color of UI buttons
# Uses mouse events to alter button state

# Button base properties
export(Color, RGB) var base_color = Color.black
export(bool) var stays_selected = false

# Button state
var selected = false
var _prev_color: Color


func set_state(state: bool):
	selected = state
	modulate = Color("#583bc6") if state else base_color

	# Disable/enable badge-in button
	if "badge" in get_button_icon().get_path():
		set_button_mask(0 if state else 1)


# Highlight button
func _on_Button_mouse_entered():
	if not (stays_selected and selected):
		_prev_color = modulate
		modulate = Color("#ad9bf6")


# Reset button back to pre-highlighted color
func _on_Button_mouse_exited():
	if not (stays_selected and selected):
		modulate = _prev_color
