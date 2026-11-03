class_name ChessFootballMath
extends RefCounted

# Expand touchline-to-touchline by 16.7% while preserving the original
# centre and goal Y (790). The 3D stadium derives its geometry from this rect.
const PITCH_RECT := Rect2(80.0, -50.0, 2480.0, 1680.0)
# 5v5 arcade mouth: 360 pitch units. The 290-unit first enlargement still
# looked undersized against the widened pitch and left too little real target.
const GOAL_HALF_HEIGHT := 180.0
const PENALTY_AREA_DEPTH := 265.0
const PENALTY_AREA_HALF_WIDTH := 215.0
const PENALTY_SPOT_DEPTH := 175.0

# Vertical simulation uses pitch-space units. With the current 3D contract
# (WORLD_SCALE 0.014, ground ball centre 0.18, radius 0.16, 1.50 crossbar
# centre and 0.075 bar thickness), about 80 units is the highest ball centre
# trajectory that still fits entirely below the bar.
const GOAL_MAX_FLIGHT_HEIGHT := 80.0
const GOAL_FRAME_POST_RADIUS := 16.0
const GOAL_FRAME_CROSSBAR_HEIGHT := 94.0
const GOAL_FRAME_CROSSBAR_RADIUS := 10.0
# Only narrowly missed posts or shots just over the bar merit the crowd gasp.
# Leave a safe gap beyond the physical frame hitboxes, which already have SFX.
const NEAR_MISS_SIDE_MARGIN := 64.0
const NEAR_MISS_ABOVE_MARGIN := 52.0

# The optional pitch is used only by 11v11-ready actors. All existing
# ball, match and restart callers keep the legacy 5v5 bounds by default.
static func clamp_to_pitch(position: Vector2, pitch: Rect2 = PITCH_RECT) -> Vector2:
	return Vector2(
		clampf(position.x, pitch.position.x + 20.0, pitch.end.x - 20.0),
		clampf(position.y, pitch.position.y + 20.0, pitch.end.y - 20.0)
	)

static func goal_center(attacking_team: int) -> Vector2:
	var x := PITCH_RECT.end.x if attacking_team == 0 else PITCH_RECT.position.x
	return Vector2(x, PITCH_RECT.get_center().y)

static func in_goal_mouth(position: Vector2) -> bool:
	return absf(position.y - PITCH_RECT.get_center().y) <= GOAL_HALF_HEIGHT

static func ball_fits_under_crossbar(flight_height: float) -> bool:
	return flight_height <= GOAL_MAX_FLIGHT_HEIGHT

static func close_shot_miss_at_goal_line(point: Vector2, height: float, attacking_team: int) -> bool:
	if attacking_team not in [0, 1]:
		return false
	var crossed: bool = (
		point.x > PITCH_RECT.end.x + 10.0 if attacking_team == 0
		else point.x < PITCH_RECT.position.x - 10.0
	)
	if not crossed:
		return false
	var offset_y := absf(point.y - PITCH_RECT.get_center().y)
	var outside_post := (
		offset_y > GOAL_HALF_HEIGHT + GOAL_FRAME_POST_RADIUS
		and offset_y <= GOAL_HALF_HEIGHT + GOAL_FRAME_POST_RADIUS + NEAR_MISS_SIDE_MARGIN
		and height <= GOAL_FRAME_CROSSBAR_HEIGHT + GOAL_FRAME_CROSSBAR_RADIUS
	)
	var above_bar := (
		offset_y <= GOAL_HALF_HEIGHT - GOAL_FRAME_POST_RADIUS
		and height > GOAL_FRAME_CROSSBAR_HEIGHT + GOAL_FRAME_CROSSBAR_RADIUS
		and height <= GOAL_FRAME_CROSSBAR_HEIGHT + GOAL_FRAME_CROSSBAR_RADIUS + NEAR_MISS_ABOVE_MARGIN
	)
	return outside_post or above_bar

static func goal_frame_collision(
	previous_position: Vector2,
	current_position: Vector2,
	previous_height: float,
	current_height: float,
) -> Dictionary:
	var delta_x: float = current_position.x - previous_position.x
	if absf(delta_x) < 0.001:
		return {}

	var center_y: float = PITCH_RECT.get_center().y
	var goal_lines: Array[float] = [PITCH_RECT.position.x, PITCH_RECT.end.x]
	for goal_x in goal_lines:
		var from_side: float = previous_position.x - goal_x
		var to_side: float = current_position.x - goal_x
		if from_side * to_side > 0.0:
			continue
		var ratio: float = clampf((goal_x - previous_position.x) / delta_x, 0.0, 1.0)
		var contact_y: float = lerpf(previous_position.y, current_position.y, ratio)
		var contact_height: float = lerpf(previous_height, current_height, ratio)
		var post_delta: float = absf(absf(contact_y - center_y) - GOAL_HALF_HEIGHT)
		if (
			post_delta <= GOAL_FRAME_POST_RADIUS
			and contact_height <= GOAL_FRAME_CROSSBAR_HEIGHT + GOAL_FRAME_CROSSBAR_RADIUS
		):
			return {
				"kind": "post",
				"goal_x": goal_x,
				"contact_y": contact_y,
				"contact_height": contact_height,
			}

		var inside_posts: bool = (
			absf(contact_y - center_y)
			<= GOAL_HALF_HEIGHT - GOAL_FRAME_POST_RADIUS * 0.35
		)
		if (
			inside_posts
			and absf(contact_height - GOAL_FRAME_CROSSBAR_HEIGHT)
			<= GOAL_FRAME_CROSSBAR_RADIUS
		):
			return {
				"kind": "crossbar",
				"goal_x": goal_x,
				"contact_y": contact_y,
				"contact_height": contact_height,
			}
	return {}
