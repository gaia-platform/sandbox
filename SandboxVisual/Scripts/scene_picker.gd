extends Control

export (String, FILE) var factory_demo_scene
export (String, FILE) var access_control_scene


func _ready():
	CommunicationManager.cleanup()


func _on_FactoryDemoButton_pressed():
	var change_scene_status = get_tree().change_scene(factory_demo_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)


func _on_AccessControlButton_pressed():
	var change_scene_status = get_tree().change_scene(access_control_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)
	else:
		CommunicationManager.publish_project_action("select", "access_control_template")
