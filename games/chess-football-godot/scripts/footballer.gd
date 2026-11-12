class_name Footballer
extends CharacterBody2D

const MatchScouting = preload("res://scripts/football_match_scouting.gd")
const Formation = preload("res://scripts/football_match_formation.gd")

var team_id: int = 0
var squad_index: int = 0
var role: String = "midfielder"
var base_speed: float = 250.0
# Each actor uses its own real pitch bounds; 5v5 stays the default.
# The expanded 11v11 field is testable without switching live match rules.
var match_pitch: Rect2 = ChessFootballMath.PITCH_RECT
# Player identities come from the canonical 54-player scouting snapshot.
var scouting_player_id: String = ""
var scouting_player_name: String = ""
var scouting_pace: int = 75
var scouting_endurance: int = 75
var scouting_passing: int = 75
var scouting_shooting: int = 75
var scouting_technique: int = 75
var scouting_tackling: int = 75
var scouting_keeping: int = 75
var technique_control_multiplier: float = 1.0
var movement_multiplier: float = 1.0
var stamina_drain_multiplier: float = 1.0
const MOVE_ACCELERATION := 1650.0
const MOVE_DECELERATION := 2150.0
const SPRINT_SPEED_MULTIPLIER := 1.34
const STAMINA_MAX := 100.0
const STAMINA_DRAIN_PER_SECOND := 45.0
const STAMINA_RECOVER_MOVING_PER_SECOND := 11.0
const STAMINA_RECOVER_IDLE_PER_SECOND := 19.0
const STAMINA_RECOVER_THRESHOLD := 40.0
const AI_SPRINT_INTENSITY := 0.94
const AI_EXHAUSTED_INTENSITY_CAP := 0.82
# Keepers need a sharp lateral shuffle to react to a shot. Outfield movement,
# dribbling and the penalty keeper's separately controlled speed are unchanged.
const KEEPER_AI_SPEED_MULTIPLIER := 1.65
const KEEPER_AI_ACCELERATION_MULTIPLIER := 1.50
const TACKLE_ACTIVE_SECONDS := 0.18
const SLIDE_TACKLE_ACTIVE_SECONDS := 0.24
const DRIBBLE_BURST_SECONDS := 0.22
# XI E in motion is a planted SIDE CUT, not a 1.52x sprint.
# Its longer three-beat window has a similar total travel footprint.
const XI_DRIBBLE_CUT_SECONDS := 0.34
const DRIBBLE_COOLDOWN_SECONDS := 0.68
const DRIBBLE_SPEED_MULTIPLIER := 1.52
const DRIBBLE_ACCELERATION := 3900.0
const DRIBBLE_TOUCH_DISTANCE := 24.0
const DRIBBLE_FEINT_SECONDS := 0.16
# XI only: allow two rendered shoulder beats while preserving the old feint
# travel footprint. 5v5/keepers retain their historical timings.
const XI_DRIBBLE_FEINT_SECONDS := 0.24
const DRIBBLE_LONG_TOUCH_SECONDS := 0.27
const DRIBBLE_FEINT_SPEED := 0.65
const XI_DRIBBLE_FEINT_SPEED := 0.44
const DRIBBLE_LONG_TOUCH_SPEED := 1.56
const DRIBBLE_FEINT_TOUCH := 8.0
const DRIBBLE_LONG_TOUCH := 32.0
const FACING_SWITCH_SPEED := 18.0
var home_position: Vector2
var active: bool = false
var has_ball: bool = false
var ai_target: Vector2
var team_color: Color = Color(0.2, 0.45, 0.95)

var visual: AnimatedSprite2D
var transition_visual: AnimatedSprite2D
const LOCOMOTION_CROSSFADE_SECONDS := 0.10
const ACTION_CROSSFADE_SECONDS := 0.08
var visual_crossfade_seconds: float = 0.0
var visual_crossfade_total: float = 0.0
var action_lock_seconds: float = 0.0
# Visual duration is the original action's requested lock. The 11v11
# presenter needs it to display every *authored* pass/shot pose even when
# a quick kick releases before 8 frames at 10 FPS would naturally finish.
# This never alters the authoritative action lock or ball release timing.
var action_visual_duration_seconds: float = 0.0
var tackle_cooldown_seconds: float = 0.0
var tackle_recovery_seconds: float = 0.0
var tackle_active_seconds: float = 0.0
var tackle_launch_speed_ratio: float = 0.0
var tackle_aggressive: bool = false
var dribble_cooldown_seconds: float = 0.0
var dribble_burst_seconds: float = 0.0
var dribble_direction: Vector2 = Vector2.RIGHT
var dribble_entry_direction: Vector2 = Vector2.RIGHT
var dribble_mode: String = "cut"
var dribble_duration_seconds: float = DRIBBLE_BURST_SECONDS
var dribble_touch_distance: float = DRIBBLE_TOUCH_DISTANCE
var yellow_cards: int = 0
var sent_off: bool = false
var contact_stun_seconds: float = 0.0
var contact_stun_total: float = 0.0
# XI contact/down state is owned by the physical player, not a 3D sprite.
var xi_collision_down_seconds: float = 0.0
var xi_collision_down_total: float = 0.0
var xi_collision_guard_seconds: float = 0.0
# Impact vector is stored solely for a bounded visual fall/recovery.
# It NEVER changes collision position, heading, ball or pickup authority.
var xi_collision_push_direction: Vector2 = Vector2.ZERO
var contact_sway_sign: float = 1.0
var keeper_hold_seconds: float = 0.0
var keeper_save_seconds: float = 0.0
var keeper_save_total: float = 0.0
var keeper_save_direction: float = 1.0
var last_sprinting: bool = false
var stamina: float = STAMINA_MAX
var sprint_exhausted: bool = false

