extends Node

var is_working = true
var _is_still_processing = false

### Signals
## AMR
signal factory_move_location(bot_id, location)


func _ready():
	# Cancel process if no JavaScript
	if ! OS.has_feature("JavaScript"):
		print("No JavaScript! Can't run communications")
		is_working = false
		return


func _physics_process(_delta):
	if is_working && not _is_still_processing:
		while JavaScript.eval("parent.unreadMessages;"):
			if not _is_still_processing:
				_is_still_processing = true
			var topic = JavaScript.eval("parent.readNextTopic();")
			var payload = JavaScript.eval("parent.readNextPayload();")

			## Detect who to send to
			var topic_extract = topic.split("/")
			match topic_extract[1]:
				"factory":
					match topic_extract[-1]:  # Look at last item in topic path
						"move_location":  # Set destination location of a bot
							emit_signal("factory_move_location", topic_extract[-2], int(payload))  # Send bot_ID and payload
						_:
							print("Unknown factory topic")
				"access_control":
					# Relating to Access Control stuff
					pass
				_:
					print("Unknown Demo")

		if _is_still_processing:
			_is_still_processing = false


### Methods
func read_variable(variable_name):
	if is_working:
		return JavaScript.eval("parent." + variable_name + ";")


func subscribe_to_topic(topic: String):
	if is_working:
		JavaScript.eval("parent.subscribeToTopic('%s');" % topic)


func publish_to_topic(topic: String, payload):
	if is_working:
		JavaScript.eval(
			(
				"parent.publishData('%s', '%s');"
				% [topic, payload if typeof(payload) == TYPE_STRING else String(payload)]
			)
		)
	else:
		print(payload)


func cleanup():
	if is_working:
		JavaScript.eval("parent.mqttCleanup();")


func get_setup_data():
	var sample_json_file = File.new()
	sample_json_file.open("res://Labs/sample_json.tres", File.READ)
	if sample_json_file.is_open():
		var json_as_text = sample_json_file.get_as_text()
		var json_parse = JSON.parse(json_as_text)
		if ! json_parse.error:
			return json_parse.result

	return null
