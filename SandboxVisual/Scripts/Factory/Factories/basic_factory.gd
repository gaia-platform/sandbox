extends Control

export (int) var number_of_waypoints
export (NodePath) var inbound_area_path
export (NodePath) var packing_area_path
export (NodePath) var buffer_area_path
export (NodePath) var painting_area_path
export (NodePath) var labeling_area_path
export (NodePath) var outbound_area_path
export (NodePath) var charging_area_path

onready var inbound_area = get_node(inbound_area_path)
onready var packing_area = get_node(packing_area_path)
onready var buffer_area = get_node(buffer_area_path)
onready var painting_area = get_node(painting_area_path)
onready var labeling_area = get_node(labeling_area_path)
onready var outbound_area = get_node(outbound_area_path)
onready var chargine_area = get_node(charging_area_path)