func configure(p_team_id: int, p_index: int, p_role: String, p_position: Vector2, p_color: Color, p_team_size: int = 5) -> void:
	match_pitch = Formation.ELEVEN_PITCH_RECT if p_team_size == 11 else ChessFootballMath.PITCH_RECT
	team_id = p_team_id
	squad_index = p_index
	role = p_role
	global_position = p_position
	home_position = p_position
	ai_target = p_position
	team_color = p_color
	_apply_match_scouting(p_team_size)
	_configure_visual()
	queue_redraw()

# Keep goalkeepers' established lateral save speed unchanged. Outfield
# players use a bounded ±10% pace factor in both human and AI movement;
# stamina changes sprint drain by -10% to +20% only, never match rules or saved careers.
func _apply_match_scouting(p_team_size: int = 5) -> void:
	var profile: Dictionary = MatchScouting.starter(team_id, squad_index, p_team_size)
	scouting_player_id = String(profile.get("id", ""))
	scouting_player_name = String(profile.get("name", ""))
	var stats: Dictionary = profile.get("scouting", {})
	scouting_pace = int(stats.get("pace", 75))
	scouting_endurance = int(stats.get("stamina", 75))
	scouting_passing = int(stats.get("passing", 75))
	scouting_shooting = int(stats.get("shooting", 75))
	scouting_technique = int(stats.get("technique", 75))
	scouting_tackling = int(stats.get("tackling", 75))
	scouting_keeping = int(stats.get("keeping", 75))
	technique_control_multiplier = clampf(
		1.0 + float(scouting_technique - 75) * 0.0025, 0.93, 1.06
	)
	movement_multiplier = 1.0 if role == "keeper" else clampf(
		1.0 + float(scouting_pace - 75) * 0.005, 0.90, 1.10
	)
	# Base speed is the actor's real scouting-adjusted cruising speed.
	# Tackle and exhaustion checks already work relative to this field.
	base_speed = 250.0 * movement_multiplier
	stamina_drain_multiplier = clampf(
		1.0 - float(scouting_endurance - 75) * 0.008, 0.90, 1.20
	)

# Only ball velocity changes for passes/shots; direction and goalkeeper
# mechanics remain intact. Rating 75 is neutral for legacy actors.
func pass_power_multiplier() -> float:
	return clampf(1.0 + float(scouting_passing - 75) * 0.004, 0.86, 1.10)

func shot_power_multiplier() -> float:
	return clampf(1.0 + float(scouting_shooting - 75) * 0.004, 0.86, 1.10)

# Defense sharpens only the clean front-on section of a real physical
# tackle; it never extends the contact zone, or bypasses foul checks.
func clean_tackle_multiplier() -> float:
	return clampf(1.0 + float(scouting_tackling - 75) * 0.003, 0.88, 1.08)

# Goalkeeping improves early shot recognition and nearby hand reach, not
# teleportation, immunity to high balls or the keeper's movement speed.
func keeper_reflex_multiplier() -> float:
	return clampf(1.0 + float(scouting_keeping - 75) * 0.003, 0.92, 1.08)

func _configure_visual() -> void:
	if visual == null:
		visual = AnimatedSprite2D.new()
		add_child(visual)
	if transition_visual == null:
		transition_visual = AnimatedSprite2D.new()
		transition_visual.visible = false
		add_child(transition_visual)
	visual.sprite_frames = ChessFootballSpriteBank.build_frames(team_id, role, squad_index)
	transition_visual.sprite_frames = visual.sprite_frames
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	transition_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visual.centered = true
	var cell := ChessFootballSpriteBank.cell_size()
	var visual_scale := ChessFootballSpriteBank.display_scale()
	visual.scale = Vector2.ONE * visual_scale
	visual.position = Vector2(0.0, -(ChessFootballSpriteBank.footline() - cell.y * 0.5) * visual_scale)
	transition_visual.scale = visual.scale
	transition_visual.position = visual.position
	visual.flip_h = team_id == 1
	transition_visual.flip_h = visual.flip_h
	visual.play("idle")
	_apply_loop_phase(&"idle")

