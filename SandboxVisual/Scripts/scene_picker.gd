extends Control

export(String, FILE) var amr_swarm_factory_scene
export(String, FILE) var amr_scenario_1_scene
export(String, FILE) var sbdl_scene
export(String, FILE) var access_control_scene


func _ready():
	CommunicationManager.cleanup()


func _on_Scenario1Button_pressed():
	var change_scene_status = get_tree().change_scene(amr_scenario_1_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)


func _on_AMRSwarmFactoryButton_pressed():
	var change_scene_status = get_tree().change_scene(amr_swarm_factory_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)


func _on_AccessControlButton_pressed():
	var change_scene_status = get_tree().change_scene(access_control_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)


func _on_ScenarioBasedDataLogging_pressed():
	var change_scene_status = get_tree().change_scene(sbdl_scene)
	if change_scene_status != OK:
		print("Error changing scene: %d" % change_scene_status)
