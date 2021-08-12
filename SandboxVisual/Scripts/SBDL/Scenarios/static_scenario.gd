extends Node2D

export (NodePath) var machine_path
onready var machine = get_node(machine_path)

onready var test_object = $TestObject


func _ready():
	var _size_change_signal = get_tree().get_root().connect(
		"size_changed", self, "_center_machine_on_screen"
	)
	_center_machine_on_screen()


func _center_machine_on_screen():
	machine.position = get_viewport().size / 2


func _physics_process(_delta):
	test_object.position = get_viewport().get_mouse_position()