func _process(delta: float) -> void:
	_tick_visual_crossfade(delta)
	tackle_cooldown_seconds = maxf(0.0, tackle_cooldown_seconds - delta)
	dribble_cooldown_seconds = maxf(0.0, dribble_cooldown_seconds - delta)
	dribble_burst_seconds = maxf(0.0, dribble_burst_seconds - delta)
	tackle_recovery_seconds = maxf(0.0, tackle_recovery_seconds - delta)
	tackle_active_seconds = maxf(0.0, tackle_active_seconds - delta)
	if tackle_active_seconds <= 0.0:
		tackle_launch_speed_ratio = 0.0
		tackle_aggressive = false
	contact_stun_seconds = maxf(0.0, contact_stun_seconds - delta)
	xi_collision_down_seconds = maxf(0.0, xi_collision_down_seconds - delta)
	xi_collision_guard_seconds = maxf(0.0, xi_collision_guard_seconds - delta)
	keeper_hold_seconds = maxf(0.0, keeper_hold_seconds - delta)
	keeper_save_seconds = maxf(0.0, keeper_save_seconds - delta)
	if action_lock_seconds <= 0.0:
		return
	action_lock_seconds = maxf(0.0, action_lock_seconds - delta)
	if action_lock_seconds <= 0.0:
		_sync_locomotion(last_sprinting)

func set_active(value: bool) -> void:
	active = value
	queue_redraw()

func move_human(delta: float, direction: Vector2, sprinting: bool) -> void:
	if xi_collision_down_seconds > 0.0:
		velocity = Vector2.ZERO
		return
	if sent_off:
		velocity = Vector2.ZERO
		return
	if dribble_active() and not has_ball:
		dribble_burst_seconds = 0.0
	var dribbling := dribble_active() and has_ball
	# The first E plant still sells the feint. Only after the second boot
	# commits may the human steer the exit; no instant snap or invulnerability.
	var xi_feint_exit: float = _xi_feint_exit_ratio()
	var xi_cut_exit: float = _xi_cut_exit_ratio()
	var wanted_direction := dribble_direction if dribbling else direction
	if dribbling and match_pitch == Formation.ELEVEN_PITCH_RECT and role != "keeper" and dribble_mode == "cut":
		# First plant follows the actual run, then the ball carrier cuts
		# across the line before a bounded, steerable exit. No teleport.
		wanted_direction = _xi_cut_motion_direction()
	if xi_feint_exit > 0.0 and direction.length_squared() > 0.04:
		wanted_direction = dribble_direction.lerp(
			direction.normalized(), xi_feint_exit * 0.80
		).normalized()
	elif xi_cut_exit > 0.0 and direction.length_squared() > 0.04:
		# The cut sells its planted foot first; then the human may guide the
		# exit by at most 45 degrees. No U-turn, speed bonus or tackle immunity.
		var turn_angle: float = clampf(
			dribble_direction.angle_to(direction.normalized()),
			-deg_to_rad(45.0), deg_to_rad(45.0)
		)
		wanted_direction = dribble_direction.rotated(turn_angle * xi_cut_exit)
	var moving := wanted_direction.length_squared() > 0.001
	var actual_sprint := _update_stamina(delta, sprinting and not dribbling, moving)
	last_sprinting = actual_sprint or dribbling
	var xi_feint_speed := (
		lerpf(XI_DRIBBLE_FEINT_SPEED, 1.10, xi_feint_exit)
		if match_pitch == Formation.ELEVEN_PITCH_RECT and role != "keeper"
		else DRIBBLE_FEINT_SPEED
	)
	var speed := (
		base_speed * (
			xi_feint_speed if dribble_mode == "feint"
			else DRIBBLE_LONG_TOUCH_SPEED if dribble_mode == "burst"
			else (
				_xi_cut_speed_multiplier()
				if dribble_mode == "cut" and match_pitch == Formation.ELEVEN_PITCH_RECT and role != "keeper"
				else DRIBBLE_SPEED_MULTIPLIER
			)
		)
		if dribbling
		else base_speed * (SPRINT_SPEED_MULTIPLIER if actual_sprint else 1.0)
	)
	# Technique affects dribbling/carrying only, never off-ball sprints.
	if has_ball and role != "keeper":
		speed *= technique_control_multiplier
	if tackle_recovery_seconds > 0.0:
		speed *= 0.42
	if contact_stun_seconds > 0.0:
		speed *= 0.32
	var desired := wanted_direction.normalized() * speed if moving else Vector2.ZERO
	var acceleration := (
		DRIBBLE_ACCELERATION
		if dribbling
		else (MOVE_ACCELERATION if desired.length_squared() > 0.001 else MOVE_DECELERATION)
	)
	velocity = velocity.move_toward(desired, acceleration * delta)
	if velocity.length() < 1.0:
		velocity = Vector2.ZERO
	move_and_slide()
	global_position = ChessFootballMath.clamp_to_pitch(global_position, match_pitch)
	_sync_facing()
	_sync_locomotion(actual_sprint or dribbling)

