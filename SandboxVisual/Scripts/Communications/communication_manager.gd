extends Node

var is_working = true


func _ready():
	# Cancel process if no JavaScript
	if ! OS.has_feature("JavaScript"):
		print("No JavaScript! Can't run communications")
		is_working = false


func read_variable(variable_name):
	if is_working:
		return JavaScript.eval("parent." + variable_name + ";")


func get_setup_data():
	var sample_json_file = File.new()
	sample_json_file.open("res://Labs/sample_json.tres", File.READ)
	if sample_json_file.is_open():
		var json_as_text = sample_json_file.get_as_text()
		var json_parse = JSON.parse(json_as_text)
		if ! json_parse.error:
			return json_parse.result

	return null
