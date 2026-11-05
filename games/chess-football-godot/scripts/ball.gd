class_name FootballBall
extends CharacterBody2D

var carrier: Footballer = null
var last_touch_team_id: int = -1
# Transient provenance for stadium reactions only. Gameplay ignores these.
# Any possession or non-shot release clears it, so passes and rebounds cannot
# masquerade as a close shot at the other goal line.
var last_release_was_shot: bool = false
var shot_flight_seconds: float = 0.0
var friction: float = 0.965
var fast_ball_friction: float = 0.982
var max_speed: float = 1260.0
var flight_height: float = 0.0
var vertical_velocity: float = 0.0
const FAST_BALL_THRESHOLD := 650.0
const BALL_GRAVITY := 1120.0
const AIR_FRICTION := 0.992
const GROUND_BOUNCE := 0.24
const MIN_BOUNCE_SPEED := 82.0
var spin_direction: float = 1.0
var reclaim_block_player: Footballer = null
var reclaim_block_seconds: float = 0.0
const RECLAIM_BLOCK_SECONDS := 0.22
# XI possession stays authoritative, but the ball rolls between successive
# touches instead of being teleported to an identical boot offset every frame.
const XI_TOUCH_STRIDE_DISTANCE := 88.0
const XI_TOUCH_BASE_LEAD := 11.0
const XI_TOUCH_PUSH_LEAD := 20.0
const XI_TOUCH_FOLLOW_PER_SECOND := 22.0
var xi_carry_distance: float = 0.0
# On a glancing (non-clean) tackle, the tackler must not magnetically
# reclaim the deflection in the same frame. Other nearby players stay eligible.
var contact_reclaim_block_player: Footballer = null
var contact_reclaim_block_seconds: float = 0.0

func attach_to(player: Footballer) -> void:
	last_release_was_shot = false
	shot_flight_seconds = 0.0
	reclaim_block_player = null
	reclaim_block_seconds = 0.0
	contact_reclaim_block_player = null
	contact_reclaim_block_seconds = 0.0
	if carrier != null:
		carrier.has_ball = false
		carrier.queue_redraw()
	carrier = player
	xi_carry_distance = 0.0
	last_touch_team_id = player.team_id
	velocity = Vector2.ZERO
	flight_height = 0.0
	vertical_velocity = 0.0
	rotation = 0.0
	player.has_ball = true
	player.queue_redraw()
	global_position = player.global_position + player.ball_anchor()

func release(direction: Vector2, power: float, lift_velocity: float = 0.0, is_shot: bool = false) -> void:
	# Tracking is sound-only and resets on every release, not just touches.
	last_release_was_shot = is_shot
	shot_flight_seconds = 0.0
	# The new kick/deflection supersedes any old glancing-contact restriction.
	contact_reclaim_block_player = null
	contact_reclaim_block_seconds = 0.0
	var previous_carrier: Footballer = carrier
	if previous_carrier != null:
		last_touch_team_id = previous_carrier.team_id
		previous_carrier.has_ball = false
		previous_carrier.queue_redraw()
	reclaim_block_player = previous_carrier
	reclaim_block_seconds = RECLAIM_BLOCK_SECONDS if previous_carrier != null else 0.0
	carrier = null
	var dir := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	spin_direction = -1.0 if dir.x < 0.0 else 1.0
	velocity = dir * minf(power, max_speed)
	flight_height = 0.0
	vertical_velocity = maxf(0.0, lift_velocity)