func move_ai(delta: float, target: Vector2, intensity: float = 1.0) -> void:
	if xi_collision_down_seconds > 0.0:
		velocity = Vector2.ZERO
		return
	if sent_off:
		velocity = Vector2.ZERO
		return
	ai_target = target
	var offset := target - global_position
	var moving := offset.length() >= 8.0
	var sprint_requested := role != "keeper" and intensity >= AI_SPRINT_INTENSITY
	var actual_sprint := _update_stamina(delta, sprint_requested, moving)
	last_sprinting = actual_sprint
	var effective_intensity := clampf(intensity, 0.35, 1.0)
	if sprint_requested and not actual_sprint:
		effective_intensity = minf(effective_intensity, AI_EXHAUSTED_INTENSITY_CAP)
	var recovery_scale := 0.42 if tackle_recovery_seconds > 0.0 else 1.0
	if contact_stun_seconds > 0.0:
		recovery_scale *= 0.32
	var desired := Vector2.ZERO
	if moving:
		var keeper_boost := KEEPER_AI_SPEED_MULTIPLIER if role == "keeper" else 1.0
		# Previously the CPU paid stamina and played sprint frames, but ran at
		# jogging speed. A human sprint could therefore outrun every defender.
		var sprint_boost := SPRINT_SPEED_MULTIPLIER if actual_sprint else 1.0
		desired = offset.normalized() * base_speed * sprint_boost * effective_intensity * recovery_scale * keeper_boost
		if has_ball and role != "keeper":
			desired *= technique_control_multiplier
	var acceleration := MOVE_ACCELERATION if desired.length_squared() > 0.001 else MOVE_DECELERATION
	if role == "keeper":
		acceleration *= KEEPER_AI_ACCELERATION_MULTIPLIER
	velocity = velocity.move_toward(desired, acceleration * delta)
	if velocity.length() < 1.0:
		velocity = Vector2.ZERO
	move_and_slide()
	global_position = ChessFootballMath.clamp_to_pitch(global_position, match_pitch)
	_sync_facing()
	_sync_locomotion(actual_sprint)

func _update_stamina(delta: float, sprint_requested: bool, moving: bool) -> bool:
	var before := stamina
	var actual_sprint := sprint_requested and moving and not sprint_exhausted and stamina > 0.0
	if actual_sprint:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN_PER_SECOND * stamina_drain_multiplier * delta)
		if stamina <= 0.01:
			stamina = 0.0
			sprint_exhausted = true
			actual_sprint = false
	else:
		var recovery_rate := STAMINA_RECOVER_MOVING_PER_SECOND if moving else STAMINA_RECOVER_IDLE_PER_SECOND
		stamina = minf(STAMINA_MAX, stamina + recovery_rate * delta)
		if sprint_exhausted and stamina >= STAMINA_RECOVER_THRESHOLD:
			sprint_exhausted = false
	if absf(stamina - before) > 0.001:
		queue_redraw()
	return actual_sprint

func stamina_ratio() -> float:
	return clampf(stamina / STAMINA_MAX, 0.0, 1.0)

func can_sprint() -> bool:
	return not sprint_exhausted and stamina > 0.0

func play_action(animation_name: String, duration: float = 0.78) -> void:
	if visual == null or not visual.sprite_frames.has_animation(animation_name):
		return
	var previous := String(visual.animation)
	if previous in ["run", "sprint"]:
		_begin_visual_crossfade(ACTION_CROSSFADE_SECONDS)
	else:
		_cancel_visual_crossfade()
	action_lock_seconds = maxf(duration, 0.05)
	action_visual_duration_seconds = action_lock_seconds
	visual.speed_scale = 1.0
	visual.play(animation_name)

func can_tackle() -> bool:
	return (
		not sent_off
		and xi_collision_down_seconds <= 0.0
		and not has_ball
		and tackle_cooldown_seconds <= 0.0
		and action_lock_seconds <= 0.0
	)

func start_tackle(aggressive: bool = false) -> bool:
	if not can_tackle():
		return false
	tackle_aggressive = aggressive
	tackle_cooldown_seconds = 1.45 if aggressive else 1.10
	tackle_recovery_seconds = 0.68 if aggressive else 0.38
	tackle_active_seconds = SLIDE_TACKLE_ACTIVE_SECONDS if aggressive else TACKLE_ACTIVE_SECONDS
	tackle_launch_speed_ratio = clampf(
		velocity.length() / maxf(base_speed, 1.0),
		0.0,
		1.35,
	)
	velocity *= 0.68 if aggressive else 0.35
	play_action("slide_tackle" if aggressive else "tackle", 0.64 if aggressive else 0.50)
	return true

