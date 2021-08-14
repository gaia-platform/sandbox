extends Control

export (String, FILE) var farobot_3_tasks_scene
export (String, FILE) var amr_scenario_1_scene
export (String, FILE) var sbdl_scene
export (String, FILE) var access_control_scene


func _ready():
	CommunicationManager.cleanup()


func _on_Scenario1Button_pressed():
	var change_scene_status = get_tree().change_scene(amr_scenario_1_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)


func _on_FARobot3TasksButton_pressed():
	var change_scene_status = get_tree().change_scene(farobot_3_tasks_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)
	else:
		CommunicationManager.publish_project_action("select", "amr_swarm_template")


func _on_AccessControlButton_pressed():
	var change_scene_status = get_tree().change_scene(access_control_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)
	else:
		CommunicationManager.publish_project_action("select", "access_control_template")


func _on_ScenarioBasedDataLogging_pressed():
	var change_scene_status = get_tree().change_scene(sbdl_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)