func tick_ball(delta: float) -> void:
	if last_release_was_shot and carrier == null:
		shot_flight_seconds += maxf(0.0, delta)
	reclaim_block_seconds = maxf(0.0, reclaim_block_seconds - delta)
	if reclaim_block_seconds <= 0.0:
		reclaim_block_player = null
	contact_reclaim_block_seconds = maxf(0.0, contact_reclaim_block_seconds - delta)
	if contact_reclaim_block_seconds <= 0.0:
		contact_reclaim_block_player = null
	if carrier != null:
		var destination: Vector2 = carrier.global_position + carrier.ball_anchor()
		if (
			carrier.match_pitch == FootballMatchFormation.ELEVEN_PITCH_RECT
			and carrier.role != "keeper"
		):
			var run_speed := carrier.velocity.length()
			if run_speed > 36.0:
				xi_carry_distance += run_speed * maxf(delta, 0.0)
				var stride_phase := fposmod(
					xi_carry_distance / XI_TOUCH_STRIDE_DISTANCE, 1.0
				)
				var forward: Vector2 = (
					carrier.dribble_direction
					if carrier.dribble_active()
					else carrier.velocity.normalized()
				)
				var lead := XI_TOUCH_BASE_LEAD + XI_TOUCH_PUSH_LEAD * sin(PI * stride_phase)
				destination += forward * lead
			# A short follow-through gives the ball its own pace on turns.
			# Zero-delta debug/restart positioning must remain deterministic.
			var follow := clampf(delta * XI_TOUCH_FOLLOW_PER_SECOND, 0.0, 1.0)
			if delta <= 0.0:
				follow = 1.0
			var previous: Vector2 = global_position
			global_position = global_position.lerp(destination, follow)
			# The carrier never loses possession to interpolation: cap the
			# offset so sharp turns cannot strand a protected ball behind.
			var offset: Vector2 = global_position - carrier.global_position
			global_position = carrier.global_position + offset.limit_length(84.0)
			if run_speed > 36.0 and delta > 0.0:
				var travelled := global_position.distance_to(previous)
				rotation += travelled * 0.012 * (-1.0 if carrier.velocity.x < 0.0 else 1.0)
		else:
			# Goalkeeper and historical five-a-side physics are unchanged.
			global_position = destination
			rotation = 0.0
		flight_height = 0.0
		vertical_velocity = 0.0
		return

	if flight_height > 0.0 or vertical_velocity > 0.0:
		vertical_velocity -= BALL_GRAVITY * delta
		flight_height += vertical_velocity * delta
		if flight_height <= 0.0:
			flight_height = 0.0
			if absf(vertical_velocity) >= MIN_BOUNCE_SPEED:
				vertical_velocity = -vertical_velocity * GROUND_BOUNCE
			else:
				vertical_velocity = 0.0

	# Ball collision/restarts are resolved explicitly by match.gd. Move with the
	# delta passed into this simulation step instead of CharacterBody2D's hidden
	# physics delta so runtime and deterministic smoke use identical kinematics.
	global_position += velocity * delta
	rotation += velocity.length() * delta * 0.012 * spin_direction
	var active_friction := AIR_FRICTION if flight_height > 0.0 else (fast_ball_friction if velocity.length() >= FAST_BALL_THRESHOLD else friction)
	velocity *= pow(active_friction, delta * 60.0)
	if velocity.length() < 4.0:
		velocity = Vector2.ZERO

func block_glancing_reclaim(player: Footballer, seconds: float) -> void:
	contact_reclaim_block_player = player
	contact_reclaim_block_seconds = maxf(0.0, seconds)


func reclaim_blocked_for(player: Footballer) -> bool:
	return (
		(reclaim_block_seconds > 0.0 and reclaim_block_player == player)
		or (
			contact_reclaim_block_seconds > 0.0
			and contact_reclaim_block_player == player
		)
	)

func airborne() -> bool:
	return flight_height > 1.0 or vertical_velocity > 1.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(0.96, 0.96, 0.92))
	draw_circle(Vector2.ZERO, 9.0, Color(0.08, 0.09, 0.10), false, 1.5)
	var center_patch := PackedVector2Array()
	for i in range(5):
		var angle := -PI * 0.5 + TAU * float(i) / 5.0
		center_patch.append(Vector2(cos(angle), sin(angle)) * 3.4)
	draw_colored_polygon(center_patch, Color(0.11, 0.12, 0.13))
	draw_circle(Vector2(-5.5, 2.5), 1.8, Color(0.16, 0.17, 0.18))
	draw_circle(Vector2(5.5, 2.3), 1.7, Color(0.16, 0.17, 0.18))