func tackle_active() -> bool:
	return tackle_active_seconds > 0.0

func tackle_aggressive_active() -> bool:
	return tackle_active() and tackle_aggressive

func tackle_momentum_ratio() -> float:
	return tackle_launch_speed_ratio if tackle_active() else 0.0

func can_dribble() -> bool:
	return (
		not sent_off
		and xi_collision_down_seconds <= 0.0
		and has_ball
		and dribble_cooldown_seconds <= 0.0
		and dribble_burst_seconds <= 0.0
		and action_lock_seconds <= 0.0
		and contact_stun_seconds <= 0.0
		and tackle_recovery_seconds <= 0.0
	)

func start_dribble(direction: Vector2, kind: String = "cut") -> bool:
	if not can_dribble() or kind not in ["feint", "cut", "burst"]:
		return false
	var wanted := direction
	if wanted.length_squared() < 0.001:
		var facing := -1.0 if visual != null and visual.flip_h else 1.0
		wanted = Vector2(facing, 0.0)
	var entering_velocity: Vector2 = velocity
	dribble_direction = wanted.normalized()
	dribble_entry_direction = dribble_direction
	if (
		kind == "cut" and match_pitch == Formation.ELEVEN_PITCH_RECT
		and role != "keeper" and entering_velocity.length_squared() > 144.0
		and entering_velocity.normalized().dot(dribble_direction) > 0.20
	):
		dribble_entry_direction = entering_velocity.normalized()
	dribble_mode = kind
	var feint_window := (
		XI_DRIBBLE_FEINT_SECONDS
		if match_pitch == Formation.ELEVEN_PITCH_RECT and role != "keeper"
		else DRIBBLE_FEINT_SECONDS
	)
	dribble_duration_seconds = (
		feint_window if kind == "feint"
		else DRIBBLE_LONG_TOUCH_SECONDS if kind == "burst"
		else XI_DRIBBLE_CUT_SECONDS if kind == "cut" and match_pitch == Formation.ELEVEN_PITCH_RECT and role != "keeper"
		else DRIBBLE_BURST_SECONDS
	)
	dribble_touch_distance = (
		DRIBBLE_FEINT_TOUCH if kind == "feint"
		else DRIBBLE_LONG_TOUCH if kind == "burst"
		else DRIBBLE_TOUCH_DISTANCE
	)
	dribble_burst_seconds = dribble_duration_seconds
	# Scouting technique makes execution/recovery noticeably more responsive,
	# not an RNG success roll or collision immunity. Rating 75 is neutral.
	var base_cooldown := (
		0.48 if kind == "feint" else 0.88 if kind == "burst" else DRIBBLE_COOLDOWN_SECONDS
	)
	dribble_cooldown_seconds = base_cooldown * clampf(
		1.0 - float(scouting_technique - 75) * 0.004, 0.90, 1.18
	)
	velocity = dribble_direction * base_speed * (0.20 if kind == "feint" else 0.72)
	return true

func dribble_active() -> bool:
	return dribble_burst_seconds > 0.0


# A real second boot plant powers a short, steerable exit from stationary E.
# 5v5, goalkeepers, cut and long touch retain their exact old motion. Keep
# this driven by the authoritative action timer so FPS cannot change balance.
func _xi_feint_exit_ratio() -> float:
	if (
		match_pitch != Formation.ELEVEN_PITCH_RECT
		or role == "keeper"
		or not has_ball
		or not dribble_active()
		or dribble_mode != "feint"
	):
		return 0.0
	var progress: float = 1.0 - clampf(
		dribble_burst_seconds / maxf(dribble_duration_seconds, 0.001),
		0.0, 1.0
	)
	return smoothstep(0.55, 0.92, progress)


# Three genuine physical beats in XI: a brief running-foot plant, a
# lateral ball touch, and a controlled acceleration into the new lane.
# Physical possession, tackling, and cooldowns still use their real clocks.
func _xi_cut_progress() -> float:
	return clampf(
		1.0 - dribble_burst_seconds / maxf(dribble_duration_seconds, 0.001),
		0.0, 1.0
	)


func _xi_cut_motion_direction() -> Vector2:
	if (
		match_pitch != Formation.ELEVEN_PITCH_RECT or role == "keeper"
		or not dribble_active() or dribble_mode != "cut"
	):
		return dribble_direction
	return dribble_entry_direction.lerp(
		# Reach the lateral lane by mid-touch, not only as E finishes:
		# a sharper planted foot makes the cut visible from match zoom.
		dribble_direction, smoothstep(0.10, 0.52, _xi_cut_progress())
	).normalized()


