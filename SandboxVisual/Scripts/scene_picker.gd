extends Control

export (String, FILE) var factory_demo_scene
export (String, FILE) var access_control_scene


func _ready():
	CommunicationManager.cleanup()

func _select_project(project_name):
	CommunicationManager.publish_to_topic(
		(
			JavaScript.eval("'sandbox_coordinator/%s/project'"
			% CommunicationManager.read_variable("sandboxUuid"))
		), project_name
	)

func _on_FactoryDemoButton_pressed():
	var change_scene_status = get_tree().change_scene(factory_demo_scene)
	if ! change_scene_status:
		print("Error changing scene: %d" % change_scene_status)


func _on_AccessControlButton_pressed():
	var change_scene_status = get_tree().change_scene(access_control_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)
	else:
		_select_project("access_control_template")
