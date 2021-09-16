extends PanelContainer
# Toggle error header and message

# Error message label reference
export(NodePath) var error_message_label_path
onready var error_message_label = get_node(error_message_label_path)


func _ready():
	# Subscribe and connect to signal
	CommunicationManager.subscribe_to_topic("access_control/error")
	var _connect_to_error = CommunicationManager.connect("ac_error", self, "_show_error_message")


func _on_CloseButton_pressed():
	hide()


func _show_error_message(message: String):
	if not visible:
		show()
	error_message_label.text = message