func _xi_cut_speed_multiplier() -> float:
	var progress := _xi_cut_progress()
	if progress < 0.25:
		return lerpf(0.82, 0.72, smoothstep(0.0, 0.25, progress))
	if progress < 0.64:
		return lerpf(0.72, 1.05, smoothstep(0.25, 0.64, progress))
	# Finishing the cut is quicker than the plant, but NEVER a sprint buff:
	# 1.24 < ordinary 1.34x sprint; F retains the real long-touch burst.
	return lerpf(1.05, 1.24, smoothstep(0.64, 1.0, progress))


# Only after the planted touch may the human steer the exit by <= 45 deg.
# 5v5 and keeper motion retain their original code path.
func _xi_cut_exit_ratio() -> float:
	if (
		match_pitch != Formation.ELEVEN_PITCH_RECT
		or role == "keeper"
		or not has_ball
		or not dribble_active()
		or dribble_mode != "cut"
	):
		return 0.0
	var progress: float = 1.0 - clampf(
		dribble_burst_seconds / maxf(dribble_duration_seconds, 0.001),
		0.0, 1.0
	)
	# Preserve the chosen sidestep through most of the boot contact;
	# only then hand control back for the deliberate 45-degree exit.
	return smoothstep(0.82, 0.95, progress)


func dribble_touch_ratio() -> float:
	if not dribble_active():
		return 0.0
	var progress := 1.0 - clampf(dribble_burst_seconds / maxf(dribble_duration_seconds, 0.001), 0.0, 1.0)
	return sin(PI * progress)

func receive_yellow_card() -> bool:
	if sent_off:
		return true
	yellow_cards += 1
	if yellow_cards >= 2:
		send_off()
		return true
	return false

func receive_red_card() -> void:
	send_off()

func send_off() -> void:
	if sent_off:
		return
	sent_off = true
	active = false
	has_ball = false
	velocity = Vector2.ZERO
	tackle_cooldown_seconds = 0.0
	tackle_recovery_seconds = 0.0
	tackle_active_seconds = 0.0
	tackle_launch_speed_ratio = 0.0
	tackle_aggressive = false
	dribble_cooldown_seconds = 0.0
	dribble_burst_seconds = 0.0
	dribble_direction = Vector2.RIGHT
	dribble_mode = "cut"
	dribble_duration_seconds = DRIBBLE_BURST_SECONDS
	dribble_touch_distance = DRIBBLE_TOUCH_DISTANCE
	action_lock_seconds = 0.0
	contact_stun_seconds = 0.0
	xi_collision_down_seconds = 0.0
	xi_collision_guard_seconds = 0.0
	collision_layer = 0
	collision_mask = 0
	queue_redraw()

func available_for_play() -> bool:
	return not sent_off

func receive_tackle_contact(push_direction: Vector2, duration: float = 0.30) -> void:
	dribble_burst_seconds = 0.0
	contact_stun_total = maxf(duration, 0.05)
	contact_stun_seconds = contact_stun_total
	tackle_recovery_seconds = maxf(tackle_recovery_seconds, duration + 0.08)
	var push := push_direction.normalized() if push_direction.length_squared() > 0.001 else Vector2.RIGHT
	if absf(push.x) > 0.01:
		contact_sway_sign = signf(push.x)
	# Separate the bodies immediately so a clean tackle reads as contact,
	# deflection and recovery instead of two sprites merging into one.
	global_position = ChessFootballMath.clamp_to_pitch(global_position + push * 24.0)
	velocity = push * base_speed * 0.42


# Temporary XI fallback until authored fall/get-up atlases are approved.
# A fall is a real no-movement, no-pickup state. Both actors retain their
# ordinary physical colliders and recover automatically on their own clock.
func xi_collision_stumble(seconds: float) -> void:
	contact_stun_total = maxf(seconds, 0.08)
	contact_stun_seconds = maxf(contact_stun_seconds, contact_stun_total)
	dribble_burst_seconds = 0.0
	velocity *= 0.42


func xi_collision_fall(push: Vector2, seconds: float) -> void:
	xi_collision_push_direction = push.normalized() if push.length_squared() > 0.001 else Vector2.ZERO
	xi_collision_down_total = maxf(seconds, 0.40)
	xi_collision_down_seconds = xi_collision_down_total
	contact_stun_total = xi_collision_down_total
	contact_stun_seconds = maxf(contact_stun_seconds, xi_collision_down_total)
	dribble_burst_seconds = 0.0
	if push.length_squared() > 0.001:
		contact_sway_sign = -1.0 if push.x < 0.0 else 1.0
	velocity = Vector2.ZERO


func xi_collision_down_ratio() -> float:
	if xi_collision_down_total <= 0.0:
		return 0.0
	return clampf(xi_collision_down_seconds / xi_collision_down_total, 0.0, 1.0)


func contact_stun_active() -> bool:
	return contact_stun_seconds > 0.0

func contact_stun_ratio() -> float:
	if contact_stun_total <= 0.0:
		return 0.0
	return clampf(contact_stun_seconds / contact_stun_total, 0.0, 1.0)

