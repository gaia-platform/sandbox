extends PanelContainer

export (NodePath) var error_message_label_path
onready var error_message_label = get_node(error_message_label_path)


func _on_CloseButton_pressed():
	hide()


func show_error_message(message: String):
	if not visible:
		show()
	error_message_label.text = message
