extends Node

var is_working = false


func _ready():
	# Cancel process if no JavaScript
	if ! OS.has_feature("JavaScript"):
		print("No JavaScript! Can't run communications")
		return

	## Launch MQTT
	# Filenames
	var aws_bundle_file_path = "res://Scripts/Communications/aws_bundle.tres"
	var mqtt_bundle_file_path = "res://Scripts/Communications/mqtt_bundle.tres"

	# Open files
	var aws_bundle_file = File.new()
	aws_bundle_file.open(aws_bundle_file_path, File.READ)

	var mqtt_bundle_file = File.new()
	mqtt_bundle_file.open(mqtt_bundle_file_path, File.READ)

	# Run files
	if aws_bundle_file.is_open():  # AWS
		JavaScript.eval(aws_bundle_file.get_as_text())
		aws_bundle_file.close()
	if mqtt_bundle_file.is_open():  # MQTT
		JavaScript.eval(mqtt_bundle_file.get_as_text())

	is_working = true


func read_variable(variable_name):
	return JavaScript.eval(variable_name + ";")


func get_setup_data():
	var sample_json_file = File.new()
	sample_json_file.open("res://Labs/sample_json.tres", File.READ)
	if sample_json_file.is_open():
		var json_as_text = sample_json_file.get_as_text()
		var json_parse = JSON.parse(json_as_text)
		if ! json_parse.error:
			return json_parse.result

	return null
