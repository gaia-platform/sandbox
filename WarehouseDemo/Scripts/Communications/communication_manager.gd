extends Node


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

	print("Configured MQTT!")