func begin_keeper_hold(duration: float = 0.72) -> void:
	keeper_hold_seconds = maxf(duration, 0.0)

func begin_keeper_save(direction: float, duration: float = 0.58) -> void:
	keeper_save_total = maxf(duration, 0.05)
	keeper_save_seconds = keeper_save_total
	keeper_save_direction = -1.0 if direction < 0.0 else 1.0
	play_action("tackle", duration)

func keeper_hold_active() -> bool:
	return keeper_hold_seconds > 0.0

func keeper_save_active() -> bool:
	return keeper_save_seconds > 0.0

func keeper_save_ratio() -> float:
	if keeper_save_total <= 0.0:
		return 0.0
	return clampf(keeper_save_seconds / keeper_save_total, 0.0, 1.0)

func ball_anchor() -> Vector2:
	var facing := -1.0 if visual != null and visual.flip_h else 1.0
	# Keep legacy 5v5 and keeper catches untouched.
	if match_pitch != Formation.ELEVEN_PITCH_RECT or role == "keeper":
		var legacy := Vector2(18.0 * facing * scale.x, -5.0)
		if dribble_active():
			legacy += dribble_direction * dribble_touch_distance * dribble_touch_ratio()
		return legacy
	# The previous fixed horizontal +18/-5 offset put the ball *between*
	# the legs or beside a runner travelling vertically/diagonally.
	# This is the authoritative 2D ball anchor so its shadow, 3D rendering,
	# possession and release location agree; no visual/physics split.
	var forward: Vector2 = dribble_direction if dribble_active() else velocity
	if dribble_active() and dribble_mode == "cut":
		# Ball and planted body follow the same gradual lane change.
		forward = _xi_cut_motion_direction()
	if forward.length_squared() < 0.001:
		forward = Vector2(facing, 0.0)
	else:
		forward = forward.normalized()
	var touch_distance := 37.0
	if dribble_active():
		touch_distance += dribble_touch_distance * dribble_touch_ratio()
	# Slightly out of the support-foot axis, but always AHEAD of travel.
	var side := Vector2(-forward.y, forward.x) * (3.5 * facing)
	return forward * touch_distance + side

func _sync_facing() -> void:
	if visual == null or absf(velocity.x) < FACING_SWITCH_SPEED:
		return
	var face_left := velocity.x < 0.0
	if visual.flip_h == face_left:
		return
	visual.flip_h = face_left
	if transition_visual != null:
		transition_visual.flip_h = face_left

func _locomotion_speed_scale(wanted: String) -> float:
	if wanted == "idle":
		return 1.0
	var reference_speed := base_speed
	if wanted == "sprint":
		reference_speed *= SPRINT_SPEED_MULTIPLIER
	var speed_ratio := clampf(velocity.length() / maxf(reference_speed, 1.0), 0.0, 1.15)
	if wanted == "sprint":
		return lerpf(0.82, 1.12, speed_ratio)
	return lerpf(0.78, 1.06, speed_ratio)


func _sync_locomotion(sprinting: bool) -> void:
	if visual == null or action_lock_seconds > 0.0:
		return
	var wanted := "idle"
	if velocity.length() >= 12.0:
		wanted = "sprint" if sprinting else "run"
	var wanted_speed_scale := _locomotion_speed_scale(wanted)
	if String(visual.animation) != wanted or not visual.is_playing():
		var previous := String(visual.animation)
		var preserve_raster_phase := previous in ["run", "sprint"] and wanted in ["run", "sprint"]
		var previous_frame := visual.frame
		var previous_progress := visual.frame_progress
		var crosses_idle_boundary := (
			previous == "idle" and wanted in ["run", "sprint"]
		) or (
			wanted == "idle" and previous in ["run", "sprint"]
		)
		var returns_from_action := (
			previous in ["pass", "shoot", "tackle", "slide_tackle", "celebrate"]
			and wanted in ["run", "sprint"]
		)
		if crosses_idle_boundary:
			_begin_visual_crossfade(LOCOMOTION_CROSSFADE_SECONDS)
		elif returns_from_action:
			_begin_visual_crossfade(ACTION_CROSSFADE_SECONDS)
		else:
			_cancel_visual_crossfade()
		visual.play(wanted)
		visual.speed_scale = wanted_speed_scale
		if preserve_raster_phase:
			var frame_count := visual.sprite_frames.get_frame_count(StringName(wanted))
			visual.frame = previous_frame % maxi(frame_count, 1)
			visual.frame_progress = previous_progress
		else:
			_apply_loop_phase(StringName(wanted))
	else:
		visual.speed_scale = wanted_speed_scale


