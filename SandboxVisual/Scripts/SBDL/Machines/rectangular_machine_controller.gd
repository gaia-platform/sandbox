extends KinematicBody2D

# Nodes
export(NodePath) var output_label_path
onready var output_label = get_node(output_label_path)

onready var green_roi = $GreenROI
onready var yellow_roi = $YellowROI
onready var red_roi = $RedROI

# States
var is_hit: bool
enum roi { GREEN, YELLOW, RED }
enum roi_angles { FRONT_RIGHT, SIDE_RIGHT, BACK_RIGHT, BACK_LEFT, SIDE_LEFT, FRONT_LEFT }


func _ready():
	rotation = Vector2.UP.angle()


func _physics_process(_delta):
	# Get collisions
	var body_collisions = move_and_collide(Vector2.ZERO)
	var roi_collisions = [
		green_roi.get_overlapping_bodies(),
		yellow_roi.get_overlapping_bodies(),
		red_roi.get_overlapping_bodies()
	]

	# Output
	var output_string = ""
	var this_frame_collisions = {}

	var roi_index = 0
	for roi_segment in roi_collisions:
		for body in roi_segment:
			if roi_index == roi.GREEN and roi_collisions[1].has(body):
				continue
			elif roi_index == roi.YELLOW and roi_collisions[2].has(body):
				continue

			output_string += body.name + ": "

			# Get location
			var angle = rad2deg(position.angle_to_point(body.position) - rotation)

			# Encode Info
			var info_encode = [roi_index]

			# Angle
			info_encode.append(angle)
			if angle >= 180 and angle < 225:
				output_string += "Front Right"
				info_encode.append(roi_angles.FRONT_RIGHT)
			elif angle >= 225 or angle < -45:
				output_string += "Side Right"
				info_encode.append(roi_angles.SIDE_RIGHT)
			elif angle >= -45 and angle < 0:
				output_string += "Back Right"
				info_encode.append(roi_angles.BACK_RIGHT)
			elif angle >= 0 and angle < 45:
				output_string += "Back Left"
				info_encode.append(roi_angles.BACK_LEFT)
			elif angle >= 45 and angle < 135:
				output_string += "Side Left"
				info_encode.append(roi_angles.SIDE_LEFT)
			elif angle >= 135 and angle < 180:
				output_string += "Front Left"
				info_encode.append(roi_angles.FRONT_LEFT)

			# ROI
			output_string += "; "
			match roi_index:
				roi.GREEN:
					output_string += "Green"
				roi.YELLOW:
					output_string += "Yellow"
				roi.RED:
					output_string += "Red"

			this_frame_collisions[body] = info_encode
			output_string += "\n"
		roi_index += 1

	if body_collisions != null:
		is_hit = true

	output_label.text = output_string
