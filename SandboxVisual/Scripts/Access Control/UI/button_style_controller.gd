extends Button

# Settings
export (Color, RGB) var base_color = Color.black
export (bool) var stays_pressed = false

# State
var selected = false
var _prev_color: Color


func _on_Button_mouse_entered():
	if not (stays_pressed and selected):
		_prev_color = modulate
		modulate = Color("47c0d7") # Highlighted color


func _on_Button_mouse_exited():
	if not (stays_pressed and selected):
		modulate = _prev_color


func _on_Button_pressed():
	if toggle_mode:
		modulate = Color("28a745") if not selected else base_color
		selected = not selected
		_prev_color = modulate
	elif stays_pressed and not selected:
		modulate = Color("28a745")
		selected = true
		set_button_mask(0)

