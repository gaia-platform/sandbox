extends Control
# Waypoint controller
# Holds center point property


func get_location():
	var half_size = rect_size.x / 2
	return Vector2(rect_global_position.x + half_size, rect_global_position.y + half_size)