func _begin_visual_crossfade(duration: float) -> void:
	if transition_visual == null or visual == null or visual.sprite_frames == null:
		return
	_cancel_visual_crossfade()
	transition_visual.sprite_frames = visual.sprite_frames
	transition_visual.play(visual.animation)
	transition_visual.frame = visual.frame
	transition_visual.frame_progress = visual.frame_progress
	transition_visual.speed_scale = visual.speed_scale
	transition_visual.flip_h = visual.flip_h
	transition_visual.visible = true
	transition_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	visual.modulate = Color(1.0, 1.0, 1.0, 0.0)
	visual_crossfade_total = maxf(duration, 0.01)
	visual_crossfade_seconds = visual_crossfade_total


func _tick_visual_crossfade(delta: float) -> void:
	if visual_crossfade_seconds <= 0.0:
		return
	visual_crossfade_seconds = maxf(0.0, visual_crossfade_seconds - delta)
	var progress := 1.0 - visual_crossfade_seconds / maxf(visual_crossfade_total, 0.01)
	progress = clampf(progress, 0.0, 1.0)
	if visual != null:
		visual.modulate = Color(1.0, 1.0, 1.0, progress)
	if transition_visual != null:
		transition_visual.modulate = Color(1.0, 1.0, 1.0, 1.0 - progress)
	if visual_crossfade_seconds <= 0.0:
		_cancel_visual_crossfade()


func _cancel_visual_crossfade() -> void:
	visual_crossfade_seconds = 0.0
	visual_crossfade_total = 0.0
	if visual != null:
		visual.modulate = Color.WHITE
	if transition_visual != null:
		transition_visual.stop()
		transition_visual.visible = false
		transition_visual.modulate = Color.WHITE


func _loop_phase_frame(animation_name: StringName) -> int:
	if visual == null or visual.sprite_frames == null:
		return 0
	var count := visual.sprite_frames.get_frame_count(animation_name)
	if count <= 1:
		return 0
	# Deterministic per-player phase offsets stop a five-a-side lineup from
	# breathing/running in lockstep like cloned mannequins.
	var seed := team_id * 5 + squad_index * 3
	return ((seed % count) + count) % count

func _apply_loop_phase(animation_name: StringName) -> void:
	if visual == null or not (animation_name in [&"idle", &"run", &"sprint"]):
		return
	visual.frame = _loop_phase_frame(animation_name)


func debug_locomotion_crossfade_active() -> bool:
	return visual_crossfade_seconds > 0.0


func debug_locomotion_crossfade_alpha() -> float:
	return visual.modulate.a if visual != null else 1.0


func debug_visual_crossfade_total() -> float:
	return visual_crossfade_total


func debug_transition_visual_playing() -> bool:
	return transition_visual != null and transition_visual.is_playing()


func debug_transition_visual_speed_scale() -> float:
	return transition_visual.speed_scale if transition_visual != null else 1.0


func debug_locomotion_speed_scale(wanted: String) -> float:
	return _locomotion_speed_scale(wanted)


func debug_texture_filter_linear() -> bool:
	return (
		visual != null
		and transition_visual != null
		and visual.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR
		and transition_visual.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR
	)


func debug_visual_flip_h() -> bool:
	return visual != null and visual.flip_h


func debug_visual_ready() -> bool:
	return visual != null and visual.sprite_frames != null

func debug_animation_names() -> PackedStringArray:
	return ChessFootballSpriteBank.animation_names()

func debug_visual_variant_key() -> String:
	return ChessFootballSpriteBank.atlas_key(team_id, role, squad_index)

func debug_loop_phase_frame(animation_name: StringName) -> int:
	return _loop_phase_frame(animation_name)

func debug_tackle_ready() -> bool:
	return can_tackle()

func debug_tackle_active() -> bool:
	return tackle_active()

func debug_tackle_aggressive() -> bool:
	return tackle_aggressive_active()

func debug_dribble_ready() -> bool:
	return can_dribble()

func debug_dribble_active() -> bool:
	return dribble_active()

func debug_dribble_direction() -> Vector2:
	return dribble_direction

func debug_yellow_cards() -> int:
	return yellow_cards

func debug_sent_off() -> bool:
	return sent_off

func debug_keeper_hold_active() -> bool:
	return keeper_hold_active()

func debug_keeper_save_active() -> bool:
	return keeper_save_active()

func debug_keeper_save_direction() -> float:
	return keeper_save_direction

func debug_stamina_ratio() -> float:
	return stamina_ratio()

func debug_stamina_exhausted() -> bool:
	return sprint_exhausted

func debug_set_stamina(value: float, exhausted: bool = false) -> void:
	stamina = clampf(value, 0.0, STAMINA_MAX)
	sprint_exhausted = exhausted
	queue_redraw()

func _draw() -> void:
	if active:
		draw_arc(Vector2(0, 2), 24.0, 0.0, TAU, 32, Color(1.0, 0.82, 0.24, 0.92), 3.0)
		var marker := PackedVector2Array([
			Vector2(-5, -66),
			Vector2(5, -66),
			Vector2(0, -58),
		])
		draw_colored_polygon(marker, Color(1.0, 0.82, 0.24, 0.96))

