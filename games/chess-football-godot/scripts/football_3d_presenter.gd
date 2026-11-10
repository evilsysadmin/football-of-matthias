class_name ChessFootball3DPresenter
extends Node3D

const WORLD_SCALE := 0.014
const GOAL_POST_HEIGHT := 1.50
# Presentation-only grass runoff beyond the near sideline. The camera now
# includes this area during human throw-ins; keeping the same authored pitch
# shader avoids a dark foreground band with no new draw calls or hitboxes.
const NEAR_TURF_RUNOFF_DEPTH := 4.0
const CAMERA_LERP_SPEED := 3.25
# Ease the *depth and pitch only* back from the near-corner wide shot.
# Horizontal ball tracking keeps its usual pace to follow the cross.
const CAMERA_CORNER_RELEASE_SPEED := 1.80
const CAMERA_CORNER_RELEASE_DEPTH_EPSILON := 0.30
# During the live near-corner cross the goalmouth is near the right edge
# under the default horizontal cap. Give the camera a little more room to
# track that one short transition without altering ordinary broadcast play.
const BROADCAST_X_LIMIT_RATIO := 0.32
const CORNER_CROSS_X_LIMIT_RATIO := 0.39
const CAMERA_FOCUS_SMOOTH_SPEED := 2.65
const CAMERA_LEAD_SMOOTH_SPEED := 2.10
const CAMERA_FOCUS_DEAD_ZONE := 0.42
const SET_PIECE_CAMERA_PAN_SECONDS := 0.38
const SET_PIECE_CAMERA_PAN_DISTANCE := 1.15
# The far-touchline thrower/corner taker can end up under the 105-141px
# event chyron at 1280x720. Aim a little deeper into that far edge while
# the human decides the restart. Do not change the lens, world or hitboxes.
const BROADCAST_BASE_LOOK_Z := -0.85
const FAR_RESTART_LOOK_SHIFT := 2.35
# With broadcast's camera behind the near touchline, its thrower/receiver
# feet can fall below the viewport. The angle needs separate corner/throw-in
# tuning because goalmouth players sit much farther from the taker.
# Leave enough space below the near thrower for the larger selected-player
# ring, not just the feet. Calibrated against 1280x720 actual Godot PNGs.
const NEAR_RESTART_LOOK_SHIFT := 8.3
# Near corners span a long diagonal from the taker to the goalmouth.
# Retreat the same broadcast camera rather than widening its lens: both
# remain readable, with unaltered player scale rules and no cut-off taker.
const NEAR_CORNER_LOOK_SHIFT := 3.85
const NEAR_CORNER_CAMERA_RETREAT := 6.2
# When the near XI corner is framed, keep the end stand in the shot instead
# of parking the entire stadium to one side of a black canvas.
# This is a stage-space camera offset only: no effect on player positions.
const XI_NEAR_CORNER_STADIUM_PAN := 12.0
const BROADCAST_HEIGHT := 9.8
const BROADCAST_DEPTH := 17.8
# XI broadcast is a playable close-follow camera, not an entire-field aerial.
# The previous all-field 1.73/2.25 / 45.5-degree framing made 22 sprites tiny.
# V remains the full-pitch tactical overview; no atlas/physics scaling changes.
const XI_BROADCAST_HEIGHT_SCALE := 1.44
const XI_BROADCAST_DEPTH_SCALE := 1.70
const XI_BROADCAST_FOV := 41.0
# Extra horizontal room on wider screens allows a slightly closer XI lens.
# Keep 16:9 unchanged and retain the safe wide lens for restarts/corner release.
const XI_BROADCAST_WIDE_FOV := 37.5
const XI_BROADCAST_WIDE_ASPECT := 2.10
# During central open play, trade a little empty foreground for larger actors.
# Move back to the proven safe lens before reaching either touchline.
const XI_BROADCAST_CENTER_ZOOM_DEGREES := 3.5
const XI_BROADCAST_FOCUS_LANE_START := 0.36
const XI_BROADCAST_FOCUS_LANE_END := 0.80
# Keep the actual XI goal visible without pushing most of the stadium off
# the opposite edge during a penalty. Mirror for both attacking teams.
const XI_PENALTY_STADIUM_PAN := 11.5
# Dedicated behind-the-kicker 3/4 composition, restricted to a live XI
# penalty. Stage-space only: the simulation still owns every ball/keeper.
const XI_PENALTY_CAMERA_BEHIND := 7.4
const XI_PENALTY_CAMERA_HEIGHT := 8.4
const XI_PENALTY_CAMERA_NEAR_Z := 13.4
const XI_PENALTY_CAMERA_FOV := 38.0
const XI_PENALTY_CAMERA_BLEND_SPEED := 4.5
const XI_BROADCAST_X_LIMIT_RATIO := 0.43
const XI_BROADCAST_VERTICAL_FOLLOW := 0.31
const XI_BROADCAST_VERTICAL_FOLLOW_MIN := -5.2
const XI_BROADCAST_VERTICAL_FOLLOW_MAX := 6.3
# During open play the broadcast near touchline must stay inside the screen
# when the live ball or the selected human enters its final 28% of the pitch.
# Measured from the ACTUAL projected white line, not an arbitrary camera pan.
const XI_BROADCAST_NEAR_GUARD_START := 0.72
const XI_BROADCAST_NEAR_GUARD_FULL := 0.87
const XI_BROADCAST_NEAR_LINE_MARGIN_PX := 48.0
const TACTICAL_HEIGHT := 27.0
const PLAYER_PIXEL_SIZE := 0.0124
const TACTICAL_PLAYER_PIXEL_SIZE := 0.0162
const PLAYER_BASE_Y := 0.76
# The approved front/back atlas bodies are about 120px tall. Normalize the
# approved side run to the same perceived height without changing PNG bytes.
const CANONICAL_BODY_HEIGHT_PIXELS := 120.0
# Perspective makes identical world-sized billboards look bigger near the
# camera and smaller far away. Compensate their *projected* size only.
# Keep gameplay coordinates, canonical atlas bytes and shadows unchanged.
const MIN_PERSPECTIVE_BODY_SCALE := 0.45
const MAX_PERSPECTIVE_BODY_SCALE := 1.80
# Diagonal artwork has broader shoulders but comparable body height.
# The canonical scale already equalizes each view to 120px; a second vertical
# multiplier made *every* diagonal smaller than front/back and side.
# Correct the width only. Do not modify any approved PNG.
const DIAGONAL_WIDTH_COMPENSATION := 0.91
# The lateral ball carrier uses an 8-frame carry atlas, while diagonal
# running uses V3's 12-pose atlas. The older view correction (0.91) and
# V3 trim stack: the former 0.86 left XI diagonals only 78% of their
# authored width, making them look undersized beside the same-depth side
# carrier. Ease ONLY the extra V3 trim to 0.92 (net 0.8372), preserving
# slight torso perspective without changing height, foot anchor, atlas,
# keepers, fallback V2, legacy 5v5 or match physics.
const XI_V3_DIAGONAL_WIDTH_TRIM := 0.92
const PLAYER_RUN_BOB := 0.050
const PLAYER_SPRINT_BOB := 0.072
# The approved keeper frames do move, but many poses are only a few pixels
# apart at broadcast zoom. Make the real stride readable using a modest
# diegetic lean/sway/weight transfer; do not change canonical raster anatomy.
const KEEPER_STRIDE_EXTRA_SWAY := 0.095
const KEEPER_STRIDE_EXTRA_BOB := 0.035
const KEEPER_STRIDE_EXTRA_LEAN_DEGREES := 13.0
# XI penalty keeper: only a visual ready posture, never a new save radius.
# Ease it out when the shot leaves the foot, so the 3/4 camera never pops.
const XI_PENALTY_KEEPER_GUARD_BLEND_SPEED := 4.0
const XI_PENALTY_KEEPER_GUARD_WIDTH := 1.06
const XI_PENALTY_KEEPER_GUARD_HEIGHT := 0.94
const XI_PENALTY_KEEPER_GUARD_LEAN_DEGREES := 5.0
const STAMINA_BAR_WIDTH := 0.76
const STAMINA_BAR_DEPTH := 0.10
const STAMINA_BAR_Z := 0.62
# Keeper-only visual grip. No changes to ball authority/collision.
# Secure at chest level; previous hip-height hold made the keeper look
# as though he was carrying a loose ball in front of the shorts.
const KEEPER_CATCH_HEIGHT := 1.25
const KEEPER_CATCH_FRONT := 0.48
const KEEPER_CATCH_SIDE := 0.12
# The gloves first reach wide, then cup the ball during the existing catch blend.
# No visual catch may start more than an arm's reach from the keeper.
const KEEPER_CATCH_START_REACH := 0.32
const KEEPER_CATCH_OPEN_HAND_SPAN := 0.29
const KEEPER_CATCH_CLOSED_HAND_SPAN := 0.188
const KEEPER_CATCH_BLEND_SECONDS := 0.18
# R2 goalkeepers should finish the real save/dive before their catch sheet
# starts. This is only the visual offset of the already-captured ball.
const XI_KEEPER_SAVE_BALL_REACH := 0.20
# Keep the established visual spin rate, but roll around the axis
# perpendicular to the ball's actual 2D travel on the X/Z pitch plane.
# This changes no movement, velocity, 2D authority, collisions or ball art.
const BALL_VISUAL_SPIN_PER_PIXEL := 0.004
# XI only: presentation-space calibration, never the 2D collision radius.
const XI_BALL_VISUAL_RADIUS := 0.12
const LEGACY_BALL_VISUAL_RADIUS := 0.16
const BALL_VISUAL_GROUND_CLEARANCE := 0.02

var match_node: Node
var camera: Camera3D
var player_nodes: Dictionary = {}
var player_sprites: Dictionary = {}
# 11v11-only QuadMesh bodies fed by the canonical AnimatedSprite3D frames.
# Legacy 5v5 continues to render AnimatedSprite3D directly.
var xi_raster_meshes: Dictionary = {}
# Temporary XI fallback until exact optional WebP sheets verify.
var xi_actor_models: Dictionary = {}
# All XI athletes (including when optional R2 is unavailable) must use
# their canonical local raster. No geometric proxy on the playing field.
var player_run_views: Dictionary = {}
# Keeper run/action poses tick independently in the visible 3D runtime.
# Hidden authoritative 2D AnimatedSprite2D nodes are not a reliable clock.
var keeper_visual_phases: Dictionary = {}
var keeper_visual_names: Dictionary = {}
var penalty_keeper_guard_blends: Dictionary = {}
# Outfield actors also need a visible 3D clock. The hidden 2D sprites can
# remain on a stale frame in the Web runtime while match physics continues.
var outfield_visual_phases: Dictionary = {}
var outfield_visual_names: Dictionary = {}
var body_scale_cache: Dictionary = {}
# Lighting is already disabled for billboards. The remaining brightness jump
# comes from shadows baked differently into the authored view families.
var tone_gain_cache: Dictionary = {}
var ball_node: MeshInstance3D
var ball_shadow: MeshInstance3D
var keeper_catch_rigs: Dictionary = {}
# A keeper switches only after all eight verified CDN frames arrive.
var _keeper_catch_r2_loaded: Dictionary = {}
# A successful R2 idle replacement is atomic for its entire actor family.
# Legacy one-frame front responses must not overwrite animated frame zero.
var _animated_idle_r2_loaded: Dictionary = {}
# v2 run replaces only outfield locomotion after every pose verifies.
var _run_v2_r2_loaded: Dictionary = {}
# V3 supersedes V2 only after its entire 12x5 sheet verifies for each club.
var _run_v3_r2_loaded: Dictionary = {}
# Authored action replacement becomes active per-club only after full verification.
var _pass_shoot_r2_loaded: Dictionary = {}
# Verified side-view carrier animations. Never alter the 2D ball or physics.
var _carry_dribble_r2_loaded: Dictionary = {}
# Independent v2 action sheet state: one verified replacement per club/action.
var _action_poses_r2_loaded: Dictionary = {}
var _contact_shadow_material: ShaderMaterial
var keeper_catch_carrier_id: int = 0
var keeper_catch_origin: Vector3 = Vector3.ZERO
var keeper_catch_elapsed: float = 0.0
var penalty_aim_marker: MeshInstance3D
var field_width: float
var field_depth: float
var smoothed_focus_x: float = 0.0
var smoothed_lead_x: float = 0.0
var smoothed_restart_look_z: float = BROADCAST_BASE_LOOK_Z
var last_camera_mode: String = "broadcast"
# Keep the aerial-to-broadcast transition distinct from a genuine corner
# recovery until the interpolating camera has cleared its aerial depth.
var xi_returning_from_tactical: bool = false
var penalty_camera_mix: float = 0.0
var penalty_camera_position: Vector3 = Vector3.ZERO
var penalty_camera_target: Vector3 = Vector3.ZERO
# Keep the static sponsor signs as the source of truth outside a real goal.
var ad_default_messages: Array[String] = []
var ad_default_accents: Array[Color] = []
var ad_last_goal_team: int = -1

func _request_animated_idle_from_r2() -> void:
	if not OS.has_feature("web"):
		return
	# Exactly three requests per presenter, never one request per footballer.
	for kind in ChessFootballIdleR2.KINDS:
		var meta := ChessFootballIdleR2.sheet_meta(kind)
		if meta.is_empty():
			continue
		var loader := ChessFootballR2AtlasLoader.new()
		loader.name = "AnimatedIdleR2_" + kind
		add_child(loader)
		loader.atlas_ready.connect(_on_animated_idle_ready.bind(kind))
		loader.start(meta, ChessFootballIdleR2.TRUSTED_ROOT)


func _on_animated_idle_ready(image: Image, kind: String) -> void:
	var textures := ChessFootballIdleR2.frames_from_image(image, kind)
	if textures.size() != ChessFootballIdleR2.FRAME_COUNT * ChessFootballIdleR2.ROW_COUNT:
		return
	var away_keeper_textures: Array[Texture2D] = []
	if kind == "keeper":
		away_keeper_textures = ChessFootballIdleR2.frames_from_image(image, kind, true)
		if away_keeper_textures.size() != textures.size():
			return
	_apply_animated_idle_frames(kind, textures, away_keeper_textures)
	# Keepers have no v2 run sheet: a verified 5-view keeper idle sheet
	# already supplies a valid raster body and can replace the fallback sculpt.
	if kind == "keeper" and _animated_idle_r2_loaded.has("keeper"):
		for team in match_node.teams:
			for player in team:
				if player.role != "keeper":
					continue
				var key: int = player.get_instance_id()
				var model_proxy := xi_actor_models.get(key) as Node3D
				var raster := xi_raster_meshes.get(key) as MeshInstance3D
				if model_proxy != null and raster != null:
					model_proxy.hide()
					raster.show()


func _apply_animated_idle_frames(
	kind: String, textures: Array[Texture2D], away_keeper_textures: Array[Texture2D]
) -> void:
	if kind not in ChessFootballIdleR2.KINDS:
		return
	if textures.size() != ChessFootballIdleR2.FRAME_COUNT * ChessFootballIdleR2.ROW_COUNT:
		return
	if kind == "keeper" and away_keeper_textures.size() != textures.size():
		return
	var targets: Array[AnimatedSprite3D] = []
	var teams: Array[int] = []
	for team in match_node.teams:
		for player in team:
			var player_kind := "keeper" if player.role == "keeper" else (
				"fc_matthias" if player.team_id == 0 else "real_enroque"
			)
			if player_kind != kind:
				continue
			var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
			if sprite == null:
				return
			var bank := sprite.sprite_frames
			for anim in ChessFootballIdleR2.IDLE_ANIMATIONS:
				var name := StringName(anim)
				if not bank.has_animation(name) or bank.get_frame_count(name) not in [1, 8]:
					return
			targets.append(sprite)
			teams.append(int(player.team_id))
	if targets.is_empty():
		return
	for index in range(targets.size()):
		var bank := targets[index].sprite_frames
		var chosen: Array[Texture2D] = (
			away_keeper_textures if kind == "keeper" and teams[index] == 1 else textures
		)
		for row in range(ChessFootballIdleR2.IDLE_ANIMATIONS.size()):
			var name := StringName(ChessFootballIdleR2.IDLE_ANIMATIONS[row])
			bank.clear(name)
			bank.set_animation_speed(name, 7.0)
			bank.set_animation_loop(name, true)
			for frame_id in range(ChessFootballIdleR2.FRAME_COUNT):
				bank.add_frame(name, chosen[row * ChessFootballIdleR2.FRAME_COUNT + frame_id])
	_animated_idle_r2_loaded[kind] = true
	# The 8-frame breathing silhouettes replace the previous idle source.
	# Discard only derived display-size references, never actor/game state.
	body_scale_cache.clear()
	tone_gain_cache.clear()


func _request_idle_front_from_r2() -> void:
	# Legacy shared-CDN still appears in optional metadata for offline
	# compatibility tests, but it is not a live dependency: the approved
	# local idle frame and independently verified animated-idle R2 suffice.
	# Never issue the old DNS request when disabled, even in Web CI.
	if not OS.has_feature("web"):
		return
	var meta: Dictionary = ChessFootballSpriteBank.optional_idle_meta()
	if meta.get("enabled") != true:
		return
	var loader := ChessFootballR2AtlasLoader.new()
	loader.name = "OptionalIdleFrontR2"
	add_child(loader)
	loader.atlas_ready.connect(_on_idle_front_atlas_ready)
	loader.start(meta)


func _on_idle_front_atlas_ready(image: Image) -> void:
	var textures := ChessFootballSpriteBank.idle_front_textures_from_image(image)
	if textures.size() == 4:
		_apply_idle_front_textures(textures)


func _apply_idle_front_textures(textures: Array[Texture2D]) -> void:
	# The third sheet cell is the yellow keeper; the fourth texture is the
	# derived teal away variant. Neither alters the canonical move frames.
	if textures.size() != 4:
		return
	for team in match_node.teams:
		for player in team:
			var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
			if sprite == null:
				continue
			var frames := sprite.sprite_frames
			if not frames.has_animation(&"idle_front"):
				continue
			var player_kind := "keeper" if player.role == "keeper" else (
				"fc_matthias" if player.team_id == 0 else "real_enroque"
			)
			if bool(_animated_idle_r2_loaded.get(player_kind, false)):
				continue
			var index: int = 2 + int(player.team_id) if player.role == "keeper" else int(player.team_id)
			frames.set_frame(&"idle_front", 0, textures[index])
	# A late successful optional sheet invalidates any cached tonal correction.
	tone_gain_cache.clear()


# Staged activation: metadata remains disabled until Infra has publicly
# accredited both R2 sheets and exact byte/CORS parity.
# Both user-uploaded 12-pose atlases have fixed URLs, checksums and dimensions.
# V2 remains active if the v3 HTTP request, SHA/CORS or frame check fails.
func _request_run_v3_from_r2() -> void:
	if not OS.has_feature("web") or match_node.match_team_size != 11:
		return
	for team_id in range(2):
		var meta := ChessFootballRunV3R2.sheet_meta(team_id)
		if meta.is_empty():
			continue
		var loader := ChessFootballR2AtlasLoader.new()
		loader.name = "RunV3R2_%d" % team_id
		add_child(loader)
		loader.atlas_ready.connect(_on_run_v3_ready.bind(team_id))
		loader.start(meta, ChessFootballRunV3R2.TRUSTED_ROOT)


func _on_run_v3_ready(image: Image, team_id: int) -> void:
	_apply_verified_run_v3(ChessFootballRunV3R2.frames_from_image(image), team_id)


func _apply_verified_run_v3(textures: Array[Texture2D], team_id: int) -> void:
	if team_id not in [0, 1] or _run_v3_r2_loaded.has(team_id):
		return
	if textures.size() != ChessFootballRunV3R2.ROWS * ChessFootballRunV3R2.COLUMNS:
		return
	var targets: Array[AnimatedSprite3D] = []
	# Validate all actors and both animation families BEFORE mutating any.
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
		if sprite == null or sprite.sprite_frames == null:
			return
		for row_name in ChessFootballRunV3R2.ANIMATIONS:
			for base in ["run", "sprint"]:
				var animation := StringName(row_name.replace("run", base))
				if not sprite.sprite_frames.has_animation(animation):
					return
				if sprite.sprite_frames.get_frame_count(animation) != ChessFootballRunV2R2.COLUMNS:
					return
		targets.append(sprite)
	if targets.size() != match_node.match_team_size - 1:
		return
	for sprite in targets:
		var frames := sprite.sprite_frames
		for row in range(ChessFootballRunV3R2.ROWS):
			for base in ["run", "sprint"]:
				var name := StringName(ChessFootballRunV3R2.ANIMATIONS[row].replace("run", base))
				var previous_fps := frames.get_animation_speed(name)
				frames.clear(name)
				frames.set_animation_speed(name,
					previous_fps * float(ChessFootballRunV3R2.COLUMNS) / float(ChessFootballRunV2R2.COLUMNS))
				for i in range(ChessFootballRunV3R2.COLUMNS):
					frames.add_frame(name, textures[row * ChessFootballRunV3R2.COLUMNS + i])
		# Preserve the physical gait position when changing the number of
		# poses mid-run. Never restart from frame zero on an async CDN arrival.
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var key: int = player.get_instance_id()
		var driver := player_sprites[key] as AnimatedSprite3D
		if _keeper_locomotion(driver.animation):
			var old_phase: float = float(outfield_visual_phases.get(key, float(driver.frame)))
			var new_phase: float = fposmod(old_phase * float(ChessFootballRunV3R2.COLUMNS) /
				float(ChessFootballRunV2R2.COLUMNS), float(ChessFootballRunV3R2.COLUMNS))
			outfield_visual_phases[key] = new_phase
			driver.frame = int(floorf(new_phase))
		var sculpt := xi_actor_models.get(key) as Node3D
		var quad := xi_raster_meshes.get(key) as MeshInstance3D
		if sculpt != null and quad != null:
			sculpt.hide()
			quad.show()
	_run_v3_r2_loaded[team_id] = true
	# Cached view-height normalization was sampled from the old eight poses.
	# Recompute on the v3 silhouettes or players visibly shrink/grow on swap.
	body_scale_cache.clear()
	tone_gain_cache.clear()


func _request_run_v2_from_r2() -> void:
	if not OS.has_feature("web"):
		return
	# One download per team, NOT per outfield player.
	for team_id in range(2):
		var meta := ChessFootballRunV2R2.sheet_meta(team_id)
		if meta.is_empty():
			continue
		var loader := ChessFootballR2AtlasLoader.new()
		loader.name = "RunV2R2_%d" % team_id
		add_child(loader)
		loader.atlas_ready.connect(_on_run_v2_ready.bind(team_id))
		loader.start(meta, ChessFootballRunV2R2.TRUSTED_ROOT)


func _on_run_v2_ready(image: Image, team_id: int) -> void:
	_apply_verified_run_v2(ChessFootballRunV2R2.frames_from_image(image), team_id)


func _apply_verified_run_v2(textures: Array[Texture2D], team_id: int) -> void:
	if _run_v3_r2_loaded.has(team_id):
		return
	if team_id not in [0, 1] or textures.size() != ChessFootballRunV2R2.COLUMNS * ChessFootballRunV2R2.ROWS:
		return
	var targets: Array[SpriteFrames] = []
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
		if sprite == null:
			return
		var frames := sprite.sprite_frames
		for base in ["run", "sprint"]:
			for named in ChessFootballRunV2R2.ANIMATIONS:
				var anim := StringName(named.replace("run", base))
				if not frames.has_animation(anim) or frames.get_frame_count(anim) != 8:
					return
		targets.append(frames)
	if targets.is_empty():
		return
	# All-or-nothing change for this club's outfield animations only.
	# Idle, tackles, passes, shots, goalkeepers and the 2D match authority
	# retain their existing assets and phase clocks.
	for frames in targets:
		for row in range(ChessFootballRunV2R2.ROWS):
			for base in ["run", "sprint"]:
				var anim := StringName(ChessFootballRunV2R2.ANIMATIONS[row].replace("run", base))
				for frame_id in range(ChessFootballRunV2R2.COLUMNS):
					frames.set_frame(anim, frame_id, textures[row * ChessFootballRunV2R2.COLUMNS + frame_id])
	_run_v2_r2_loaded[team_id] = true
	# Running silhouettes have changed: a cached scale from the bundled
	# atlas would make otherwise identical XI actors visibly different sizes
	# after the asynchronous WebP replacement. This does not touch physics.
	body_scale_cache.clear()
	# On verified success, switch the entire club from its provisional
	# no-duplicate model to the real 8-frame raster in one visual update.
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var key: int = player.get_instance_id()
		var model_proxy := xi_actor_models.get(key) as Node3D
		var raster := xi_raster_meshes.get(key) as MeshInstance3D
		if model_proxy != null and raster != null:
			model_proxy.hide()
			raster.show()
	tone_gain_cache.clear()


func _request_lateral_run_from_r2() -> void:
	if not OS.has_feature("web"):
		return
	for team_id in range(2):
		var meta := ChessFootballSpriteBank.lateral_run_meta(team_id)
		if meta.is_empty():
			continue
		var loader := ChessFootballR2AtlasLoader.new()
		loader.name = "OptionalLateralRun_%d" % team_id
		add_child(loader)
		loader.atlas_ready.connect(_on_lateral_run_atlas_ready.bind(team_id))
		loader.start(meta)


func _on_lateral_run_atlas_ready(image: Image, team_id: int) -> void:
	var textures := ChessFootballSpriteBank.validated_lateral_run_frames(image, team_id)
	_apply_verified_lateral_run(textures, team_id)


func _apply_verified_lateral_run(textures: Array[Texture2D], team_id: int) -> void:
	# An older v1 request may complete after the v2 atlas. It must not
	# overwrite the newly validated running frames.
	if _run_v2_r2_loaded.has(team_id) or _run_v3_r2_loaded.has(team_id):
		return
	# Keep all original run phases, FPS, action indices and facing animations;
	# switching only the eight side frames cannot change game simulation.
	if textures.size() != 8 or team_id not in [0, 1]:
		return
	var names := [&"idle", &"run", &"sprint", &"pass", &"shoot", &"tackle", &"celebrate"]
	var targets: Array[SpriteFrames] = []
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
		if sprite == null:
			return
		var frames := sprite.sprite_frames
		for animation in names:
			if not frames.has_animation(animation):
				return
			var expected := 1 if animation == &"idle" else 8
			if frames.get_frame_count(animation) != expected:
				return
		targets.append(frames)
	for frames in targets:
		frames.set_frame(&"idle", 0, textures[0])
		for animation in names:
			if animation == &"idle":
				continue
			if animation == &"tackle" and (
				_tackle_r2_loaded.has("%d:tackle" % team_id)
				or _action_poses_r2_loaded.has("%d:tackle" % team_id)
			):
				continue
			if animation in [&"pass", &"shoot"] and _pass_shoot_r2_loaded.has(team_id):
				continue
			var poses: Array = ChessFootballSpriteBank.CANONICAL_ACTION_POSES.get(String(animation), [])
			for index in range(8):
				var source := index if animation in [&"run", &"sprint"] else int(poses[index])
				frames.set_frame(animation, index, textures[source])
	# Recalculate the side/idle body-height reference on an atomic atlas swap.
	# Keeping the previous reference would cause scale jumps as players turn.
	body_scale_cache.clear()
	tone_gain_cache.clear()


# A single verified 2x8 sheet supplies both actions for one club.
# Never request one image per footballer and never touch match authority.
func _request_pass_shoot_from_r2() -> void:
	if not OS.has_feature("web"):
		return
	for team_id in range(2):
		var meta := ChessFootballPassShootR2.sheet_meta(team_id)
		if meta.is_empty():
			continue
		var loader := ChessFootballR2AtlasLoader.new()
		loader.name = "OptionalPassShootR2_%d" % team_id
		add_child(loader)
		loader.atlas_ready.connect(_on_pass_shoot_ready.bind(team_id))
		loader.start(meta, ChessFootballPassShootR2.TRUSTED_ROOT)


func _on_pass_shoot_ready(image: Image, team_id: int) -> void:
	_apply_verified_pass_shoot_frames(ChessFootballPassShootR2.frames_from_image(image), team_id)


func _apply_verified_pass_shoot_frames(textures: Array[Texture2D], team_id: int) -> void:
	if team_id not in [0, 1] or textures.size() != 16:
		return
	var targets: Array[SpriteFrames] = []
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
		if sprite == null:
			return
		var frames := sprite.sprite_frames
		for animation in ChessFootballPassShootR2.ANIMATIONS:
			if not frames.has_animation(animation) or frames.get_frame_count(animation) != 8:
				return
		targets.append(frames)
	if targets.is_empty():
		return
	for frames in targets:
		for row in range(ChessFootballPassShootR2.ROWS):
			var animation: StringName = ChessFootballPassShootR2.ANIMATIONS[row]
			for index in range(ChessFootballPassShootR2.COLUMNS):
				frames.set_frame(animation, index, textures[row * 8 + index])
	_pass_shoot_r2_loaded[team_id] = true
	tone_gain_cache.clear()


# Download at most one carry/dribble atlas per club, never one per actor.
# The candidate contract stays disabled until public R2/CORS/SHA approval.
func _request_carry_dribble_from_r2() -> void:
	if not OS.has_feature("web"):
		return
	for team_id in range(2):
		var meta := ChessFootballCarryDribbleR2.sheet_meta(team_id)
		if meta.is_empty():
			continue
		var loader := ChessFootballR2AtlasLoader.new()
		loader.name = "OptionalCarryDribbleR2_%d" % team_id
		add_child(loader)
		loader.atlas_ready.connect(_on_carry_dribble_ready.bind(team_id))
		loader.start(meta, ChessFootballCarryDribbleR2.TRUSTED_ROOT)


func _on_carry_dribble_ready(image: Image, team_id: int) -> void:
	_apply_verified_carry_dribble_frames(
		ChessFootballCarryDribbleR2.frames_from_image(image), team_id
	)


func _apply_verified_carry_dribble_frames(textures: Array[Texture2D], team_id: int) -> void:
	if team_id not in [0, 1] or textures.size() != 16:
		return
	var targets: Array[SpriteFrames] = []
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
		if sprite == null:
			return
		var frames := sprite.sprite_frames
		for animation in ChessFootballCarryDribbleR2.ANIMATIONS:
			if frames.has_animation(animation):
				return
		targets.append(frames)
	if targets.is_empty():
		return
	# All 10 outfield SpriteFrames receive all 16 verified poses or none.
	for frames in targets:
		for row in range(ChessFootballCarryDribbleR2.ROWS):
			var name: StringName = ChessFootballCarryDribbleR2.ANIMATIONS[row]
			frames.add_animation(name)
			frames.set_animation_speed(name, 12.0 if row == 0 else 36.0)
			frames.set_animation_loop(name, row == 0)
			for frame_id in range(ChessFootballCarryDribbleR2.COLUMNS):
				frames.add_frame(name, textures[row * 8 + frame_id])
	_carry_dribble_r2_loaded[team_id] = true
	# Carrier source art has its OWN silhouette envelope, independent of v3
	# side running. Clear any cached reference from before the async swap.
	body_scale_cache.clear()
	tone_gain_cache.clear()


# Native R2 v2 eight-pose action pack, independent of the legacy source-
# sized tackler decoder. A failed fetch/shape/hash leaves local canon intact.
func _request_action_poses_from_r2() -> void:
	# Old 5v5 remains the canon-only headless fixture.
	if not OS.has_feature("web") or match_node.match_team_size != 11:
		return
	for team_id in range(2):
		for action in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
			var meta := ChessFootballActionPosesR2.sheet_meta(team_id, action)
			if meta.is_empty():
				continue
			var loader := ChessFootballR2AtlasLoader.new()
			loader.name = "ActionPosesV2_%d_%s" % [team_id, String(action)]
			add_child(loader)
			loader.atlas_ready.connect(_on_action_pose_ready.bind(team_id, action))
			loader.start(meta, ChessFootballActionPosesR2.TRUSTED_ROOT)


func _on_action_pose_ready(image: Image, team_id: int, action: StringName) -> void:
	_apply_verified_action_pose_frames(
		ChessFootballActionPosesR2.frames_from_image(image, action), team_id, action
	)


func _apply_verified_action_pose_frames(
	textures: Array[Texture2D], team_id: int, action: StringName
) -> void:
	if team_id not in [0, 1] or action not in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
		return
	if textures.size() != ChessFootballActionPosesR2.COLUMNS:
		return
	var key := "%d:%s" % [team_id, String(action)]
	if _action_poses_r2_loaded.has(key):
		return
	var targets: Array[SpriteFrames] = []
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
		if sprite == null or sprite.sprite_frames == null:
			return
		var bank := sprite.sprite_frames
		if action in [&"tackle", &"slide_tackle"]:
			if not bank.has_animation(action) or bank.get_frame_count(action) != 8:
				return
		elif bank.has_animation(action):
			return
		targets.append(bank)
	if targets.size() != match_node.match_team_size - 1:
		return
	for bank in targets:
		if action in [&"dribble_cut", &"dribble_burst"]:
			bank.add_animation(action)
			bank.set_animation_speed(action, 36.0 if action == &"dribble_cut" else 30.0)
			bank.set_animation_loop(action, false)
		for i in range(ChessFootballActionPosesR2.COLUMNS):
			if action in [&"tackle", &"slide_tackle"]:
				bank.set_frame(action, i, textures[i])
			else:
				bank.add_frame(action, textures[i])
	_action_poses_r2_loaded[key] = true
	# Local, opt-in player-facing diagnostics. Report only the exact set of
	# verified R2 sheets installed in SpriteFrames, not network attempts,
	# gameplay, user identity or telemetry. Only the authenticated staging
	# parent may receive this read-only state; never broadcast to *.
	if match_node.match_team_size == 11 and OS.has_feature("web"):
		var installed: Array[String] = []
		for club_id in range(ChessFootballActionPosesR2.CLUBS.size()):
			for pose in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
				var pose_key := "%d:%s" % [club_id, String(pose)]
				if _action_poses_r2_loaded.has(pose_key):
					installed.append(pose_key)
		var receipt: String = JSON.stringify({
			"source": "chess-football-godot",
			"type": "action-poses-status",
			"team_size": 11,
			"expected": 8,
			"installed": installed,
		})
		JavaScriptBridge.eval(
			"if (location.hostname === 'assets.chess-studio.shadowops.dpdns.org' && document.referrer.startsWith('https://staging.football.shadowops.dpdns.org/')) window.parent.postMessage(%s, 'https://staging.football.shadowops.dpdns.org');" % receipt,
			true
		)
	# Explicit CI-only proof from the ACTUAL browser renderer: all four
	# SHA-verified action sheets were installed for both teams, not merely
	# fetched successfully or rendered in native/headless Godot tests.
	# No user telemetry or public probe flag is introduced.
	if match_node.match_team_size == 11 and OS.has_feature("web"):
		var expected_sheets := (
			ChessFootballActionPosesR2.CLUBS.size()
			* ChessFootballActionPosesR2.ACTIVE_ANIMATIONS.size()
		)
		if _action_poses_r2_loaded.size() == expected_sheets:
			var every_sheet_installed := true
			for club_id in range(ChessFootballActionPosesR2.CLUBS.size()):
				for approved_action in ChessFootballActionPosesR2.ACTIVE_ANIMATIONS:
					if not _action_poses_r2_loaded.has(
						"%d:%s" % [club_id, String(approved_action)]
					):
						every_sheet_installed = false
			if every_sheet_installed:
				JavaScriptBridge.eval(
					"if (location.hostname === '127.0.0.1' && window.__chessFootballInputProbe === true) window.parent.postMessage({source:'chess-football-godot', type:'ci-action-poses-installed', team_size:11, sheets:8}, '*');",
					true
				)
	# The new artist poses have their own stable silhouette geometry; clear
	# only derived presenter measurements, not sprite/physics action clocks.
	body_scale_cache.clear()
	tone_gain_cache.clear()


# Four source-sized R2 sheets: standing tackle and slide tackle for each
# club. They are opt-in until the public endpoint, CORS and bytes are proven.
var _tackle_r2_loaded: Dictionary = {}


func _request_tackle_atlases_from_r2() -> void:
	if not OS.has_feature("web"):
		return
	for team_id in range(2):
		for animation in [&"tackle", &"slide_tackle"]:
			var meta := ChessFootballTackleR2.active_entry(team_id, animation)
			if meta.is_empty():
				continue
			var loader := ChessFootballR2AtlasLoader.new()
			loader.name = "OptionalTackle_%d_%s" % [team_id, String(animation)]
			add_child(loader)
			loader.atlas_ready.connect(_on_tackle_atlas_ready.bind(team_id, animation))
			loader.start(meta)


func _on_tackle_atlas_ready(image: Image, team_id: int, animation: StringName) -> void:
	var source := ChessFootballTackleR2.source_entry(team_id, animation)
	var textures := ChessFootballTackleR2.frames_from_image(image, source)
	_apply_verified_tackle_frames(textures, team_id, animation)


func _apply_verified_tackle_frames(
	textures: Array[Texture2D], team_id: int, animation: StringName
) -> void:
	if _action_poses_r2_loaded.has("%d:%s" % [team_id, String(animation)]):
		return
	if textures.size() != 8 or team_id not in [0, 1] or animation not in [&"tackle", &"slide_tackle"]:
		return
	var targets: Array[SpriteFrames] = []
	for player in match_node.teams[team_id]:
		if player.role == "keeper":
			continue
		var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
		if sprite == null or not sprite.sprite_frames.has_animation(animation):
			return
		var bank := sprite.sprite_frames
		if bank.get_frame_count(animation) != 8:
			return
		targets.append(bank)
	for bank in targets:
		for index in range(8):
			bank.set_frame(animation, index, textures[index])
	_tackle_r2_loaded["%d:%s" % [team_id, String(animation)]] = true
	# Invalidate only derived tonal calculations. Do not reset running
	# phases, action animation time, kick/slide collision or match score.
	tone_gain_cache.clear()



# Reception-only sheets never touch canonical run/tackle or keeper physics.
# Bad bytes, wrong poses or failed HTTP leave the old glove rig available.
func _request_keeper_catch_atlases_from_r2() -> void:
	if not OS.has_feature("web"):
		return
	for team_id in range(2):
		var meta := ChessFootballKeeperCatchR2.active_entry(team_id)
		if meta.is_empty():
			continue
		var loader := ChessFootballR2AtlasLoader.new()
		loader.name = "OptionalKeeperCatch_%d" % team_id
		add_child(loader)
		loader.atlas_ready.connect(_on_keeper_catch_atlas_ready.bind(team_id))
		# Pin only the receiving keeper to its independently owned R2 origin.
		# Every other atlas still uses the legacy shared CDN allowlist.
		loader.start(meta, ChessFootballKeeperCatchR2.public_root())


func _on_keeper_catch_atlas_ready(image: Image, team_id: int) -> void:
	var textures := ChessFootballKeeperCatchR2.frames_from_image(
		image, ChessFootballKeeperCatchR2.source_entry(team_id)
	)
	_apply_verified_keeper_catch_frames(textures, team_id)


func _apply_verified_keeper_catch_frames(textures: Array[Texture2D], team_id: int) -> void:
	if team_id not in [0, 1] or textures.size() != 8:
		return
	var targets: Array[AnimatedSprite3D] = []
	for player in match_node.teams[team_id]:
		if player.role != "keeper":
			continue
		var sprite := player_sprites.get(player.get_instance_id()) as AnimatedSprite3D
		if sprite == null or sprite.sprite_frames.has_animation(&"keeper_catch"):
			return
		targets.append(sprite)
	if targets.is_empty():
		return
	for sprite in targets:
		var bank := sprite.sprite_frames
		bank.add_animation(&"keeper_catch")
		bank.set_animation_speed(&"keeper_catch", 12.0)
		bank.set_animation_loop(&"keeper_catch", false)
		for texture in textures:
			bank.add_frame(&"keeper_catch", texture)
	_keeper_catch_r2_loaded[team_id] = true
	tone_gain_cache.clear()


func setup(p_match: Node) -> void:
	match_node = p_match
	var pitch: Rect2 = match_node.match_pitch
	field_width = pitch.size.x * WORLD_SCALE
	field_depth = pitch.size.y * WORLD_SCALE
	_build_environment()
	_build_pitch()
	_build_goals()
	_build_player_proxies()
	_build_ball()
	_build_camera()
	sync_presentation(1.0, "broadcast")
	# Render approved XI atlases as real textured 3D meshes.
	_build_xi_quad_bodies()
	_request_idle_front_from_r2()
	_request_animated_idle_from_r2()
	_request_lateral_run_from_r2()
	_request_run_v2_from_r2()
	_request_run_v3_from_r2()
	_request_pass_shoot_from_r2()
	_request_carry_dribble_from_r2()
	_request_tackle_atlases_from_r2()
	_request_action_poses_from_r2()
	_request_keeper_catch_atlases_from_r2()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.010, 0.018, 0.028)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.40, 0.49, 0.62)
	environment.ambient_light_energy = 0.82
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	key_light.light_color = Color(0.92, 0.95, 1.0)
	key_light.light_energy = 1.42
	key_light.shadow_enabled = true
	add_child(key_light)

	var warm_fill := DirectionalLight3D.new()
	warm_fill.rotation_degrees = Vector3(-42.0, 145.0, 0.0)
	warm_fill.light_color = Color(1.0, 0.76, 0.48)
	warm_fill.light_energy = 0.46
	warm_fill.shadow_enabled = false
	add_child(warm_fill)

func _material(color: Color, roughness: float = 0.84) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_pitch() -> void:
	_add_stadium_apron()
	# One shared shader gives every stripe continuous pitch-space variation,
	# without textures, extra geometry, or camera-dependent UV seams.
	var turf_shader := Shader.new()
	turf_shader.code = """
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 stripe_color : source_color;
varying vec2 turf_coordinate;

void vertex() {
	turf_coordinate = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Soft mowing grain, with a restrained cross-grain visible at match zoom.
	float broad = sin(turf_coordinate.x * 0.81 + turf_coordinate.y * 0.37)
		* sin(turf_coordinate.y * 0.91);
	float fiber = sin(turf_coordinate.x * 8.6 + turf_coordinate.y * 2.8)
		* sin(turf_coordinate.y * 7.4);
	float variation = 1.0 + 0.060 * broad + 0.014 * fiber;
	// Narrow, softened wear in the two goalmouths; never cover pitch lines.
	float wear = smoothstep(12.7, 16.7, abs(turf_coordinate.x))
		* (1.0 - smoothstep(0.9, 3.2, abs(turf_coordinate.y)));
	vec3 turf = stripe_color.rgb * variation;
	ALBEDO = mix(turf, turf * vec3(1.14, 0.89, 0.76), wear * 0.25);
	ROUGHNESS = 0.96;
}
"""
	var stripe_width := field_width / 16.0
	for i in range(16):
		var stripe := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		# Extend only towards the broadcast camera: far-sideline shape and
		# every stripe's X coordinate stay identical. No extra MeshInstance3Ds.
		mesh.size = Vector2(stripe_width + 0.01, field_depth + NEAR_TURF_RUNOFF_DEPTH)
		stripe.mesh = mesh
		stripe.position = Vector3(
			-field_width * 0.5 + stripe_width * (float(i) + 0.5),
			0.0,
			NEAR_TURF_RUNOFF_DEPTH * 0.5,
		)
		stripe.name = "TurfStripe_%02d" % i
		var turf_material := ShaderMaterial.new()
		turf_material.shader = turf_shader
		turf_material.set_shader_parameter(
			"stripe_color",
			Color(0.150, 0.299, 0.140) if i % 2 == 0 else Color(0.185, 0.347, 0.159),
		)
		stripe.material_override = turf_material
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stripe)

	var line_color := Color(0.95, 0.96, 0.91)
	_add_box(Vector3(0.0, 0.018, -field_depth * 0.5), Vector3(field_width, 0.025, 0.055), line_color)
	_add_box(Vector3(0.0, 0.018, field_depth * 0.5), Vector3(field_width, 0.025, 0.055), line_color)
	_add_box(Vector3(-field_width * 0.5, 0.018, 0.0), Vector3(0.055, 0.025, field_depth), line_color)
	_add_box(Vector3(field_width * 0.5, 0.018, 0.0), Vector3(0.055, 0.025, field_depth), line_color)
	_add_box(Vector3(0.0, 0.022, 0.0), Vector3(0.045, 0.03, field_depth), line_color)
	_add_penalty_box(false, line_color)
	_add_penalty_box(true, line_color)
	_add_goal_area_markings(false, line_color)
	_add_goal_area_markings(true, line_color)
	_add_center_circle(line_color)
	_add_corner_flags()

	var far_stand := MeshInstance3D.new()
	var far_mesh := BoxMesh.new()
	far_mesh.size = Vector3(field_width + 6.2, 2.15, 2.35)
	far_stand.mesh = far_mesh
	far_stand.position = Vector3(0.0, 1.02, -field_depth * 0.5 - 3.05)
	far_stand.material_override = _material(Color(0.024, 0.033, 0.046), 0.96)
	add_child(far_stand)

	# Separate riser faces from their tread edges. Both remain static and
	# behind the LED hoardings/crowd; only the visible five levels get detail.
	for row in range(5):
		var step := MeshInstance3D.new()
		var step_mesh := BoxMesh.new()
		var tier_width := field_width + 5.5 - float(row) * 0.42
		step_mesh.size = Vector3(tier_width, 0.40, 0.64)
		step.mesh = step_mesh
		var tier_y := 0.23 + float(row) * 0.39
		var tier_z := -field_depth * 0.5 - 1.0 - float(row) * 0.49
		step.position = Vector3(0.0, tier_y, tier_z)
		step.name = "FarStandRiser_%02d" % row
		step.material_override = _material(
			Color(0.062 + float(row) * 0.009, 0.083 + float(row) * 0.011, 0.108 + float(row) * 0.012),
			0.94
		)
		add_child(step)
		# Thin, satin-metal nosing on the exposed front face (towards +Z).
		# It brings out the stadium's depth without additional lights/shadows.
		var nosing := _add_box(
			Vector3(0.0, tier_y + 0.135, tier_z + 0.338),
			Vector3(tier_width - 0.10, 0.052, 0.035),
			Color(0.17, 0.25, 0.31) if row % 2 == 0 else Color(0.19, 0.27, 0.33)
		)
		nosing.name = "FarStandNosing_%02d" % row
		nosing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_add_ad_panels()
	_add_crowd()
	_add_end_stands()
	_add_far_roof()
	# The camera now includes the near touchline on playable human throw-ins.
	# Replace the tall, shadow-casting brown parapet that used to fill the
	# lower screen edge with a low satin-green pitch-side trim, outside the
	# playable rect. The new name makes its pure decorative contract testable.
	var near_rim := _add_box(
		Vector3(0.0, 0.09, field_depth * 0.5 + 0.28),
		Vector3(field_width + 1.4, 0.14, 0.12),
		Color(0.088, 0.16, 0.13)
	)
	near_rim.name = "NearTouchlineTrim"
	near_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_benches()
	_add_floodlights()

func _add_corner_flags() -> void:
	# Four regulation-scale corner pennants: club colours help the pitch read
	# like a football ground. Entirely decorative, outside the playable rect.
	# One vertex-coloured pennant mesh and one pole per corner; no new lights.
	for x_index in range(2):
		var sx := -1.0 if x_index == 0 else 1.0
		for z_index in range(2):
			var sz := -1.0 if z_index == 0 else 1.0
			var position_x := sx * (field_width * 0.5 + 0.14)
			var position_z := sz * (field_depth * 0.5 + 0.14)
			var pole := _add_box(
				Vector3(position_x, 0.77, position_z),
				Vector3(0.045, 1.54, 0.045),
				Color(0.91, 0.92, 0.86)
			)
			pole.name = "CornerPole_%d_%d" % [x_index, z_index]
			pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# A contrasting hoist and a triangular club-colour fly share one mesh.
			# The pennant flies outward, away from the corner taker and match chyron.
			var fly_direction := sx
			var vertices := PackedVector3Array([
				Vector3(0.0, 1.49, 0.0),
				Vector3(fly_direction * 0.25, 1.40, 0.0),
				Vector3(0.0, 1.11, 0.0),
				Vector3(0.0, 1.11, 0.0),
				Vector3(fly_direction * 0.25, 1.40, 0.0),
				Vector3(fly_direction * 0.25, 1.20, 0.0),
				Vector3(fly_direction * 0.25, 1.40, 0.0),
				Vector3(fly_direction * 0.84, 1.30, 0.0),
				Vector3(fly_direction * 0.25, 1.20, 0.0),
			])
			var hoist_color := Color(0.91, 0.81, 0.50)
			var club_color := (
				Color(0.20, 0.64, 0.98) if x_index == 0
				else Color(0.92, 0.21, 0.31)
			)
			var colors := PackedColorArray()
			for vertex_id in range(vertices.size()):
				colors.append(hoist_color if vertex_id < 6 else club_color)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_COLOR] = colors
			var pennant_mesh := ArrayMesh.new()
			pennant_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var pennant := MeshInstance3D.new()
			pennant.name = "CornerPennant_%d_%d" % [x_index, z_index]
			pennant.mesh = pennant_mesh
			pennant.position = Vector3(position_x, 0.0, position_z)
			var cloth := StandardMaterial3D.new()
			cloth.vertex_color_use_as_albedo = true
			cloth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
			pennant.material_override = cloth
			pennant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(pennant)

func _add_stadium_apron() -> void:
	var apron := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(field_width + 8.0, field_depth + 8.0)
	apron.mesh = mesh
	apron.position = Vector3(0.0, -0.035, 0.0)
	apron.material_override = _material(Color(0.025, 0.052, 0.046), 0.98)
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(apron)

	_add_box(Vector3(0.0, -0.12, -field_depth * 0.5 - 4.0), Vector3(field_width + 8.0, 0.22, 0.16), Color(0.030, 0.038, 0.048))
	_add_box(Vector3(0.0, -0.12, field_depth * 0.5 + 4.0), Vector3(field_width + 8.0, 0.22, 0.16), Color(0.030, 0.038, 0.048))

func _add_end_stands() -> void:
	# The end terraces are very visible during corners and goals. Their seats
	# share a single mesh rather than adding hundreds of per-seat draw calls.
	var seat_pads := MultiMesh.new()
	seat_pads.transform_format = MultiMesh.TRANSFORM_3D
	seat_pads.use_colors = true
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(0.35, 0.075, 0.32)
	seat_pads.mesh = pad_mesh
	seat_pads.instance_count = 2 * 4 * 24
	# Two shared meshes add occupants to previously empty end stands without
	# hundreds of individual nodes or extra lighting in the WebGL renderer.
	var supporter_bodies := MultiMesh.new()
	supporter_bodies.transform_format = MultiMesh.TRANSFORM_3D
	supporter_bodies.use_colors = true
	var supporter_body_mesh := BoxMesh.new()
	supporter_body_mesh.size = Vector3(0.22, 0.24, 0.20)
	supporter_bodies.mesh = supporter_body_mesh
	supporter_bodies.instance_count = seat_pads.instance_count
	var supporter_heads := MultiMesh.new()
	supporter_heads.transform_format = MultiMesh.TRANSFORM_3D
	supporter_heads.use_colors = true
	var supporter_head_mesh := SphereMesh.new()
	supporter_head_mesh.radius = 0.080
	supporter_head_mesh.height = 0.16
	supporter_head_mesh.radial_segments = 8
	supporter_head_mesh.rings = 4
	supporter_heads.mesh = supporter_head_mesh
	supporter_heads.instance_count = seat_pads.instance_count
	var seat_id := 0
	# The structural wall must sit BEHIND the upper seating. The old block
	# overlapped rows 2-4, clipping torsos and leaving floating heads.
	var stand_x := field_width * 0.5 + 3.30
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		var rear_wall := _add_box(
			Vector3(side * stand_x, 0.82, 0.0),
			Vector3(2.15, 1.70, field_depth + 1.8),
			Color(0.045, 0.067, 0.089)
		)
		rear_wall.name = "EndStandRearWall_%d" % side_index
		# Thin architectural accents are unshaded surfaces, NOT real floodlights.
		# Place them on the field-facing edge of the back wall, behind every
		# spectator row so the crowd remains the star of the corner camera.
		var wall_face_x := side * (stand_x - 1.10)
		var rim := _add_box(
			Vector3(wall_face_x, 1.71, 0.0),
			Vector3(0.065, 0.075, field_depth + 1.62),
			Color(0.26, 0.63, 0.77) if side_index == 0 else Color(0.77, 0.43, 0.32)
		)
		rim.name = "EndStandParapetRim_%d" % side_index
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var rim_material := rim.material_override as StandardMaterial3D
		rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for pillar_index in range(7):
			var z := lerpf(-field_depth * 0.43, field_depth * 0.43, float(pillar_index) / 6.0)
			var pillar := _add_box(
				Vector3(wall_face_x, 1.00, z),
				Vector3(0.070, 1.34, 0.15),
				Color(0.16, 0.23, 0.27)
			)
			pillar.name = "EndStandParapetPillar_%d_%d" % [side_index, pillar_index]
			pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for row in range(4):
			var x := side * (field_width * 0.5 + 0.72 + float(row) * 0.42)
			var height := 0.22 + float(row) * 0.34
			var tier_depth := field_depth + 1.25 - float(row) * 0.24
			_add_box(
				Vector3(x, height, 0.0),
				Vector3(0.56, 0.34, tier_depth),
				Color(0.060, 0.083 + float(row) * 0.014, 0.115 + float(row) * 0.014)
			)
			# Continuous steel-blue aisle-edge safety rail, always outside play.
			var rail := _add_box(
				Vector3(x - side * 0.23, height + 0.24, 0.0),
				Vector3(0.065, 0.09, tier_depth - 0.20),
				Color(0.19, 0.30, 0.38)
			)
			rail.name = "EndStandTierRail_%d_%d" % [side_index, row]
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for seat in range(24):
				var z := lerpf(-tier_depth * 0.44, tier_depth * 0.44, (float(seat) + 0.5) / 24.0)
				seat_pads.set_instance_transform(
					seat_id,
					Transform3D(Basis.IDENTITY, Vector3(x, height + 0.22, z))
				)
				var color := Color(0.18, 0.31, 0.49)
				if (seat + row * 2 + side_index) % 7 == 0:
					color = Color(0.58, 0.42, 0.22)
				elif (seat + row + side_index) % 5 == 0:
					color = Color(0.27, 0.43, 0.58)
				seat_pads.set_instance_color(seat_id, color)
				# Bodies rest on the visible seating, and heads keep the far
				# grandstand's restrained, readable low-poly vocabulary.
				supporter_bodies.set_instance_transform(
					seat_id, Transform3D(Basis.IDENTITY, Vector3(x, height + 0.38, z))
				)
				supporter_heads.set_instance_transform(
					seat_id, Transform3D(Basis.IDENTITY, Vector3(x, height + 0.58, z))
				)
				var shirt := Color(0.15, 0.37, 0.67) if side_index == 0 else Color(0.51, 0.15, 0.22)
				if (seat + row * 3) % 9 == 0:
					shirt = Color(0.73, 0.56, 0.20)
				elif (seat + row + side_index) % 7 == 0:
					shirt = Color(0.34, 0.40, 0.47)
				supporter_bodies.set_instance_color(seat_id, shirt)
				var skin := Color(0.62, 0.46, 0.33)
				if (seat + row) % 3 == 0:
					skin = Color(0.37, 0.29, 0.24)
				elif (seat + row) % 3 == 2:
					skin = Color(0.74, 0.59, 0.44)
				supporter_heads.set_instance_color(seat_id, skin)
				seat_id += 1
	_add_crowd_instances("EndStandSeatPads", seat_pads)
	_add_crowd_instances("EndStandSupporterBodies", supporter_bodies)
	_add_crowd_instances("EndStandSupporterHeads", supporter_heads)

func _add_far_roof() -> void:
	var roof_z := -field_depth * 0.5 - 3.70
	_add_box(Vector3(0.0, 3.25, roof_z), Vector3(field_width + 6.4, 0.18, 2.4), Color(0.045, 0.050, 0.060))
	for x_value in [-field_width * 0.48, -field_width * 0.16, field_width * 0.16, field_width * 0.48]:
		var x: float = float(x_value)
		_add_box(Vector3(x, 1.75, roof_z + 0.55), Vector3(0.11, 3.0, 0.11), Color(0.20, 0.22, 0.24))
		_add_box(Vector3(x, 3.03, roof_z + 0.10), Vector3(0.10, 0.10, 1.05), Color(0.20, 0.22, 0.24))

func _add_benches() -> void:
	# The benches used to sit directly in the playable near-touchline
	# camera foreground. Keep their actual geometry and dimensions, but park
	# them beside the end terraces, beyond near-corner camera sightlines.
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		var x := side * (field_width * 0.5 + 1.0)
		var base := _add_box(
			Vector3(x, 0.20, field_depth * 0.5 + 0.68),
			Vector3(1.7, 0.38, 0.52),
			Color(0.055, 0.070, 0.082)
		)
		base.name = "TouchlineBenchBase_%d" % side_index
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var canopy := _add_box(
			Vector3(x, 0.46, field_depth * 0.5 + 0.72),
			Vector3(1.7, 0.08, 0.56),
			Color(0.24, 0.26, 0.28)
		)
		canopy.name = "TouchlineBenchCanopy_%d" % side_index
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _add_floodlights() -> void:
	for z_value in [-field_depth * 0.5 - 3.15, field_depth * 0.5 + 3.15]:
		var z: float = float(z_value)
		for side_index in range(2):
			var side := -1.0 if side_index == 0 else 1.0
			# Near-side poles must not obscure the near corner in broadcast.
			# Keep all four existing lights; move only the foreground pair
			# just beyond the actual field/terrace corners.
			var x := side * (
				field_width * 0.5 + 2.5 if z > 0.0
				else field_width * 0.43
			)
			var post := _add_box(
				Vector3(x, 2.55, z), Vector3(0.10, 5.10, 0.10),
				Color(0.20, 0.22, 0.24)
			)
			var bar := _add_box(
				Vector3(x, 5.02, z), Vector3(1.25, 0.12, 0.26),
				Color(0.24, 0.26, 0.29)
			)
			if z > 0.0:
				post.name = "NearCornerFloodlightPost_%d" % side_index
				bar.name = "NearCornerFloodlightBar_%d" % side_index
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 4.90, z)
			lamp.light_color = Color(0.84, 0.90, 1.0)
			lamp.light_energy = 0.72
			lamp.omni_range = 12.0
			lamp.shadow_enabled = false
			add_child(lamp)

func _add_ad_panels() -> void:
	# Match-side signs are intentionally static and lightweight for Godot Web.
	# Distinctive club/studio identities replace the old primary-color blocks;
	# no external sponsors, animated textures, or extra realtime light sources.
	var messages := [
		"FC MATTHIAS", "CHESS FOOTBALL", "SHADOWOPS", "REAL ENROQUE",
		"FC MATTHIAS", "SHADOWOPS", "CHESS FOOTBALL", "REAL ENROQUE",
		"SHADOWOPS", "FC MATTHIAS", "REAL ENROQUE", "CHESS FOOTBALL",
	]
	var accents := [
		Color(0.26, 0.72, 0.91), Color(0.90, 0.69, 0.33),
		Color(0.62, 0.81, 0.89), Color(0.77, 0.41, 0.44),
	]
	ad_default_messages.clear()
	ad_default_accents.clear()
	var panel_count := messages.size()
	var panel_width := field_width / float(panel_count)
	var z := -field_depth * 0.5 - 0.30
	for i in range(panel_count):
		var x := -field_width * 0.5 + panel_width * (float(i) + 0.5)
		var color: Color = accents[i % accents.size()]
		ad_default_messages.append(messages[i])
		ad_default_accents.append(color)
		var panel := _add_box(
			Vector3(x, 0.24, z), Vector3(panel_width - 0.045, 0.43, 0.08),
			Color(0.045, 0.085, 0.124)
		)
		panel.name = "MatchLedPanel_%02d" % i
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Thin top accent is emissive-looking, but does not illuminate the pitch.
		var band := _add_box(
			Vector3(x, 0.462, z + 0.052),
			Vector3(panel_width - 0.055, 0.035, 0.012), color
		)
		band.name = "MatchLedAccent_%02d" % i
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var band_material := band.material_override as StandardMaterial3D
		band_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		# Front-facing Label3D is visible to the broadcast camera (+Z).
		# The panel's mesh remains an actual stadium object, not HUD UI.
		var sign := Label3D.new()
		sign.name = "MatchLedSign_%02d" % i
		sign.text = messages[i]
		sign.font_size = 47
		sign.pixel_size = 0.0050
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.modulate = Color(0.97, 0.98, 1.0)
		sign.shaded = false
		sign.no_depth_test = false
		sign.position = Vector3(x, 0.253, z + 0.061)
		add_child(sign)


func _sync_goal_ad_panels() -> void:
	# Only the authoritative match announcement triggers this diegetic
	# celebration. A transition restores the original sponsor content exactly
	# once, so no per-frame churn, overlays, or made-up result data.
	var announcement := String(match_node.last_goal_text)
	var scoring_team := -1
	if announcement.begins_with("GOAL · FC Matthias"):
		scoring_team = 0
	elif announcement.begins_with("GOAL · Real Enroque"):
		scoring_team = 1
	if scoring_team == ad_last_goal_team:
		return
	ad_last_goal_team = scoring_team
	var winning_name := "FC MATTHIAS" if scoring_team == 0 else "REAL ENROQUE"
	var winning_accent := (
		Color(0.24, 0.70, 0.97) if scoring_team == 0
		else Color(0.96, 0.35, 0.38)
	)
	for index in range(ad_default_messages.size()):
		var board := get_node_or_null("MatchLedSign_%02d" % index) as Label3D
		if board != null:
			board.text = (
				("GOOOL!" if index % 2 == 0 else winning_name)
				if scoring_team >= 0 else ad_default_messages[index]
			)
		var accent_mesh := get_node_or_null("MatchLedAccent_%02d" % index) as MeshInstance3D
		if accent_mesh != null:
			var accent_mat := accent_mesh.material_override as StandardMaterial3D
			if accent_mat != null:
				accent_mat.albedo_color = (
					winning_accent if scoring_team >= 0 else ad_default_accents[index]
				)

func _add_crowd() -> void:
	# The grandstand is one authored crowd, not 170 individual shadow-casting
	# boxes. Shared 3D instances keep WebGL draw calls and memory predictable.
	var rows := 5
	var seats := 34
	var bodies := MultiMesh.new()
	bodies.transform_format = MultiMesh.TRANSFORM_3D
	bodies.use_colors = true
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.21, 0.24, 0.14)
	bodies.mesh = body_mesh
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	heads.use_colors = true
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.075
	head_mesh.height = 0.15
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	heads.mesh = head_mesh

	# Leave two clearly readable stair aisles; crowd positions remain static,
	# deterministic and visually separate from footballers and the field.
	var crowd_positions: Array[Vector3] = []
	var body_colors: Array[Color] = []
	var head_colors: Array[Color] = []
	for row in range(rows):
		for seat in range(seats):
			if seat in [10, 11, 22, 23]:
				continue
			var ratio := (float(seat) + 0.5) / float(seats)
			var x := lerpf(-field_width * 0.47, field_width * 0.47, ratio)
			var y := 0.43 + float(row) * 0.38
			var z := -field_depth * 0.5 - 1.02 - float(row) * 0.48
			crowd_positions.append(Vector3(x, y, z))
			var palette := (seat + row * 3) % 9
			var shirt := Color(0.24, 0.29, 0.36)
			if palette in [0, 4]:
				shirt = Color(0.13, 0.37, 0.70)
			elif palette in [1, 6]:
				shirt = Color(0.49, 0.15, 0.21)
			elif palette == 2:
				shirt = Color(0.69, 0.53, 0.18)
			elif palette == 5:
				shirt = Color(0.55, 0.59, 0.65)
			body_colors.append(shirt)
			head_colors.append(
				Color(0.49, 0.34, 0.26) if (seat + row) % 3 == 0
				else Color(0.64, 0.51, 0.39) if (seat + row) % 3 == 1
				else Color(0.33, 0.29, 0.27)
			)
	bodies.instance_count = crowd_positions.size()
	heads.instance_count = crowd_positions.size()
	for i in range(crowd_positions.size()):
		bodies.set_instance_transform(i, Transform3D(Basis.IDENTITY, crowd_positions[i]))
		bodies.set_instance_color(i, body_colors[i])
		heads.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, crowd_positions[i] + Vector3(0.0, 0.18, 0.0))
		)
		heads.set_instance_color(i, head_colors[i])
	_add_crowd_instances("GrandstandCrowdBodies", bodies)
	_add_crowd_instances("GrandstandCrowdHeads", heads)

	# Warm, unlit tread edges give both stair aisles depth without extra lights.
	# No light/shadow changes on the playing field or canonical player sprites.
	var treads := MultiMesh.new()
	treads.transform_format = MultiMesh.TRANSFORM_3D
	var tread_mesh := BoxMesh.new()
	tread_mesh.size = Vector3(0.52, 0.035, 0.10)
	treads.mesh = tread_mesh
	treads.instance_count = rows * 2
	for row in range(rows):
		for aisle in range(2):
			var middle_seat := 10.5 if aisle == 0 else 22.5
			var x := lerpf(-field_width * 0.47, field_width * 0.47, (middle_seat + 0.5) / float(seats))
			var y := 0.45 + float(row) * 0.39
			var z := -field_depth * 0.5 - 0.82 - float(row) * 0.49
			treads.set_instance_transform(
				row * 2 + aisle, Transform3D(Basis.IDENTITY, Vector3(x, y, z))
			)
	var tread_instance := MultiMeshInstance3D.new()
	tread_instance.name = "GrandstandAisleTreads"
	tread_instance.multimesh = treads
	var amber := _material(Color(0.91, 0.62, 0.25))
	amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tread_instance.material_override = amber
	tread_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tread_instance)

func _add_crowd_instances(label: String, instances: MultiMesh) -> void:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _add_penalty_box(right_side: bool, color: Color) -> void:
	var width := ChessFootballMath.PENALTY_AREA_DEPTH * WORLD_SCALE
	var depth := ChessFootballMath.PENALTY_AREA_HALF_WIDTH * 2.0 * WORLD_SCALE
	var edge_x := field_width * 0.5 if right_side else -field_width * 0.5
	var center_x := edge_x - width * 0.5 if right_side else edge_x + width * 0.5
	var inner_x := edge_x - width if right_side else edge_x + width
	_add_box(Vector3(center_x, 0.022, -depth * 0.5), Vector3(width, 0.03, 0.04), color)
	_add_box(Vector3(center_x, 0.022, depth * 0.5), Vector3(width, 0.03, 0.04), color)
	_add_box(Vector3(inner_x, 0.022, 0.0), Vector3(0.04, 0.03, depth), color)
	var penalty_spot_x := (
		edge_x - ChessFootballMath.PENALTY_SPOT_DEPTH * WORLD_SCALE
		if right_side
		else edge_x + ChessFootballMath.PENALTY_SPOT_DEPTH * WORLD_SCALE
	)
	_add_box(Vector3(penalty_spot_x, 0.024, 0.0), Vector3(0.11, 0.025, 0.11), color)

func _add_goal_area_markings(right_side: bool, color: Color) -> void:
	# The six-yard box and penalty D are pitch paint only. They deliberately
	# derive from the same 5v5 arcade proportions without changing physics.
	var right_name := "Right" if right_side else "Left"
	var side := -1.0 if right_side else 1.0
	var edge_x := side * -field_width * 0.5
	var goal_area_depth := ChessFootballMath.PENALTY_AREA_DEPTH * 0.40 * WORLD_SCALE
	var goal_area_half_width := ChessFootballMath.PENALTY_AREA_HALF_WIDTH * 0.79 * WORLD_SCALE
	var inner_x := edge_x + side * goal_area_depth
	var mid_x := edge_x + side * goal_area_depth * 0.5
	var line_thickness := 0.035

	for z_side in [-1.0, 1.0]:
		var mark := _add_box(
			Vector3(mid_x, 0.027, z_side * goal_area_half_width),
			Vector3(goal_area_depth, 0.026, line_thickness), color
		)
		mark.name = "GoalArea%sSide%s" % [right_name, "Near" if z_side > 0.0 else "Far"]
	var inner := _add_box(
		Vector3(inner_x, 0.027, 0.0),
		Vector3(line_thickness, 0.026, goal_area_half_width * 2.0), color
	)
	inner.name = "GoalArea%sInner" % right_name

	# Arc is clipped to the part outside the penalty rectangle. The centre of
	# the D is exactly the marked penalty spot; its ends touch the box edge.
	var arc_radius := ChessFootballMath.PENALTY_AREA_DEPTH * 0.58 * WORLD_SCALE
	var spot_x := edge_x + side * ChessFootballMath.PENALTY_SPOT_DEPTH * WORLD_SCALE
	var box_gap := (
		ChessFootballMath.PENALTY_AREA_DEPTH - ChessFootballMath.PENALTY_SPOT_DEPTH
	) * WORLD_SCALE
	var cutoff_angle := acos(box_gap / arc_radius)
	var arc_mesh := ImmediateMesh.new()
	arc_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(33):
		var angle := lerpf(-cutoff_angle, cutoff_angle, float(i) / 32.0)
		arc_mesh.surface_add_vertex(
			Vector3(
				spot_x + side * cos(angle) * arc_radius,
				0.038,
				sin(angle) * arc_radius
			)
		)
	arc_mesh.surface_end()
	var penalty_arc := MeshInstance3D.new()
	penalty_arc.name = "PenaltyArc%s" % right_name
	penalty_arc.mesh = arc_mesh
	var arc_material := StandardMaterial3D.new()
	arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_material.albedo_color = color
	penalty_arc.material_override = arc_material
	penalty_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(penalty_arc)

func _add_center_circle(color: Color) -> void:
	var mesh := ImmediateMesh.new()
	var radius := 105.0 * WORLD_SCALE
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(49):
		var angle := TAU * float(i) / 48.0
		mesh.surface_add_vertex(Vector3(cos(angle) * radius, 0.035, sin(angle) * radius))
	mesh.surface_end()
	var circle := MeshInstance3D.new()
	circle.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	circle.material_override = material
	add_child(circle)

func _build_goals() -> void:
	var goal_half := ChessFootballMath.GOAL_HALF_HEIGHT * WORLD_SCALE
	var post_height := GOAL_POST_HEIGHT
	var post := 0.075
	var depth := 1.00
	var white := Color(0.95, 0.96, 0.94)
	var net_color := Color(0.58, 0.63, 0.66)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var x: float = side * field_width * 0.5
		var back_x: float = x + side * depth
		for z_value in [-goal_half, goal_half]:
			var z: float = float(z_value)
			_add_box(Vector3(x, post_height * 0.5, z), Vector3(post, post_height, post), white)
			_add_box(Vector3(back_x, post_height * 0.5, z), Vector3(post * 0.65, post_height, post * 0.65), net_color)
			_add_box(Vector3((x + back_x) * 0.5, post_height, z), Vector3(depth, post * 0.65, post * 0.65), net_color)
			_add_box(Vector3((x + back_x) * 0.5, 0.045, z), Vector3(depth, post * 0.55, post * 0.55), net_color)
		_add_box(Vector3(x, post_height, 0.0), Vector3(post, post, goal_half * 2.0 + post), white)
		_add_box(Vector3(back_x, post_height, 0.0), Vector3(post * 0.65, post * 0.65, goal_half * 2.0), net_color)
		_add_box(Vector3(back_x, 0.045, 0.0), Vector3(post * 0.55, post * 0.55, goal_half * 2.0), net_color)
		# Fine netting is one line-mesh draw per goal. Never add physics bodies:
		# gameplay goal-mouth checks stay owned by ChessFootballMath.
		_add_goal_net_grid(x, back_x, goal_half, post_height, side < 0.0)

func _add_net_segment(net: ImmediateMesh, from_point: Vector3, to_point: Vector3) -> void:
	net.surface_add_vertex(from_point)
	net.surface_add_vertex(to_point)

func _add_goal_net_grid(
	front_x: float, back_x: float, half_width: float, height: float, is_left: bool
) -> void:
	var net := ImmediateMesh.new()
	net.surface_begin(Mesh.PRIMITIVE_LINES)
	# Vertical and horizontal strands across the back of the goal.
	for z_index in range(17):
		var z := lerpf(-half_width, half_width, float(z_index) / 16.0)
		_add_net_segment(net, Vector3(back_x, 0.05, z), Vector3(back_x, height, z))
		_add_net_segment(net, Vector3(front_x, height, z), Vector3(back_x, height, z))
	for y_index in range(11):
		var y := lerpf(0.05, height, float(y_index) / 10.0)
		_add_net_segment(net, Vector3(back_x, y, -half_width), Vector3(back_x, y, half_width))
		# Side panels keep a clean opening between the front goalposts.
		for edge in [-half_width, half_width]:
			_add_net_segment(net, Vector3(front_x, y, edge), Vector3(back_x, y, edge))
	# Complete both side panels and the roof, rather than a few thick rails.
	for depth_index in range(7):
		var net_x := lerpf(front_x, back_x, float(depth_index) / 6.0)
		_add_net_segment(
			net, Vector3(net_x, height, -half_width), Vector3(net_x, height, half_width)
		)
		for edge in [-half_width, half_width]:
			_add_net_segment(net, Vector3(net_x, 0.05, edge), Vector3(net_x, height, edge))
	net.surface_end()
	var instance := MeshInstance3D.new()
	instance.name = "GoalNetLeft" if is_left else "GoalNetRight"
	instance.mesh = net
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.68, 0.74, 0.78)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

# The XI quad always reuses the live sprite driver's canonical frame,
# including real idle, run direction and action poses while R2 is offline.
# Nearest filtering and the lowered alpha threshold on the quad preserve
# those local sprites at full-pitch zoom (the regression is pixel-tested).
# A tactical camera looks steeply downward; an upright FIXED_Y billboard
# looks like a flattened scrap of cloth from above. Use a camera-facing
# billboard there, but translate its centre so the actual boot pixel stays
# on exactly the same ground point as the upright broadcast billboard.
# All offsets are presentation-only and are recalculated each frame.
# The frame's lowest opaque pixel is not directly beneath its centre when
# the runner leans. Resolve that *rotated* boot pixel in billboard space,
# then shift the quad so it stays at the same world-ground point as the
# static contact shadow. FIXED_Y broadcast has a horizontal right axis;
# camera-facing tactical uses the full camera up/right basis.
# Caller supplies the FINAL perspective-corrected Y scale. No GPU readback.
static func xi_rotated_foot_anchor_offset(
	view_camera: Camera3D, frame: Texture2D, pixel_size: float,
	scale_y: float, tilt_radians: float, tactical: bool
) -> Vector3:
	if view_camera == null or frame == null:
		return Vector3.ZERO
	var foot_pixels: float = ChessFootballSpriteBank.frame_bottom(frame) - float(frame.get_height()) * 0.5
	var foot_extent: float = foot_pixels * pixel_size * scale_y
	var right_axis: Vector3 = view_camera.global_transform.basis.x.normalized()
	var up_axis := Vector3.UP
	if tactical:
		up_axis = view_camera.global_transform.basis.y.normalized()
	else:
		# A fixed-Y billboard never pitches its local horizontal axis.
		right_axis.y = 0.0
		right_axis = right_axis.normalized()
	var rotated_up := up_axis * cos(tilt_radians) - right_axis * sin(tilt_radians)
	return (rotated_up - Vector3.UP) * foot_extent


# Compatibility helper: zero-lean tactical stance uses the same anchor.
static func xi_tactical_foot_anchor_offset(
	view_camera: Camera3D, frame: Texture2D, pixel_size: float, scale_y: float
) -> Vector3:
	return xi_rotated_foot_anchor_offset(view_camera, frame, pixel_size, scale_y, 0.0, true)


func _xi_frame_texture(_player: Footballer, driver: AnimatedSprite3D) -> Texture2D:
	var frames := driver.sprite_frames
	if frames.has_animation(driver.animation):
		var count := frames.get_frame_count(driver.animation)
		if count > 0:
			return frames.get_frame_texture(driver.animation, clampi(driver.frame, 0, count - 1))
	# Fail closed to the known local raster if a transitional state names a
	# missing animation; never substitute a geometric placeholder.
	var run_count := frames.get_frame_count(&"run")
	if run_count > 0:
		return frames.get_frame_texture(&"run", driver.frame % run_count)
	return null


# XI-only raster mirrors the existing AnimatedSprite3D clock and atlas.
# Initialize after the 3D scene entered the tree, exactly like the real
# 22-actor visual diagnostic. The shipped 5v5 has no extra raster nodes.
# In XI, Godot's GLES3 Sprite3D batches intermittently skip distant bodies.
# A textured QuadMesh always renders the bundled canonical atlas and can
# optionally receive verified R2 frames. No sculpt or placeholder fallback.
# The hidden AnimatedSprite3D remains the animation clock.
func _build_xi_quad_bodies() -> void:
	if match_node.match_team_size != 11:
		return
	for team in match_node.teams:
		for player in team:
			var key: int = int(player.get_instance_id())
			var driver: AnimatedSprite3D = player_sprites.get(key)
			var proxy: Node3D = player_nodes.get(key)
			assert(driver != null and proxy != null)
			var frame_texture: Texture2D = _xi_frame_texture(player, driver)
			var panel := QuadMesh.new()
			panel.size = Vector2(frame_texture.get_width(), frame_texture.get_height()) * driver.pixel_size
			var material := StandardMaterial3D.new()
			material.albedo_texture = frame_texture
			material.albedo_color = driver.modulate
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			# The bundled legacy atlas has thin opaque strokes surrounded by
			# transparent padding. Linear mipmap averaging can reduce distant
			# actors below the alpha cutout threshold, effectively erasing them.
			# Preserve a texel-aligned silhouette at XI broadcast/tactical zoom.
			material.alpha_scissor_threshold = 0.02
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			# Rotate only around world Y. A fully camera-facing billboard
			# tilts back with the broadcast camera and lifts the visible boots
			# away from the real grass contact/shadow point on distant players.
			material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			# Critical: Godot billboard shaders discard MeshInstance3D.scale
			# unless KEEP_SCALE is enabled. Earlier per-view and depth corrections
			# changed sprite/quad transforms but NOT the visible pixel silhouette.
			# Keep the real authored scale in BOTH fixed-Y broadcast and full
			# camera-facing tactical modes. The foot anchor already uses it.
			material.billboard_keep_scale = true
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			# Prevent a distant, vertical raster body from sinking into turf
			# when the full-pitch aerial camera intersects the field depth.
			material.no_depth_test = true
			var quad := MeshInstance3D.new()
			quad.name = "XI_RasterBody"
			quad.mesh = panel
			quad.material_override = material
			quad.position = driver.position
			quad.rotation = driver.rotation
			quad.scale = driver.scale
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			proxy.add_child(quad)
			xi_raster_meshes[key] = quad
			# One visible body per actor: use the bundled canonical raster even
			# when optional R2 is offline. Keep the legacy sculpt hidden so
			# switching R2 frames never exposes a second body or a mannequin.
			var sculpt := xi_actor_models.get(key) as Node3D
			if sculpt != null:
				sculpt.hide()
			driver.hide()


func _build_xi_actor_sculpt(root: Node3D, player: Footballer) -> void:
	var model := Node3D.new()
	model.name = "XI_KitSculpt"
	var jersey := _material(player.team_color, 0.86)
	var shorts := _material(player.team_color.darkened(0.38), 0.91)
	var skin := _material(Color(0.69, 0.48, 0.33), 0.92)
	var boots := _material(Color(0.035, 0.046, 0.063), 0.90)
	var torso := MeshInstance3D.new()
	torso.name = "Jersey"
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.24
	body_mesh.bottom_radius = 0.19
	body_mesh.height = 0.58
	torso.mesh = body_mesh
	torso.position.y = 0.69
	torso.material_override = jersey
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(torso)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.15
	head_mesh.height = 0.30
	head.mesh = head_mesh
	head.position.y = 1.13
	head.material_override = skin
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(head)
	for sign in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.097
		leg_mesh.bottom_radius = 0.072
		leg_mesh.height = 0.48
		leg.mesh = leg_mesh
		leg.position = Vector3(sign * 0.12, 0.24, 0.0)
		leg.material_override = shorts
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(leg)
		var shoe := MeshInstance3D.new()
		var shoe_mesh := BoxMesh.new()
		shoe_mesh.size = Vector3(0.18, 0.095, 0.29)
		shoe.mesh = shoe_mesh
		shoe.position = Vector3(sign * 0.12, 0.055, -0.045)
		shoe.material_override = boots
		shoe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(shoe)
	root.add_child(model)
	xi_actor_models[int(player.get_instance_id())] = model


func _soft_contact_shadow_material() -> ShaderMaterial:
	if _contact_shadow_material != null:
		return _contact_shadow_material
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength : hint_range(0.0, 1.0) = 0.27;
void fragment() {
	vec2 offset = (UV - vec2(0.5)) * 2.0;
	float distance_to_center = length(offset);
	float feather = 1.0 - smoothstep(0.05, 1.0, distance_to_center);
	ALBEDO = vec3(0.018, 0.025, 0.019);
	ALPHA = feather * feather * strength;
}
"""
	_contact_shadow_material = ShaderMaterial.new()
	_contact_shadow_material.shader = shader
	return _contact_shadow_material


func _build_player_proxies() -> void:
	for team in match_node.teams:
		for player in team:
			var root := Node3D.new()
			root.name = "Player3D_%d_%d" % [player.team_id, player.squad_index]

			var sprite := AnimatedSprite3D.new()
			sprite.name = "Sprite"
			sprite.sprite_frames = ChessFootballSpriteBank.build_frames(
				player.team_id,
				player.role,
				player.squad_index,
				true,
			)
			sprite.centered = true
			sprite.pixel_size = PLAYER_PIXEL_SIZE
			sprite.position.y = PLAYER_BASE_Y
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			# Avoid blended transparent quads looking like ghosts in WebGL.
			# Raster footballers should render opaque body pixels, without pitch lighting.
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			sprite.alpha_scissor_threshold = 0.12
			sprite.shaded = false
			sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sprite.flip_h = player.team_id == 1
			sprite.play("idle")
			root.add_child(sprite)
			if match_node.match_team_size == 11:
				_build_xi_actor_sculpt(root, player)
			if player.role == "keeper":
				keeper_catch_rigs[int(player.get_instance_id())] = _build_keeper_catch_rig(root, player.team_id)

			# One feathered ground decal per player, no ink-black cylinder
			# and no baked shadow attached to the animated body texture.
			var shadow := MeshInstance3D.new()
			shadow.name = "ContactShadow"
			var shadow_mesh := QuadMesh.new()
			shadow_mesh.size = Vector2(0.74, 0.46)
			shadow.mesh = shadow_mesh
			shadow.rotation.x = -PI * 0.5
			shadow.position.y = 0.012
			shadow.material_override = _soft_contact_shadow_material()
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(shadow)

			var active_disc := MeshInstance3D.new()
			active_disc.name = "ActiveDisc"
			var disc_mesh := TorusMesh.new()
			disc_mesh.inner_radius = 0.40
			disc_mesh.outer_radius = 0.48
			active_disc.mesh = disc_mesh
			active_disc.position.y = 0.035
			active_disc.material_override = _material(Color(1.0, 0.72, 0.16), 0.32)
			active_disc.visible = false
			root.add_child(active_disc)

			# Only during a playable human corner/throw: show which outfield
			# teammates can receive a tap. This is passive 3D decoration, never
			# a new input or match-state authority. Keep it separate from the
			# existing amber controlled-player ring.
			var receiver_disc := MeshInstance3D.new()
			receiver_disc.name = "SetPieceReceiverDisc"
			var receiver_mesh := TorusMesh.new()
			receiver_mesh.inner_radius = 0.59
			receiver_mesh.outer_radius = 0.67
			receiver_disc.mesh = receiver_mesh
			receiver_disc.position.y = 0.045
			receiver_disc.material_override = _material(Color(0.30, 0.92, 0.83), 0.34)
			receiver_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			receiver_disc.visible = false
			root.add_child(receiver_disc)

			var stamina_back := MeshInstance3D.new()
			stamina_back.name = "StaminaBack"
			var stamina_back_mesh := BoxMesh.new()
			stamina_back_mesh.size = Vector3(STAMINA_BAR_WIDTH + 0.06, 0.028, STAMINA_BAR_DEPTH + 0.04)
			stamina_back.mesh = stamina_back_mesh
			stamina_back.position = Vector3(0.0, 0.040, STAMINA_BAR_Z)
			stamina_back.material_override = _material(Color(0.025, 0.030, 0.032), 0.95)
			stamina_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stamina_back.visible = false
			root.add_child(stamina_back)

			var stamina_fill := MeshInstance3D.new()
			stamina_fill.name = "StaminaFill"
			var stamina_fill_mesh := BoxMesh.new()
			stamina_fill_mesh.size = Vector3(STAMINA_BAR_WIDTH, 0.034, STAMINA_BAR_DEPTH)
			stamina_fill.mesh = stamina_fill_mesh
			stamina_fill.position = Vector3(0.0, 0.058, STAMINA_BAR_Z)
			stamina_fill.material_override = _material(Color(1.0, 0.72, 0.16), 0.45)
			stamina_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stamina_fill.visible = false
			root.add_child(stamina_fill)

			add_child(root)
			player_nodes[player.get_instance_id()] = root
			player_sprites[player.get_instance_id()] = sprite


# The canonical keeper sprite remains untouched. A low-poly visual grip
# only appears while the keeper actually possesses the ball. Its narrow shirt
# sleeves lead into dark glove backs and smaller painted palms: no floating
# yellow spheres or thick tubular forearms at broadcast distance.
func _build_keeper_catch_rig(parent: Node3D, team_id: int) -> Node3D:
	var rig := Node3D.new()
	rig.name = "KeeperCatchHands"
	rig.visible = false
	parent.add_child(rig)
	var sleeve_color := Color(0.08, 0.30, 0.34) if team_id == 0 else Color(0.17, 0.21, 0.28)
	for suffix in ["Left", "Right"]:
		var sleeve := MeshInstance3D.new()
		sleeve.name = "Sleeve" + suffix
		var sleeve_mesh := CylinderMesh.new()
		sleeve_mesh.top_radius = 0.039
		sleeve_mesh.bottom_radius = 0.052
		sleeve_mesh.height = 1.0
		sleeve.mesh = sleeve_mesh
		var sleeve_mat := _material(sleeve_color, 0.98)
		sleeve_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sleeve.material_override = sleeve_mat
		sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(sleeve)

		var glove := MeshInstance3D.new()
		glove.name = "Glove" + suffix
		var glove_mesh := SphereMesh.new()
		glove_mesh.radius = 0.074
		glove_mesh.height = 0.135
		glove_mesh.radial_segments = 10
		glove_mesh.rings = 5
		glove.mesh = glove_mesh
		# The dark leather back gives each glove a cuff/silhouette, not a
		# second oversized flesh-coloured disk alongside the match ball.
		var glove_mat := _material(Color(0.28, 0.34, 0.38), 0.95)
		glove_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glove.material_override = glove_mat
		glove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(glove)

		var palm := MeshInstance3D.new()
		palm.name = "GripPalm"
		var palm_mesh := SphereMesh.new()
		palm_mesh.radius = 0.046
		palm_mesh.height = 0.080
		palm_mesh.radial_segments = 10
		palm_mesh.rings = 5
		palm.mesh = palm_mesh
		palm.position = Vector3(0.0, 0.002, 0.056)
		var palm_mat := _material(Color(0.83, 0.81, 0.58), 0.95)
		palm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		palm.material_override = palm_mat
		palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glove.add_child(palm)
	return rig

func _sync_keeper_catch_hands(
	carrier: Footballer, ball_at: Vector3, catch_progress: float
) -> void:
	for key in keeper_catch_rigs.keys():
		var rig: Node3D = keeper_catch_rigs[key]
		rig.visible = (
			carrier != null and int(carrier.get_instance_id()) == int(key)
			and not _keeper_catch_r2_loaded.has(int(carrier.team_id))
		)
	if carrier == null:
		return
	var rig: Node3D = keeper_catch_rigs.get(int(carrier.get_instance_id()))
	if rig == null:
		return
	if _keeper_catch_r2_loaded.has(int(carrier.team_id)):
		return
	var held_ball := ball_at - world_to_stage(carrier.global_position)
	# Both wrists move in from an open, anticipatory shape instead of appearing
	# as a rigid pair of grips already locked around a just-arrived ball.
	var hand_span := lerpf(
		KEEPER_CATCH_OPEN_HAND_SPAN, KEEPER_CATCH_CLOSED_HAND_SPAN,
		clampf(catch_progress, 0.0, 1.0),
	)
	for side in [-1, 1]:
		var suffix := "Left" if side < 0 else "Right"
		var glove := rig.get_node("Glove" + suffix) as MeshInstance3D
		var sleeve := rig.get_node("Sleeve" + suffix) as MeshInstance3D
		var palm := held_ball + Vector3(float(side) * hand_span, -0.015, 0.085)
		glove.position = palm
		var shoulder := Vector3(float(side) * 0.29, 1.08, 0.24)
		var wrist := palm + Vector3(float(side) * 0.055, -0.065, -0.04)
		var length := shoulder.distance_to(wrist)
		sleeve.position = (shoulder + wrist) * 0.5
		sleeve.scale.y = length
		if length > 0.001:
			sleeve.quaternion = Quaternion(Vector3.UP, (wrist - shoulder).normalized())


func debug_keeper_catch_hands_visible(keeper: Footballer) -> bool:
	var rig: Node3D = keeper_catch_rigs.get(int(keeper.get_instance_id()))
	return rig != null and rig.visible


func debug_keeper_catch_sleeve_length(keeper: Footballer, side: int) -> float:
	var rig: Node3D = keeper_catch_rigs.get(int(keeper.get_instance_id()))
	if rig == null:
		return INF
	var suffix := "Left" if side < 0 else "Right"
	var sleeve := rig.get_node("Sleeve" + suffix) as MeshInstance3D
	return sleeve.scale.y


func debug_keeper_catch_glove_span(keeper: Footballer) -> float:
	var rig: Node3D = keeper_catch_rigs.get(int(keeper.get_instance_id()))
	if rig == null:
		return 0.0
	var left := rig.get_node("GloveLeft") as MeshInstance3D
	var right := rig.get_node("GloveRight") as MeshInstance3D
	return left.global_position.distance_to(right.global_position)


func debug_keeper_catch_glove_distance(keeper: Footballer, side: int) -> float:
	var rig: Node3D = keeper_catch_rigs.get(int(keeper.get_instance_id()))
	if rig == null:
		return INF
	var suffix := "Left" if side < 0 else "Right"
	var glove := rig.get_node("Glove" + suffix) as MeshInstance3D
	return glove.global_position.distance_to(ball_node.global_position)


func _build_ball() -> void:
	ball_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	# Only the XI mesh gets a slightly smaller football relative to the
	# approved player sprites. 2D ball radius, contacts, saves and shots do
	# not change; the legacy 5v5 visual proportions stay untouched.
	var xi_ball: bool = match_node.match_team_size == 11
	sphere.radius = XI_BALL_VISUAL_RADIUS if xi_ball else LEGACY_BALL_VISUAL_RADIUS
	sphere.height = sphere.radius * 2.0
	ball_node.mesh = sphere
	# The same original dark-panel ball stays recognizable in flight and
	# between the keeper's pale gloves; only its visual material changes.
	var ball_material := _material(Color.WHITE, 0.40)
	ball_material.albedo_texture = preload("res://assets/ball/football_panels.svg")
	ball_node.material_override = ball_material
	ball_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ball_node)

	ball_shadow = MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	# Match the slightly smaller XI footprint without changing its physics.
	shadow_mesh.top_radius = 0.082 if xi_ball else 0.105
	shadow_mesh.bottom_radius = 0.082 if xi_ball else 0.105
	shadow_mesh.height = 0.008
	ball_shadow.mesh = shadow_mesh
	ball_shadow.material_override = _material(Color(0.012, 0.020, 0.015), 1.0)
	ball_shadow.position.y = 0.010
	add_child(ball_shadow)

	penalty_aim_marker = MeshInstance3D.new()
	penalty_aim_marker.name = "PenaltyAimMarker"
	var aim_mesh := TorusMesh.new()
	aim_mesh.inner_radius = 0.20 if xi_ball else 0.12
	aim_mesh.outer_radius = 0.29 if xi_ball else 0.20
	penalty_aim_marker.mesh = aim_mesh
	penalty_aim_marker.material_override = _material(Color(1.0, 0.73, 0.16), 0.28)
	penalty_aim_marker.position.y = GOAL_POST_HEIGHT * 0.55 if xi_ball else 0.040
	penalty_aim_marker.rotation.z = PI * 0.5 if xi_ball else 0.0
	penalty_aim_marker.visible = false
	penalty_aim_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(penalty_aim_marker)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 37.5
	camera.near = 0.08
	camera.far = 90.0
	add_child(camera)
	var focus := world_to_stage(match_node.ball.global_position)
	smoothed_focus_x = focus.x
	smoothed_lead_x = 0.0
	last_camera_mode = "broadcast"
	var xi: bool = match_node.match_team_size == 11
	camera.position = Vector3(
		focus.x,
		BROADCAST_HEIGHT * (XI_BROADCAST_HEIGHT_SCALE if xi else 1.0),
		BROADCAST_DEPTH * (XI_BROADCAST_DEPTH_SCALE if xi else 1.0),
	)
	camera.look_at(Vector3(focus.x, 0.0, -0.85), Vector3.UP)

func _add_box(position_3d: Vector3, size_3d: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_3d
	instance.mesh = box
	instance.position = position_3d
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)
	return instance

func world_to_stage(world: Vector2, height: float = 0.0) -> Vector3:
	var center := ChessFootballMath.PITCH_RECT.get_center()
	return Vector3(
		(world.x - center.x) * WORLD_SCALE,
		height,
		(world.y - center.y) * WORLD_SCALE
	)

# A verified R2 catch should not erase the real 0.58s save pose on the
# very first frame of a successful save. Normal possession catches (without
# a save), fallback atlases and the old 5v5 path keep their existing timing.
static func xi_keeper_dive_before_catch(
	team_size: int, is_holding: bool, has_r2_catch: bool, save_active: bool
) -> bool:
	return team_size == 11 and is_holding and has_r2_catch and save_active


func sync_presentation(delta: float, mode: String) -> void:
	# Size compensation must use the camera pose from this same frame, not
	# yesterday's interpolated pose; otherwise footballers visibly pulse.
	_sync_camera(delta, mode)
	_sync_goal_ad_panels()
	var holding_keeper: Footballer = match_node.ball.carrier
	if holding_keeper != null and holding_keeper.role != "keeper":
		holding_keeper = null
	for team in match_node.teams:
		for player in team:
			var key: int = int(player.get_instance_id())
			var proxy: Node3D = player_nodes.get(key)
			var sprite: AnimatedSprite3D = player_sprites.get(key)
			if proxy == null or sprite == null:
				continue
			proxy.visible = not player.sent_off
			if player.sent_off:
				continue
			proxy.position = world_to_stage(player.global_position)
			if player.visual != null:
				var wanted_animation := StringName(player.visual.animation)
				# XI's VISIBLE off-ball raster must reflect physical movement even
				# if the hidden 2D sprite briefly remains in an idle state. Keep
				# possession/carry, locked actions, keeper and 5v5 rendering intact.
				if (
					match_node.match_team_size == 11
					and player.role != "keeper"
					and not player.has_ball
					and match_node.ball.carrier != player
					and player.action_lock_seconds <= 0.0
				):
					wanted_animation = xi_outfield_motion_animation(
						player.velocity, player.last_sprinting
					)
				# Keep locomotion animations in phase with the authoritative 2D actor.
				# Non-locomotion actions preserve their established side-facing frames.
				var run_view := ChessFootballRunDirection.view_for_velocity(
					player.velocity, String(player_run_views.get(key, "front"))
				)
				player_run_views[key] = run_view
				var directional_animation := ChessFootballRunDirection.animation_for(wanted_animation, run_view)
				if sprite.sprite_frames.has_animation(directional_animation):
					wanted_animation = directional_animation
				# Side-facing real ball carriers may use verified 3D-only
				# carry/dribble poses. Gameplay and other facing views are untouched.
				var carrier_action := ChessFootballCarryDribbleR2.animation_for(
					wanted_animation, run_view, player.role,
					player.has_ball and match_node.ball.carrier == player,
					player.dribble_active(),
				)
				if sprite.sprite_frames.has_animation(carrier_action):
					wanted_animation = carrier_action
				# The new action pack is side-only and never overrides a shot,
				# keeper action, normal carry or an unapproved/failed R2 sheet.
				var action_pose := ChessFootballActionPosesR2.animation_for(
					wanted_animation, run_view, player.role,
					player.has_ball and match_node.ball.carrier == player,
					player.dribble_active(), player.dribble_mode
				)
				if sprite.sprite_frames.has_animation(action_pose):
					wanted_animation = action_pose
				# The verified R2 cut/burst atlas contains a real planted-foot
				# action, but was previously restricted to lateral running.
				# For a real XI front/diagonal dribble, briefly turn the body
				# into that authored planted stance before returning to the
				# correct directional runner. A non-Web/local R2 miss retains
				# the existing directional fallback without any proxy art.
				if match_node.match_team_size == 11 and player.role != "keeper":
					var pivot_progress := 1.0 - clampf(
						player.dribble_burst_seconds / maxf(player.dribble_duration_seconds, 0.001),
						0.0, 1.0
					)
					var pivot_pose := xi_verified_dribble_pivot_animation(
						wanted_animation, run_view, player.role,
						player.has_ball and match_node.ball.carrier == player,
						player.dribble_active(), player.dribble_mode, pivot_progress,
						_action_poses_r2_loaded.has("%d:dribble_cut" % player.team_id),
						_action_poses_r2_loaded.has("%d:dribble_burst" % player.team_id)
					)
					if sprite.sprite_frames.has_animation(pivot_pose):
						wanted_animation = pivot_pose
				var save_before_catch := xi_keeper_dive_before_catch(
					match_node.match_team_size, player == holding_keeper,
					_keeper_catch_r2_loaded.has(int(player.team_id)),
					player.keeper_save_active()
				)
				var authored_catch: bool = (
					player.role == "keeper" and player == holding_keeper
					and _keeper_catch_r2_loaded.has(int(player.team_id))
					and not save_before_catch
				)
				if authored_catch:
					if sprite.animation != &"keeper_catch":
						sprite.play(&"keeper_catch")
						sprite.pause()
					# Follow the same visual-only grip clock as the single 3D ball.
					var grip_ratio := clampf(
						keeper_catch_elapsed / KEEPER_CATCH_BLEND_SECONDS, 0.0, 1.0
					)
					sprite.frame = clampi(int(floorf(grip_ratio * 7.0)), 0, 7)
				else:
					_sync_visible_animation(key, player, sprite, wanted_animation, delta)
				if player.role == "keeper":
					# The approved front/back keeper atlas does not alternate which
					# leg leads strongly enough. Mirroring only the second half of
					# those symmetric views yields a real left/right step without
					# generating art or flipping the oblique facing direction.
					var direct_view := String(wanted_animation)
					var symmetric_run := direct_view in [
						"run_front", "run_back", "sprint_front", "sprint_back"
					]
					var alternate_leg := (
						symmetric_run
						and sprite.frame >= sprite.sprite_frames.get_frame_count(wanted_animation) / 2
					)
					sprite.flip_h = player.visual.flip_h != alternate_leg
				else:
					# The feint has two opposed boot plants. The R2 lateral
					# pose used for front/diagonal XI turns previously showed
					# the same shoulder/leg orientation in both halves, even
					# while the physical ball visibly changed sides. Reverse
					# ONLY the painted second plant; the real facing, running
					# view, ball ownership and 2D game stay authoritative.
					var feint_progress := 1.0 - clampf(
						player.dribble_burst_seconds / maxf(player.dribble_duration_seconds, 0.001),
						0.0, 1.0
					)
					sprite.flip_h = xi_feint_pivot_mirror(
						player.visual.flip_h, match_node.match_team_size,
						run_view, player.role,
						player.has_ball and match_node.ball.carrier == player,
						player.dribble_active(), player.dribble_mode,
						wanted_animation, feint_progress
					)
			sprite.pixel_size = TACTICAL_PLAYER_PIXEL_SIZE if mode == "tactical" else PLAYER_PIXEL_SIZE
			_sync_player_secondary_motion(player, sprite, proxy, delta)
			var tone_gain := _tonal_view_gain(sprite)
			sprite.modulate = Color(tone_gain, tone_gain, tone_gain, 1.0)
			# Broadcast's steeply pitched camera projects vertical bodies
			# differently across near/far touchlines even after correcting
			# camera-forward distance. Match the actual on-screen projected
			# height, not an approximate depth ratio; keep legacy 5v5/tactical.
			var depth_scale := (
				xi_projected_body_scale(camera, proxy.global_position)
				if match_node.match_team_size == 11 and mode == "broadcast"
				else perspective_body_scale(camera, proxy.global_position)
			)
			# Apply to both axes AFTER each authored-view/role correction. Boot
			# baseline must also be scaled, or feet sink as players cross depth.
			var authored_y := sprite.scale.y
			sprite.scale.x *= depth_scale
			sprite.scale.y *= depth_scale
			var cell_half_height := ChessFootballSpriteBank.cell_size().y * 0.5
			var foot_y := (
				ChessFootballSpriteBank.frame_bottom(
					sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
				) - cell_half_height
			)
			sprite.position.y += foot_y * sprite.pixel_size * (sprite.scale.y - authored_y)
			# XI bodies grow toward the far touchline to compensate projection,
			# but their contact shadows used to keep the unscaled world footprint.
			# Distant players then looked detached from tiny ground marks. Match
			# the shadow's planar footprint to the same bounded body correction.
			# The motion pass resets shadow.scale every tick, so this cannot
			# accumulate; neither physical collision nor 5v5 is affected.
			if match_node.match_team_size == 11:
				var contact_shadow := proxy.get_node_or_null("ContactShadow") as MeshInstance3D
				if contact_shadow != null:
					contact_shadow.scale.x *= depth_scale
					contact_shadow.scale.z *= depth_scale
			# A visible XI QuadMesh uses the original animation frame, position,
			# mirroring and footline. No separate animation or physics authority.
			var xi_quad: MeshInstance3D = xi_raster_meshes.get(key)
			if xi_quad != null:
				var panel: QuadMesh = xi_quad.mesh
				var canvas: StandardMaterial3D = xi_quad.material_override
				var current_frame: Texture2D = _xi_frame_texture(player, sprite)
				if canvas.albedo_texture != current_frame:
					canvas.albedo_texture = current_frame
				var frame_size := Vector2(current_frame.get_width(), current_frame.get_height()) * sprite.pixel_size
				if panel.size != frame_size:
					panel.size = frame_size
				var flip_u: bool = sprite.flip_h
				var target_uv_scale := Vector3(-1.0, 1.0, 1.0) if flip_u else Vector3.ONE
				var target_uv_offset := Vector3(1.0, 0.0, 0.0) if flip_u else Vector3.ZERO
				if canvas.uv1_scale != target_uv_scale:
					canvas.uv1_scale = target_uv_scale
					canvas.uv1_offset = target_uv_offset
				# Keep tactical silhouettes fully visible to the overhead camera
				# while anchoring the *same* boot pixel to the ground shadow.
				# Broadcast uses a genuinely upright billboard; tactical
				# faces the camera with a compensating 3D centre translation.
				var tactical_billboard := mode == "tactical"
				var wanted_billboard := (
					BaseMaterial3D.BILLBOARD_ENABLED if tactical_billboard
					else BaseMaterial3D.BILLBOARD_FIXED_Y
				)
				if canvas.billboard_mode != wanted_billboard:
					canvas.billboard_mode = wanted_billboard
				# Keep the actual tilted boot pixel (not just the unrotated
				# frame bottom) pinned above the contact decal at every depth.
				# The sprite driver stays hidden in XI; only this quad is offset.
				var body_offset := xi_rotated_foot_anchor_offset(
					camera, current_frame, sprite.pixel_size, sprite.scale.y,
					sprite.rotation.z, tactical_billboard
				)
				var wanted_position := sprite.position + body_offset
				if xi_quad.position != wanted_position:
					xi_quad.position = wanted_position
				if xi_quad.rotation != sprite.rotation:
					xi_quad.rotation = sprite.rotation
				if xi_quad.scale != sprite.scale:
					xi_quad.scale = sprite.scale
				if canvas.albedo_color != sprite.modulate:
					canvas.albedo_color = sprite.modulate
			# The existing secondary motion includes deliberate running bob,
			# which stays independent from depth and untouched here.
			var is_controlled: bool = player == match_node.controlled
			# The XI body and its contact shadow already compensate for
			# camera depth, but the controlled-player/receiver rings were
			# still fixed-world-size. Match their ground footprint to that
			# same visible body so a winger's yellow ring does not shrink
			# relative to his boots at the far touchline. 5v5 is unchanged.
			var marker_depth: float = depth_scale if match_node.match_team_size == 11 else 1.0
			var marker_footprint := Vector3(marker_depth, 1.0, marker_depth)
			var active_disc := proxy.get_node_or_null("ActiveDisc") as MeshInstance3D
			if active_disc != null:
				active_disc.visible = is_controlled
				if active_disc.scale != marker_footprint:
					active_disc.scale = marker_footprint
			var receiver_disc := proxy.get_node_or_null("SetPieceReceiverDisc") as MeshInstance3D
			if receiver_disc != null:
				if receiver_disc.scale != marker_footprint:
					receiver_disc.scale = marker_footprint
				receiver_disc.visible = (
					match_node.human_set_piece_available()
					and not match_node.pause_menu_open
					and player.team_id == 0
					and player != match_node.set_piece_player
					and player.role != "keeper"
					and not player.sent_off
				)
			var stamina_back := proxy.get_node_or_null("StaminaBack") as MeshInstance3D
			var stamina_fill := proxy.get_node_or_null("StaminaFill") as MeshInstance3D
			var stamina_ratio: float = player.stamina_ratio()
			var show_stamina: bool = is_controlled and (player.last_sprinting or stamina_ratio < 0.995)
			if stamina_back != null:
				stamina_back.visible = show_stamina
			if stamina_fill != null:
				stamina_fill.visible = show_stamina
				var fill_ratio: float = maxf(0.015, stamina_ratio)
				stamina_fill.scale.x = fill_ratio
				stamina_fill.position.x = -STAMINA_BAR_WIDTH * 0.5 * (1.0 - fill_ratio)

	# Front/diagonal XI dribbles need a readable ball *touch*, not just a
	# shoulder lean. Keep the rendered ball and its contact shadow together.
	# Never move the actual 2D ball, its collision, or keeper possession.
	var dribble_ball_offset := Vector3.ZERO
	if match_node.match_team_size == 11 and holding_keeper == null:
		var ball_carrier: Footballer = match_node.ball.carrier
		if (
			ball_carrier != null and ball_carrier.role != "keeper"
			and ball_carrier.has_ball and ball_carrier.dribble_active()
		):
			var dribble_progress := 1.0 - clampf(
				ball_carrier.dribble_burst_seconds / maxf(ball_carrier.dribble_duration_seconds, 0.001),
				0.0, 1.0
			)
			dribble_ball_offset = xi_dribble_visual_ball_offset(
				ball_carrier.dribble_mode, dribble_progress, ball_carrier.dribble_direction
			)
			# Match the real overhead lens, not an arbitrary world-unit
			# multiplier. A small native-pixel countertouch stays readable in
			# tactical without inflating broadcast or changing the 2D ball.
			# The sinusoidal target fades to zero with the authoritative action.
			if mode == "tactical" and dribble_ball_offset.length_squared() > 0.000001:
				var ball_anchor := world_to_stage(
					match_node.ball.global_position,
					XI_BALL_VISUAL_RADIUS + BALL_VISUAL_GROUND_CLEARANCE
				)
				var start_px := camera.unproject_position(ball_anchor)
				var moved_px := camera.unproject_position(ball_anchor + dribble_ball_offset)
				var projected_pixels := start_px.distance_to(moved_px)
				if projected_pixels > 0.001:
					var target_pixels := 6.25 * maxf(0.0, sin(PI * dribble_progress))
					dribble_ball_offset *= clampf(
						target_pixels / projected_pixels, 1.0, 3.25
					)

	if ball_node != null:
		var grip_progress := 1.0
		# Keep clearance above the grass constant as visual radius changes;
		# otherwise a smaller rolling ball appears to hover over its shadow.
		var visual_radius: float = (
			XI_BALL_VISUAL_RADIUS if match_node.match_team_size == 11
			else LEGACY_BALL_VISUAL_RADIUS
		)
		var ground_center_y: float = visual_radius + BALL_VISUAL_GROUND_CLEARANCE
		var ball_at := world_to_stage(
			match_node.ball.global_position,
			ground_center_y + float(match_node.ball.flight_height) * WORLD_SCALE,
		)
		if holding_keeper != null:
			var current_keeper_id := int(holding_keeper.get_instance_id())
			# Authored palms meet around the centre of the chest. The old
			# side-offset remains untouched for the fallback glove rig.
			var catch_offset := (
				0.0 if _keeper_catch_r2_loaded.has(int(holding_keeper.team_id))
				else KEEPER_CATCH_SIDE * holding_keeper.keeper_save_direction
			)
			var target := (
				world_to_stage(holding_keeper.global_position, KEEPER_CATCH_HEIGHT)
				+ Vector3(catch_offset, 0.0, KEEPER_CATCH_FRONT)
			)
			if keeper_catch_carrier_id != current_keeper_id:
				keeper_catch_carrier_id = current_keeper_id
				keeper_catch_elapsed = 0.0
				# The previously rendered ball can be in an old scene/restart
				# or at the outer edge of the save radius. Keep visual contact
				# inside arm's reach so no hand turns into a telescopic pole.
				keeper_catch_origin = target + (
					ball_node.position - target
				).limit_length(KEEPER_CATCH_START_REACH)
			var dive_before_catch := xi_keeper_dive_before_catch(
				match_node.match_team_size, true,
				_keeper_catch_r2_loaded.has(int(holding_keeper.team_id)),
				holding_keeper.keeper_save_active()
			)
			if dive_before_catch:
				# The ball has ALREADY been legally saved and attached by the 2D
				# match. Follow the keeper's existing dive sway; do not invent
				# a second ball, delay possession or extend the save radius.
				var save_phase := 1.0 - holding_keeper.keeper_save_ratio()
				var reach := sin(PI * save_phase) * XI_KEEPER_SAVE_BALL_REACH
				var hand_target := target + Vector3(
					holding_keeper.keeper_save_direction * reach, 0.0, 0.0
				)
				# Do not snap the ball straight from the save contact point to
				# chest height on the first rendered dive frame. Track the hands
				# within the same bounded 0.18-second visual catch interval.
				keeper_catch_origin = keeper_catch_origin.lerp(
					hand_target,
					clampf(maxf(0.0, delta) / KEEPER_CATCH_BLEND_SECONDS, 0.0, 1.0)
				)
				ball_at = keeper_catch_origin
				keeper_catch_elapsed = 0.0
				grip_progress = 0.0
			else:
				# Only once the save has finished does the R2 eight-frame
				# reception begin, blending from the last saved-ball position.
				keeper_catch_elapsed += maxf(0.0, delta)
				var progress := smoothstep(
					0.0, 1.0,
					clampf(keeper_catch_elapsed / KEEPER_CATCH_BLEND_SECONDS, 0.0, 1.0),
				)
				ball_at = keeper_catch_origin.lerp(target, progress)
				grip_progress = progress
		else:
			keeper_catch_carrier_id = 0
			keeper_catch_elapsed = 0.0
		# A real frontal/diagonal XI R2 plant should touch the SINGLE
		# displayed ball, not leave it stranded at the far diagonal
		# possession anchor. Keep the physical 2D ball unchanged; keep
		# its 3D grass shadow on the exact same corrected path.
		var feint_carrier: Footballer = match_node.ball.carrier
		if (
			feint_carrier != null and holding_keeper == null
			and match_node.match_team_size == 11
			and feint_carrier.role != "keeper"
			and feint_carrier.has_ball and feint_carrier.dribble_active()
			and feint_carrier.dribble_mode == "feint"
			and _action_poses_r2_loaded.has("%d:dribble_cut" % feint_carrier.team_id)
			and String(player_run_views.get(feint_carrier.get_instance_id(), "side")) in [
				"front", "back", "front_diagonal", "back_diagonal"
			]
		):
			var feint_progress := 1.0 - clampf(
				feint_carrier.dribble_burst_seconds /
					maxf(feint_carrier.dribble_duration_seconds, 0.001),
				0.0, 1.0
			)
			var foot_anchor := world_to_stage(feint_carrier.global_position, ground_center_y)
			var corrected_ball := xi_feint_display_foot_contact(
				ball_at + dribble_ball_offset, foot_anchor,
				feint_carrier.dribble_direction, feint_carrier.team_id,
				feint_carrier.visual.flip_h, feint_progress
			)
			dribble_ball_offset = corrected_ball - ball_at
		ball_node.position = ball_at + dribble_ball_offset
		_sync_ball_visual_roll(delta)
		_sync_keeper_catch_hands(holding_keeper, ball_at, grip_progress)
	if ball_shadow != null:
		# The carried ball is not simultaneously painted at the keeper's boots.
		ball_shadow.visible = holding_keeper == null
		if ball_shadow.visible:
			ball_shadow.position = world_to_stage(match_node.ball.global_position, 0.010) + dribble_ball_offset
			var shadow_scale: float = lerpf(1.0, 0.62, clampf(float(match_node.ball.flight_height) / 90.0, 0.0, 1.0))
			ball_shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

	if penalty_aim_marker != null:
		penalty_aim_marker.visible = match_node.penalty_preview_visible()
		if penalty_aim_marker.visible:
			if match_node.match_team_size == 11:
				var aim_direction: float = 1.0 if match_node.set_piece_team_id == 0 else -1.0
				penalty_aim_marker.position = world_to_stage(
					match_node.penalty_preview_target(),
					GOAL_POST_HEIGHT * 0.55,
				) + Vector3(-aim_direction * 0.08, 0.0, 0.0)
			else:
				penalty_aim_marker.position = world_to_stage(
					match_node.penalty_preview_target(),
					0.045,
				)


# Given a 2D movement (X along the field, Y across it), the matching 3D
# movement is (X, 0, Z). Up cross travel gives the horizontal rolling axis;
# a fixed Z-axis spin visibly rolls sideways during vertical passes.
static func ball_roll_axis(velocity: Vector2) -> Vector3:
	if velocity.length_squared() <= 0.001:
		return Vector3.ZERO
	return Vector3(velocity.y, 0.0, -velocity.x).normalized()


func _sync_ball_visual_roll(delta: float) -> void:
	if ball_node == null or delta <= 0.0:
		return
	var velocity: Vector2 = match_node.ball.velocity
	if match_node.ball.carrier != null:
		var owner: Footballer = match_node.ball.carrier
		# XI carries are rolling ground touches, not a stationary ball
		# magnetically following the boots. Keep held keeper balls and
		# historical five-a-side rendering exactly as before.
		if owner.match_pitch != FootballMatchFormation.ELEVEN_PITCH_RECT or owner.role == "keeper":
			return
		velocity = owner.velocity
	var axis := ball_roll_axis(velocity)
	if axis == Vector3.ZERO:
		return
	ball_node.rotate(axis, velocity.length() * delta * BALL_VISUAL_SPIN_PER_PIXEL)


static func _keeper_locomotion(animation_name: StringName) -> bool:
	var name := String(animation_name)
	return name == "run" or name == "sprint" or name.begins_with("run_") or name.begins_with("sprint_")


# A full XI gait needs to cover roughly the same amount of turf each cycle.
# A fixed FPS makes decelerating players keep pedalling at running speed,
# even though the 2D actor's real velocity is dropping. Advance the VISIBLE
# outfield pose by actual displacement only. This supports future 12-pose
# atlases without pretending that the current approved 8 poses are new art.
# Keep 5v5, keeper clocks, match physics and every authored atlas untouched.
# The XI raster must follow actual CharacterBody2D movement, rather than
# relying on the hidden 2D animation state during support/AI transitions.
static func xi_outfield_motion_animation(
	movement: Vector2, sprinting: bool
) -> StringName:
	if movement.length_squared() < 12.0 * 12.0:
		return &"idle"
	return &"sprint" if sprinting else &"run"


# Normal off-ball support movement is usually 60-85% of maximum pace.
# The old 168/180 world-pixel gait covered multiple boot-lengths per loop,
# making teammates move across the grass before the next foot plant.
# Only the XI NON-CARRIER shortens that cycle; attackers with the ball,
# goalkeepers and historical 5v5 keep their existing cadence and assets.
const XI_OFFBALL_RUN_CYCLE_PX := 112.0
const XI_OFFBALL_SPRINT_CYCLE_PX := 132.0


static func xi_offball_stride_advance(
	travel_speed: float, delta: float, frame_count: int,
	base_fps: float, sprinting: bool
) -> float:
	if travel_speed <= 0.0 or delta <= 0.0 or frame_count < 1 or base_fps <= 0.0:
		return 0.0
	var cycle_px: float = (
		XI_OFFBALL_SPRINT_CYCLE_PX if sprinting else XI_OFFBALL_RUN_CYCLE_PX
	)
	var fps: float = travel_speed * float(frame_count) / cycle_px
	# Never skip a painted pose when the Web renderer/physics slows down:
	# a 12-frame sprint can otherwise jump 2-3 images in a 15-20 FPS tick,
	# especially for fast non-carriers. Prioritize completing EVERY pose
	# over catching up the visual gait during a slow frame. This is
	# presentation-only; movement, stamina and tackles remain untouched.
	return minf(delta * minf(fps, base_fps * 1.35), 0.99)


static func xi_outfield_stride_advance(
	travel_speed: float, delta: float, frame_count: int,
	base_fps: float, sprinting: bool
) -> float:
	if travel_speed <= 0.0 or delta <= 0.0 or frame_count < 1 or base_fps <= 0.0:
		return 0.0
	var cycle_travel_px := 180.0 if sprinting else 168.0
	var stride_fps := travel_speed * float(frame_count) / cycle_travel_px
	return delta * minf(stride_fps, base_fps * 1.35)


# Draw every original pass/shot pose in its actual lock window. For a
# 0.58-second pass the old fixed 10-FPS clock only reached ~frame 5/8.
# The visual phase uses the same lock that already controls gameplay;
# never prolong the kick or delay the authoritative ball release.
# A short, intentional pivot reveals the original authored side-action
# FOOTWORK for the otherwise unanimated front/diagonal XI dribble. This does
# not claim to be a new front atlas; it is a body turn during the genuine
# possession window. Outside the planted interval and without fully verified
# R2 action art the player's directional runner stays canonical.
static func xi_verified_dribble_pivot_animation(
	base: StringName, view: String, role: String,
	owns_ball: bool, active: bool, mode: String, progress: float,
	has_cut: bool, has_burst: bool
) -> StringName:
	if (
		role == "keeper" or not owns_ball or not active
		or view not in ["front", "back", "front_diagonal", "back_diagonal"]
		or base not in [
			&"run_front", &"run_back", &"run_front_diagonal", &"run_back_diagonal",
			&"sprint_front", &"sprint_back", &"sprint_front_diagonal", &"sprint_back_diagonal"
		]
	):
		return base
	var t := clampf(progress, 0.0, 1.0)
	if mode == "feint":
		return &"dribble_cut" if has_cut and t >= 0.14 and t <= 0.86 else base
	if mode == "cut":
		return &"dribble_cut" if has_cut and t >= 0.16 and t <= 0.87 else base
	if mode == "burst":
		return &"dribble_burst" if has_burst and t >= 0.12 and t <= 0.87 else base
	return base


# A real front/diagonal feint sells one painted R2 side step, then plants
# the opposite foot. The second half is a visual mirror of the SAME verified
# action texture, never a rotation or physical direction reversal. Other
# actions, keepers, five-a-side and fallback directional runs are untouched.
static func xi_feint_pivot_mirror(
	base_flip: bool, team_size: int, view: String, role: String,
	owns_ball: bool, active: bool, mode: String,
	animation: StringName, progress: float
) -> bool:
	if (
		team_size != 11 or role == "keeper" or not owns_ball or not active
		or mode != "feint" or animation != &"dribble_cut"
		or view not in ["front", "back", "front_diagonal", "back_diagonal"]
	):
		return base_flip
	# A clean two-beat counterstep: at the mid-point the shoulder and
	# support foot commit to the opposite side while the ball follows.
	return base_flip != (clampf(progress, 0.0, 1.0) >= 0.5)


# The real feint lasts only 0.24s: playing all eight painted R2 frames
# at ~33 FPS skips most of them on a 15-20 FPS Web client. Hold the two
# actual contact poses instead, so both planted steps are sampled at low
# frame rate. The countdown remains the ONLY clock; no gameplay slowdown.
static func xi_feint_r2_contact_pose(frame_count: int, progress: float) -> float:
	if frame_count < 6:
		return 0.0
	var t := clampf(progress, 0.0, 1.0)
	var fraction := 0.36 if t < 0.5 else 0.72
	return float(clampi(
		int(floorf(float(frame_count - 1) * fraction)), 0, frame_count - 1
	))


# An in-place front/diagonal feint must actually change the planted LEG,
# not just tilt the same running frame. Two opposite painted strides from the
# existing approved directional atlas follow the authoritative countdown.
# Side-facing approved R2 poses and normal locomotion keep their own clock.
static func xi_front_feint_foot_pose(frame_count: int, progress: float) -> float:
	if frame_count < 2:
		return 0.0
	var stride := 0.25 if progress < 0.5 else 0.75
	return float(clampi(int(floorf(float(frame_count) * stride)), 0, frame_count - 1))


static func xi_complete_action_phase(
	frame_count: int, total_seconds: float, remaining_seconds: float
) -> float:
	if frame_count < 1 or total_seconds <= 0.0:
		return 0.0
	var progress: float = clampf(
		1.0 - remaining_seconds / total_seconds, 0.0, 1.0
	)
	return minf(float(frame_count - 1), floorf(progress * float(frame_count)))


func _sync_visible_animation(
	key: int, player: Footballer, sprite: AnimatedSprite3D, wanted: StringName, delta: float
) -> void:
	# Keepers already use a dedicated visible raster clock; outfield actors
	# must use the same strategy or their 3D poses can freeze while the hidden
	# 2D game actor stays on a stale frame. Gameplay, actions and speed remain
	# authoritative in the 2D actor; only raster frame timing lives here.
	var frames := sprite.sprite_frames
	if not frames.has_animation(wanted):
		return
	var count := frames.get_frame_count(wanted)
	if count < 1:
		return
	var is_keeper := player.role == "keeper"
	var phases: Dictionary = keeper_visual_phases if is_keeper else outfield_visual_phases
	var names: Dictionary = keeper_visual_names if is_keeper else outfield_visual_names
	var previous: StringName = names.get(key, &"")
	var phase: float = float(phases.get(key, 0.0))
	if previous != wanted or sprite.animation != wanted:
		var keep_run_phase := _keeper_locomotion(previous) and _keeper_locomotion(wanted)
		var keep_idle_phase := String(previous).begins_with("idle") and String(wanted).begins_with("idle")
		if not keep_run_phase and not keep_idle_phase:
			phase = 0.0
			if not is_keeper and _keeper_locomotion(wanted):
				# Retain the roster's deterministic staggered starting stride.
				# Subsequent turns and run/sprint switches keep the live 3D phase.
				phase = float(player.visual.frame)
		sprite.play(wanted)
		# Never race Godot's built-in AnimatedSprite3D clock against physics.
		sprite.pause()
		names[key] = wanted
	var advance := maxf(delta, 0.0) * frames.get_animation_speed(wanted)
	if (
		match_node.match_team_size == 11 and not is_keeper
		and player.has_ball and player.dribble_active() and player.dribble_mode == "feint"
		and String(wanted) in [
			"run_front", "run_front_diagonal", "run_back", "run_back_diagonal",
			"sprint_front", "sprint_front_diagonal", "sprint_back", "sprint_back_diagonal"
		]
	):
		var feint_progress := 1.0 - clampf(
			player.dribble_burst_seconds / maxf(player.dribble_duration_seconds, 0.001),
			0.0, 1.0
		)
		phase = xi_front_feint_foot_pose(count, feint_progress)
	elif _keeper_locomotion(wanted):
		# Movement-phase continuity survives turns and run/sprint switches.
		# A stationary actor must not run in place.
		if player.velocity.length() >= 12.0:
			if not is_keeper and match_node.match_team_size == 11:
				var visible_sprinting: bool = String(wanted).begins_with("sprint")
				var off_ball: bool = (
					not player.has_ball and match_node.ball.carrier != player
				)
				# Shorter off-ball footstep distance means actual AI support runs
				# visibly cycle through all the painted leg poses, rather than
				# drifting across the grass with a slow, disconnected gait.
				if off_ball:
					phase += xi_offball_stride_advance(
						player.velocity.length(), delta, count,
						frames.get_animation_speed(wanted), visible_sprinting
					)
				else:
					phase += xi_outfield_stride_advance(
						player.velocity.length(), delta, count,
						frames.get_animation_speed(wanted), visible_sprinting
					)
			else:
				phase += advance * maxf(player.visual.speed_scale, 0.0)
	elif String(wanted).begins_with("idle"):
		# Old one-frame fallback holds; new eight-frame R2 idle breathes in place.
		if count > 1:
			phase += advance
	elif (
		match_node.match_team_size == 11
		and not is_keeper and player.has_ball
		and wanted == &"dribble_cut" and player.dribble_mode == "feint"
		and player.dribble_active()
		and String(player_run_views.get(key, "side")) in [
			"front", "back", "front_diagonal", "back_diagonal"
		]
	):
		var planted_progress := 1.0 - clampf(
			player.dribble_burst_seconds / maxf(player.dribble_duration_seconds, 0.001),
			0.0, 1.0
		)
		phase = xi_feint_r2_contact_pose(count, planted_progress)
	elif (
		match_node.match_team_size == 11
		and not is_keeper
		and wanted in [&"dribble_cut", &"dribble_burst"]
		and player.dribble_active()
	):
		phase = xi_complete_action_phase(
			count, player.dribble_duration_seconds, player.dribble_burst_seconds
		)
	elif (
		match_node.match_team_size == 11
		and not is_keeper
		and (
			wanted in [&"pass", &"shoot"]
			or (
				wanted in [&"tackle", &"slide_tackle"]
				and _action_poses_r2_loaded.has(
					"%d:%s" % [player.team_id, String(wanted)]
				)
			)
		)
		and player.action_lock_seconds > 0.0
		and player.action_visual_duration_seconds > 0.0
	):
		phase = xi_complete_action_phase(
			count, player.action_visual_duration_seconds, player.action_lock_seconds
		)
	else:
		phase += advance * maxf(player.visual.speed_scale, 0.0)
	if frames.get_animation_loop(wanted):
		phase = fposmod(phase, float(count))
	else:
		phase = minf(phase, float(count - 1))
	phases[key] = phase
	sprite.frame = clampi(int(floorf(phase)), 0, count - 1)


static func view_compensation(animation_name: StringName) -> Vector2:
	var name := String(animation_name)
	if name in [
		"run_front_diagonal", "run_back_diagonal",
		"sprint_front_diagonal", "sprint_back_diagonal",
	]:
		return Vector2(DIAGONAL_WIDTH_COMPENSATION, 1.0)
	return Vector2.ONE


static func xi_v3_diagonal_width_trim(
	animation_name: StringName, team_size: int, is_keeper: bool, v3_loaded: bool
) -> float:
	if team_size != 11 or is_keeper or not v3_loaded:
		return 1.0
	var name := String(animation_name)
	if name in [
		"run_front_diagonal", "run_back_diagonal",
		"sprint_front_diagonal", "sprint_back_diagonal",
	]:
		return XI_V3_DIAGONAL_WIDTH_TRIM
	return 1.0


# The broadcast camera is pitched toward the grass. Depth-ratio scaling
# alone does not equalize projected body height: the visible vertical span
# also changes with a footballer's lane (especially the NEAR touchline).
# Measure a ground-to-head reference segment through the actual camera.
# Keeping a single projected height across lanes avoids shrinking wingers;
# fixed-world gameplay coordinates, physical contact and PNGs are untouched.
static func xi_projected_body_scale(view_camera: Camera3D, stage_position: Vector3) -> float:
	if view_camera == null or view_camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return 1.0
	var ground := Vector3(stage_position.x, 0.02, stage_position.z)
	var head := ground + Vector3.UP * 1.48
	var reference := Vector3(view_camera.global_position.x, 0.02, 0.0)
	var reference_head := reference + Vector3.UP * 1.48
	if view_camera.is_position_behind(ground) or view_camera.is_position_behind(head):
		return 1.0
	if view_camera.is_position_behind(reference) or view_camera.is_position_behind(reference_head):
		return 1.0
	var projected: float = view_camera.unproject_position(ground).distance_to(
		view_camera.unproject_position(head)
	)
	var reference_pixels: float = view_camera.unproject_position(reference).distance_to(
		view_camera.unproject_position(reference_head)
	)
	if projected < 0.01 or reference_pixels < 0.01:
		return 1.0
	return clampf(
		reference_pixels / projected,
		MIN_PERSPECTIVE_BODY_SCALE, MAX_PERSPECTIVE_BODY_SCALE
	)


static func perspective_body_scale(view_camera: Camera3D, stage_position: Vector3) -> float:
	if view_camera == null or view_camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return 1.0
	# Use CAMERA FORWARD depth, not Euclidean distance: a player's horizontal
	# lane should not make them larger at the same pitch depth.
	var forward := -view_camera.global_transform.basis.z
	var reference_point := Vector3(view_camera.global_position.x, PLAYER_BASE_Y, 0.0)
	var reference_depth := (reference_point - view_camera.global_position).dot(forward)
	var player_depth := (
		(stage_position + Vector3.UP * PLAYER_BASE_Y) - view_camera.global_position
	).dot(forward)
	if reference_depth <= 0.01 or player_depth <= 0.01:
		return 1.0
	return clampf(
		player_depth / reference_depth,
		MIN_PERSPECTIVE_BODY_SCALE, MAX_PERSPECTIVE_BODY_SCALE
	)


# Remote XI footballers occupy fewer screen pixels: dramatic synthetic body
# sway, lean and squash can move the boot silhouette off its contact decal.
# Smoothly reduce only the EXTRA procedural motion at far broadcast depth.
# Never change the authored atlas, the perspective body-size correction, or
# the 2D match movement; 5v5 keeps its existing appearance.
static func xi_distant_stride_weight(depth_scale: float) -> float:
	var remote: float = clampf((depth_scale - 1.0) / 0.55, 0.0, 1.0)
	var eased: float = remote * remote * (3.0 - 2.0 * remote)
	return lerpf(1.0, 0.35, eased)


static func _animation_luminance(frames: SpriteFrames, name: StringName) -> float:
	if not frames.has_animation(name):
		return 0.0
	var count := frames.get_frame_count(name)
	if count < 1:
		return 0.0
	var sample_indexes := [0, maxi(0, count / 2), count - 1]
	var total := 0.0
	for sample_index in sample_indexes:
		total += ChessFootballSpriteBank.frame_luminance(
			frames.get_frame_texture(name, sample_index)
		)
	return total / float(sample_indexes.size())


func _tonal_view_gain(sprite: AnimatedSprite3D) -> float:
	var frames := sprite.sprite_frames
	var key := "%d:%s" % [frames.get_instance_id(), String(sprite.animation)]
	if tone_gain_cache.has(key):
		return float(tone_gain_cache[key])
	var frontal := _animation_luminance(frames, &"run_front")
	var side := _animation_luminance(frames, &"run")
	var wanted := _animation_luminance(frames, sprite.animation)
	if frontal <= 0.01 or side <= 0.01 or wanted <= 0.01:
		return 1.0
	# Equalize within each sprite identity, not across different club colors
	# or skin tones. This deliberately preserves the approved painted shading.
	var target := (frontal + side) * 0.5
	var gain := clampf(target / wanted, 0.88, 1.12)
	tone_gain_cache[key] = gain
	return gain


static func normalized_body_scale(pixel_height: float) -> float:
	# The clamp fails safely on malformed or extremely short silhouettes;
	# smoke asserts that every approved source fits the expected body envelope.
	return clampf(CANONICAL_BODY_HEIGHT_PIXELS / maxf(pixel_height, 1.0), 0.80, 1.40)


func _canonical_body_scale(sprite: AnimatedSprite3D, role: String = "", team_id: int = -1) -> float:
	var current_name := String(sprite.animation)
	# In XI a verified animated R2 idle has eight breathing frames. Measuring
	# the CURRENT frame changes sprite scale each time the body moves, making
	# otherwise stationary players visibly swell/shrink. Use one stable
	# silhouette reference for the whole authored loop (no atlas edits).
	# One-frame historical idles and the legacy 5v5 retain their old path.
	if current_name == "idle" or current_name.begins_with("idle_"):
		var idle_frames := sprite.sprite_frames
		var idle_count := idle_frames.get_frame_count(sprite.animation)
		if match_node.match_team_size == 11 and idle_count > 1:
			var idle_key := "idle:%s:%d:%s" % [role, team_id, current_name]
			if body_scale_cache.has(idle_key):
				return float(body_scale_cache[idle_key])
			var idle_heights: Array[float] = []
			for frame_id in range(idle_count):
				var frame_texture := idle_frames.get_frame_texture(sprite.animation, frame_id)
				var frame_height := ChessFootballSpriteBank.frame_height(frame_texture)
				if frame_height < 60.0:
					push_error("Chess Football: invalid animated idle silhouette")
					return 1.0
				idle_heights.append(frame_height)
			idle_heights.sort()
			var mid := int(idle_heights.size() / 2)
			var reference_height := (
				(idle_heights[mid - 1] + idle_heights[mid]) * 0.5
				if idle_heights.size() % 2 == 0 else idle_heights[mid]
			)
			var fixed_scale := normalized_body_scale(reference_height)
			body_scale_cache[idle_key] = fixed_scale
			return fixed_scale
		var stance := idle_frames.get_frame_texture(sprite.animation, sprite.frame)
		var height := ChessFootballSpriteBank.frame_height(stance)
		if height >= 60.0:
			return normalized_body_scale(height)
	var view := "side"
	if current_name.begins_with("run_"):
		view = current_name.trim_prefix("run_")
	elif current_name.begins_with("sprint_"):
		view = current_name.trim_prefix("sprint_")
	var reference_name := ChessFootballRunDirection.animation_for(&"run", view)
	# The ball carrier sometimes uses an older, separately painted 8-pose
	# carry/dribble atlas instead of the 12-pose v3 running row. Measuring
	# its height from v3 'run' makes the player pop in size on possession.
	if current_name in ["carry", "dribble", "dribble_cut", "dribble_burst"]:
		reference_name = StringName(current_name)
	# Different club sheets and action sources must never share a cached
	# height; measure only once per family, not once per actor or frame.
	var cache_key := "%s:%d:%s" % [role, team_id, String(reference_name)]
	if body_scale_cache.has(cache_key):
		return float(body_scale_cache[cache_key])
	if not sprite.sprite_frames.has_animation(reference_name):
		push_error("Chess Football: missing approved run reference " + String(reference_name))
		return 1.0
	# Measure once per authored view from three cycle poses, not once per
	# player/frame. This avoids size pumping as legs alternate and avoids
	# repeated GPU readbacks during play.
	var heights: Array[float] = []
	var samples := [0, 3, 6] if sprite.sprite_frames.get_frame_count(reference_name) == 8 else [0, 4, 8]
	for frame_id in samples:
		var sample := sprite.sprite_frames.get_frame_texture(reference_name, frame_id) as ImageTexture
		if sample == null:
			push_error("Chess Football: non-raster canonical height sample")
			return 1.0
		var bounds := sample.get_image().get_used_rect()
		if bounds.size.y < 60:
			push_error("Chess Football: empty/invalid approved football silhouette")
			return 1.0
		heights.append(float(bounds.size.y))
	heights.sort()
	var scale := normalized_body_scale(heights[1])
	body_scale_cache[cache_key] = scale
	return scale


# A short body-only scrape across the planted contact shadow, driven by
# the authoritative action lock. Zero before/after contact so the sprite
# never teleports on return to running; no player/collider movement.
static func xi_slide_scrape_weight(total_seconds: float, remaining_seconds: float) -> float:
	if total_seconds <= 0.0 or remaining_seconds <= 0.0:
		return 0.0
	var progress := clampf(1.0 - remaining_seconds / total_seconds, 0.0, 1.0)
	return maxf(0.0, sin(PI * progress))


# (lateral sway in stage units, shoulder lean degrees, width multiplier).
# Fully fades at the beginning/end of a successful real dribble. Deliberately
# visual-only and deterministic: no timers, random effects or asset changes.
# Feints counter-lean; cuts/long touches plant once in the chosen direction.
static func xi_dribble_fallback_footwork(mode: String, progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var contact := sin(PI * t)
	if mode == "feint":
		var counterstep := sin(TAU * t) * contact
		# Two distinct, grounded shoulder plants at the actual broadcast scale.
		return Vector3(0.20 * counterstep, 25.0 * counterstep, 1.0 - 0.065 * contact)
	if mode == "burst":
		return Vector3(0.13 * contact, 19.0 * contact, 1.0 - 0.05 * contact)
	return Vector3(0.145 * contact, 22.0 * contact, 1.0 - 0.06 * contact)


# The authored SIDE R2 planted foot is on opposite screen sides for the
# two clubs, whereas the actual XI carrier anchor can sit well ahead in a
# diagonal. A bigger lateral offset alone made the ball visibly miss the
# painted boot. Blend the SAME displayed ball toward a bounded contact point
# at the player's feet, with a continuous right-to-left crossing (no snap
# when the second R2 frame is mirrored). Keep its 2D authority unchanged.
static func xi_feint_display_foot_contact(
	base_ball: Vector3, carrier_foot: Vector3,
	travel: Vector2, team_id: int, base_flip: bool, progress: float
) -> Vector3:
	if team_id not in [0, 1] or travel.length_squared() < 0.001:
		return base_ball
	var t := clampf(progress, 0.0, 1.0)
	var weight := clampf(sin(PI * t) * 1.08, 0.0, 0.94)
	if weight <= 0.0:
		return base_ball
	var dir := travel.normalized()
	var art_side := (1.0 if team_id == 0 else -1.0) * (
		-1.0 if base_flip else 1.0
	)
	# Traverse the two boots continuously even though the source R2
	# bitmap changes at 50%. The old diagonal ball could sit a full
	# boot-length beyond the painted leg.
	var cross := cos(PI * clampf((t - 0.14) / 0.72, 0.0, 1.0))
	var target := carrier_foot + Vector3(
		dir.x * 0.20 + art_side * 0.30 * cross, 0.0, dir.y * 0.20
	)
	return base_ball.lerp(target, weight)


# Only the DISPLAYED XI ball follows the planted foot while the actual
# possession action is active. Physics, keeper catches and the 2D ball remain
# authoritative and untouched. Bounded offsets return to zero at both ends;
# no independent clock or after-image can cause a phantom dribble.
# A feint sells one side with the shoulder, then nudges the ball across the
# opposite boot. A cut moves it laterally; a long touch pushes it forward.
static func xi_dribble_visual_ball_offset(mode: String, progress: float, direction: Vector2) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var weight := maxf(0.0, sin(PI * t))
	if weight <= 0.0 or direction.length_squared() < 0.001:
		return Vector3.ZERO
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var lateral := 0.0
	var lead := 0.0
	if mode == "feint":
		var counterstep := sin(TAU * t)
		# The previous first touch (0.08) was a third of the countertouch
		# and barely registered in XI broadcast. Balance the *display* ball
		# between the two real R2 planted feet. Both signed contacts still
		# decay to zero with the authoritative 0.24s action countdown.
		lateral = (0.26 * maxf(counterstep, 0.0) - 0.30 * maxf(-counterstep, 0.0)) * weight
	elif mode == "burst":
		lead = 0.33 * weight
	else:
		lateral = 0.31 * weight
		lead = 0.08 * weight
	var step: Vector2 = side * lateral + forward * lead
	return Vector3(step.x, 0.0, step.y)


func _sync_player_secondary_motion(
	player: Footballer, sprite: AnimatedSprite3D, proxy: Node3D, delta: float = 0.0
) -> void:
	var animation_name := String(sprite.animation)
	var frame_count := maxi(1, sprite.sprite_frames.get_frame_count(sprite.animation))
	# The visible 3D sprite changes texels on whole frames, but its secondary
	# weight transfer must follow the sub-frame clock. Quantizing sway/bob to
	# sprite.frame made each eight-pose run hitch at broadcast zoom.
	var phase_frames: float = float(sprite.frame)
	if _keeper_locomotion(sprite.animation):
		var phases: Dictionary = keeper_visual_phases if player.role == "keeper" else outfield_visual_phases
		phase_frames = float(phases.get(player.get_instance_id(), phase_frames))
	var phase := TAU * phase_frames / float(frame_count)
	var speed_ratio := clampf(player.velocity.length() / maxf(player.base_speed, 1.0), 0.0, 1.4)
	var moving_weight := clampf(speed_ratio, 0.0, 1.0)
	var bob := sin(phase) * 0.012
	var lateral_sway := sin(phase) * 0.010
	# V22 stops undoing the authored anatomy in the 3D presenter. The old
	# 0.90x/1.08y baseline made every improved atlas read tall and paper-thin
	# at broadcast scale. Keep the idle silhouette close to authored proportions;
	# reserve stronger deformation for genuinely explosive actions.
	var stretch_x := 0.98
	var stretch_y := 1.02
	var tilt_degrees := sin(phase) * 0.7
	var facing_sign := -1.0 if sprite.flip_h else 1.0
	var slide_scrape_weight := 0.0

	if animation_name == "idle" or animation_name.begins_with("idle_"):
		# The authored eight-frame cycle supplies its own breathing/weight shift.
		# No synthetic ground bob, tilt or sway: boots stay planted.
		bob = 0.0
		lateral_sway = 0.0
		tilt_degrees = 0.0
	elif animation_name == "run" or animation_name.begins_with("run_"):
		bob = absf(sin(phase)) * (PLAYER_RUN_BOB + 0.014) * moving_weight
		lateral_sway = sin(phase) * 0.029 * moving_weight
		stretch_x = 0.97 + absf(cos(phase)) * 0.018
		stretch_y = 1.025 - absf(cos(phase)) * 0.012
		tilt_degrees = -facing_sign * (4.5 + sin(phase) * 1.5) * moving_weight
	elif animation_name == "sprint" or animation_name.begins_with("sprint_"):
		bob = absf(sin(phase)) * (PLAYER_SPRINT_BOB + 0.020) * moving_weight
		lateral_sway = sin(phase) * 0.038 * moving_weight
		stretch_x = 0.95 + absf(cos(phase)) * 0.028
		stretch_y = 1.04 - absf(cos(phase)) * 0.018
		tilt_degrees = -facing_sign * (7.5 + sin(phase) * 1.8) * moving_weight
	elif animation_name == "pass":
		bob = absf(sin(phase)) * 0.025
		lateral_sway = -facing_sign * 0.026 * sin(phase)
		stretch_x = 0.98
		stretch_y = 1.02
		tilt_degrees = -facing_sign * 6.0
	elif animation_name == "shoot":
		bob = absf(sin(phase)) * 0.038
		lateral_sway = -facing_sign * 0.036 * sin(phase)
		stretch_x = 1.00
		stretch_y = 1.01
		tilt_degrees = -facing_sign * 12.0
	elif animation_name in ["dribble_cut", "dribble_burst"]:
		# The eight source poses supply the actual change of direction/stride.
		# Avoid a second procedural tilt or bounce that shifts the boots.
		bob = 0.0
		lateral_sway = 0.0
		stretch_x = 1.0
		stretch_y = 1.0
		tilt_degrees = 0.0
	elif animation_name in ["tackle", "slide_tackle"]:
		if _action_poses_r2_loaded.has("%d:%s" % [player.team_id, animation_name]):
			# Source slides are already low and horizontal. The old renderer
			# rotated/stretched the fallback tackle sprite into a fake slide.
			bob = 0.0
			lateral_sway = 0.0
			stretch_x = 1.0
			stretch_y = 1.0
			tilt_degrees = 0.0
			if animation_name == "slide_tackle" and match_node.match_team_size == 11:
				slide_scrape_weight = xi_slide_scrape_weight(
					player.action_visual_duration_seconds,
					player.action_lock_seconds
				)
				# A subtle forward pitch scrape; the frame's opaque boot baseline
				# remains grounded and the 2D action / collision never moves.
				lateral_sway = facing_sign * 0.075 * slide_scrape_weight
				tilt_degrees = -facing_sign * 2.5 * slide_scrape_weight
		elif player.tackle_aggressive_active():
			bob = -0.105
			lateral_sway = facing_sign * 0.095
			stretch_x = 1.16
			stretch_y = 0.80
			tilt_degrees = -facing_sign * 31.0
		else:
			bob = -0.050
			lateral_sway = facing_sign * 0.065
			stretch_x = 1.04
			stretch_y = 0.94
			tilt_degrees = -facing_sign * 17.0
	elif animation_name == "celebrate":
		bob = absf(sin(phase)) * 0.095
		lateral_sway = sin(phase * 0.5) * 0.022
		stretch_x = 0.98
		stretch_y = 1.05

	# Only the keeper receives stronger *visible* weight transfer.
	# It shares the same 8-frame cadence; no animation restarts or added clocks.
	# At broadcast distance the current canonical feet and gloves otherwise
	# move less than a couple of screen pixels, reading as a sliding cut-out.
	# This is presentation only: collisions, AI speed and the authored atlas
	# remain unchanged; stops and save/tackle animations keep their own poses.
	if (
		player.role == "keeper"
		and moving_weight > 0.0
		and (animation_name == "run" or animation_name.begins_with("run_")
			or animation_name == "sprint" or animation_name.begins_with("sprint_"))
	):
		var foot_phase := sin(phase)
		lateral_sway += foot_phase * KEEPER_STRIDE_EXTRA_SWAY * moving_weight
		bob += absf(foot_phase) * KEEPER_STRIDE_EXTRA_BOB * moving_weight
		tilt_degrees += foot_phase * KEEPER_STRIDE_EXTRA_LEAN_DEGREES * moving_weight
		stretch_x *= 1.0 + foot_phase * 0.035 * moving_weight
	# During an actual XI penalty the defending keeper braces on the line.
	# This is camera-facing body posture only: no player, collision or save
	# position is changed. Real lateral velocity determines which way they
	# lean. The weight fades over several frames after the restart ends.
	if player.role == "keeper":
		var keeper_id: int = int(player.get_instance_id())
		var guard_active: bool = (
			match_node.match_team_size == 11
			and match_node.set_piece_active
			and match_node.set_piece_kind == "PENALTI"
			and player.team_id != match_node.set_piece_team_id
			and not player.keeper_save_active()
			and sprite.animation != &"keeper_catch"
		)
		var guard_weight: float = move_toward(
			float(penalty_keeper_guard_blends.get(keeper_id, 0.0)),
			1.0 if guard_active else 0.0,
			maxf(0.0, delta) * XI_PENALTY_KEEPER_GUARD_BLEND_SPEED
		)
		penalty_keeper_guard_blends[keeper_id] = guard_weight
		if guard_weight > 0.0:
			stretch_x = lerpf(stretch_x, XI_PENALTY_KEEPER_GUARD_WIDTH, guard_weight)
			stretch_y = lerpf(stretch_y, XI_PENALTY_KEEPER_GUARD_HEIGHT, guard_weight)
			var lateral_speed: float = clampf(
				player.velocity.y / maxf(match_node.PENALTY_KEEPER_MOVE_SPEED, 1.0),
				-1.0, 1.0
			)
			tilt_degrees += lateral_speed * XI_PENALTY_KEEPER_GUARD_LEAN_DEGREES * guard_weight
	if player.keeper_save_active() and sprite.animation != &"keeper_catch":
		var save_progress := 1.0 - player.keeper_save_ratio()
		var save_weight := sin(PI * clampf(save_progress, 0.0, 1.0))
		lateral_sway = player.keeper_save_direction * 0.23 * save_weight
		bob = maxf(bob, 0.075 * save_weight)
		stretch_x = lerpf(stretch_x, 1.12, save_weight)
		stretch_y = lerpf(stretch_y, 0.87, save_weight)
		tilt_degrees = lerpf(
			tilt_degrees,
			player.keeper_save_direction * 38.0,
			save_weight,
		)

	if player.contact_stun_active():
		var contact_weight := player.contact_stun_ratio()
		bob = minf(bob, -0.030 * contact_weight)
		lateral_sway += player.contact_sway_sign * 0.065 * contact_weight
		stretch_x *= 1.0 + 0.070 * contact_weight
		stretch_y *= 1.0 - 0.065 * contact_weight
		tilt_degrees += player.contact_sway_sign * 16.0 * contact_weight

	# The authored XI frames already contain running weight transfer.
	# Synthetic vertical bob raises the boots above the ground shadow in
	# broadcast, most visibly for small distant players. Keep it for 5v5
	# and for XI actions such as slide, save and celebrations, but not
	# for ordinary XI locomotion.
	if (
		match_node.match_team_size == 11
		and (animation_name in ["run", "sprint"]
			or animation_name.begins_with("run_")
			or animation_name.begins_with("sprint_"))
	):
		bob = 0.0
		# At the far touchline, procedural lean/sway made tiny bodies look
		# detached even with an exact boot anchor and a matched shadow size.
		# Dampen the extra movement BEFORE the approved body/view scales.
		var stride_weight := xi_distant_stride_weight(
			perspective_body_scale(camera, proxy.global_position)
		)
		lateral_sway *= stride_weight
		tilt_degrees *= stride_weight
		stretch_x = lerpf(1.0, stretch_x, stride_weight)
		stretch_y = lerpf(1.0, stretch_y, stride_weight)

	# XI action R2 paintings are side-only: front/diagonal dribbles use a
	# two-beat visual foot plant on the SAME approved directional runner.
	# Real possession time drives it; nothing here changes motion, contacts,
	# 2D ball/boots or the existing 3D contact shadow. A feint reverses
	# shoulder weight (sell one side, leave the other), while a cut/long touch
	# visibly commits the shoulder in the actual intended direction.
	if (
		match_node.match_team_size == 11 and player.role != "keeper"
		and player.has_ball and player.dribble_active()
		and animation_name not in ["dribble_cut", "dribble_burst"]
	):
		var progress := 1.0 - clampf(
			player.dribble_burst_seconds / maxf(player.dribble_duration_seconds, 0.001),
			0.0, 1.0
		)
		var step := xi_dribble_fallback_footwork(player.dribble_mode, progress)
		var pivot_sign := 1.0 if player.dribble_direction.y >= 0.0 else -1.0
		if absf(player.dribble_direction.y) <= 0.12:
			pivot_sign = -1.0 if sprite.flip_h else 1.0
		lateral_sway += pivot_sign * step.x
		tilt_degrees += pivot_sign * step.y
		stretch_x *= step.z

	# One body-height reference for both teams, all views and all roles.
	var canonical_scale := _canonical_body_scale(sprite, player.role, player.team_id)
	var view_adjust := view_compensation(sprite.animation)
	# The previous parity fix only corrected BODY HEIGHT. At equal pitch
	# position V3 diagonals still read as much broader than the 8-frame
	# lateral carrier. Keep height and boot/shadow anchor unchanged while
	# correcting just the apparent torso width of these verified V3 views.
	var v3_width_trim := xi_v3_diagonal_width_trim(
		sprite.animation, match_node.match_team_size, player.role == "keeper",
		_run_v3_r2_loaded.has(int(player.team_id))
	)
	stretch_x *= canonical_scale * view_adjust.x * v3_width_trim
	stretch_y *= canonical_scale * view_adjust.y
	# The 3D canvas is centered in the atlas cell. Keep the same clearance
	# between boot soles and the pitch in broadcast AND tactical zoom, even
	# when the authored silhouette needs uniform scale correction.
	var cell_height := ChessFootballSpriteBank.cell_size().y
	var canonical_foot_pixels := ChessFootballSpriteBank.footline() - cell_height * 0.5
	var clearance := PLAYER_BASE_Y - canonical_foot_pixels * PLAYER_PIXEL_SIZE
	# The *authored* foot bottom can differ between running frames and poses.
	# Use the alpha baseline recorded while slicing the 3D image, otherwise
	# a raised pose floats while another sinks despite identical sprite scale.
	# This lookup is cached and makes NO per-frame GPU image readbacks.
	var frame_texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var frame_foot_pixels := ChessFootballSpriteBank.frame_bottom(frame_texture) - cell_height * 0.5
	sprite.position.x = lateral_sway
	sprite.position.y = clearance + frame_foot_pixels * sprite.pixel_size * stretch_y + bob
	sprite.rotation.z = deg_to_rad(tilt_degrees)
	sprite.scale = Vector3(stretch_x, stretch_y, 1.0)

	var shadow := proxy.get_node_or_null("ContactShadow") as MeshInstance3D
	if shadow != null:
		var shadow_scale := clampf(1.0 - maxf(bob, 0.0) * 2.2, 0.76, 1.0)
		shadow.scale = Vector3(
			shadow_scale * (1.0 + 0.12 * slide_scrape_weight),
			1.0,
			shadow_scale * (1.0 - 0.05 * slide_scrape_weight)
		)

# Human-owned touchline restarts need a little extra camera clearance on
# either edge: far away from the top chyron, near restarts above the bottom crop.
# Penalties, CPU restarts, tactical view and normal play remain unaffected.
static func broadcast_restart_look_z(
	active: bool, team_id: int, kind: String, spot: Vector2,
	pitch: Rect2 = ChessFootballMath.PITCH_RECT
) -> float:
	if not active or team_id != 0 or kind not in ["CÓRNER", "SAQUE DE BANDA"]:
		return BROADCAST_BASE_LOOK_Z
	var distance_from_center := spot.y - pitch.get_center().y
	if distance_from_center <= -pitch.size.y * 0.35:
		return BROADCAST_BASE_LOOK_Z - FAR_RESTART_LOOK_SHIFT
	if distance_from_center >= pitch.size.y * 0.35:
		if kind == "CÓRNER":
			return BROADCAST_BASE_LOOK_Z + NEAR_CORNER_LOOK_SHIFT
		return BROADCAST_BASE_LOOK_Z + NEAR_RESTART_LOOK_SHIFT
	return BROADCAST_BASE_LOOK_Z


# Pure framing contract. Only the human near-corner camera retreats;
# ordinary play, the far corner, CPU corners and all throw-ins keep depth.
static func broadcast_corner_camera_depth(
	active: bool, team_id: int, kind: String, spot: Vector2,
	pitch: Rect2 = ChessFootballMath.PITCH_RECT
) -> float:
	if (
		active and team_id == 0 and kind == "CÓRNER"
		and spot.y >= pitch.get_center().y + pitch.size.y * 0.35
	):
		return BROADCAST_DEPTH + NEAR_CORNER_CAMERA_RETREAT
	return BROADCAST_DEPTH


# A human near corner is a wide scene with a taker and a goalmouth. The
# standard ball-follow places the stadium against the outside edge, leaving
# too much empty black space. Shift the camera toward midfield just for XI,
# mirroring the bias at either end. Near throw-ins, far corners, 5v5 and CPU
# restarts are deliberately unchanged.
static func xi_corner_stadium_camera_x(
	camera_focus_x: float, xi: bool, active: bool, team_id: int,
	kind: String, spot: Vector2, pitch: Rect2
) -> float:
	if (
		not xi or not active or team_id != 0 or kind != "CÓRNER"
		or pitch.size.x <= 0.0 or pitch.size.y <= 0.0
	):
		return camera_focus_x
	var center: Vector2 = pitch.get_center()
	if (
		spot.y < center.y + pitch.size.y * 0.35
		or absf(spot.x - center.x) < pitch.size.x * 0.36
	):
		return camera_focus_x
	return camera_focus_x - signf(spot.x - center.x) * XI_NEAR_CORNER_STADIUM_PAN


# Only active XI penalties shift the stadium toward midfield horizontally.
# This changes no keeper, shot, ball or match-authoritative position.
static func xi_penalty_camera_x(
	camera_x: float, xi: bool, active: bool, kind: String, team_id: int
) -> float:
	if not xi or not active or kind != "PENALTI":
		return camera_x
	return camera_x - (XI_PENALTY_STADIUM_PAN if team_id == 0 else -XI_PENALTY_STADIUM_PAN)


# Authoritative penalty spot and goal are converted to stage coordinates
# using the full current pitch. This composition sits behind the taker,
# looking diagonally toward the real goal; the sign mirrors for both teams.
# Do not confuse it with the legacy horizontal stadium pan, which remains
# the fallback during the transition in and out.
static func xi_penalty_camera_pose(
	spot: Vector2, team_id: int, pitch: Rect2
) -> Dictionary:
	var direction: float = 1.0 if team_id == 0 else -1.0
	var center: Vector2 = pitch.get_center()
	var goal: Vector2 = ChessFootballMath.goal_center(team_id, pitch)
	var spot_x: float = (spot.x - center.x) * WORLD_SCALE
	var goal_x: float = (goal.x - center.x) * WORLD_SCALE
	return {
		"position": Vector3(
			spot_x - direction * XI_PENALTY_CAMERA_BEHIND,
			XI_PENALTY_CAMERA_HEIGHT, XI_PENALTY_CAMERA_NEAR_Z
		),
		"look": Vector3(goal_x - direction * 0.85, 0.70, 0.0),
		"fov": XI_PENALTY_CAMERA_FOV,
	}


# The corner is the only broadcast state that pushes the camera backward.
# Detect the outgoing composition from the real interpolated camera depth,
# not the new target: set_piece_active is cleared before the first ball frame.
static func broadcast_corner_release_active(
	mode: String, restart_active: bool, current_depth: float, xi: bool = false
) -> bool:
	# XI's normal camera is already farther back. Do not mistake every live
	# midfield frame for an outgoing corner and force corner-only smoothing.
	var neutral_depth := BROADCAST_DEPTH * (XI_BROADCAST_DEPTH_SCALE if xi else 1.0)
	return (
		mode == "broadcast"
		and not restart_active
		and current_depth > neutral_depth + CAMERA_CORNER_RELEASE_DEPTH_EPSILON
	)


static func broadcast_live_corner_x_limit_ratio(easing_corner_release: bool) -> float:
	return CORNER_CROSS_X_LIMIT_RATIO if easing_corner_release else BROADCAST_X_LIMIT_RATIO


# The real corner cross can be intercepted near the near touchline while
# the lens is already easing upward to the normal midfield view. Until the
# ball moves infield, retain enough downward pitch to keep that first touch
# and its selected-player ring visible. This only runs during near-corner
# release; no change to normal play, far corners or CPU restarts.
static func broadcast_live_corner_pitch_floor(
	ball_spot: Vector2, pitch: Rect2 = ChessFootballMath.PITCH_RECT
) -> float:
	var near_fraction := (ball_spot.y - pitch.get_center().y) / pitch.size.y
	var side_influence := smoothstep(0.30, 0.42, near_fraction)
	return BROADCAST_BASE_LOOK_Z + NEAR_CORNER_LOOK_SHIFT * side_influence


# Live XI camera pans toward the actual ball lane when it approaches either
# touchline. The tighter lens stays readable without cropping a controlled
# winger or using the 5v5 pitch proportions.
static func xi_broadcast_lane_look_z(ball_spot: Vector2, pitch: Rect2) -> float:
	var distance_z: float = (
		ball_spot.y - pitch.get_center().y
	) * WORLD_SCALE
	return BROADCAST_BASE_LOOK_Z + clampf(
		distance_z * XI_BROADCAST_VERTICAL_FOLLOW,
		XI_BROADCAST_VERTICAL_FOLLOW_MIN,
		XI_BROADCAST_VERTICAL_FOLLOW_MAX,
	)


# Match play has no authored restart shift, so both positive (near) and
# negative (far) lanes must control the lens. Preserve stronger special-shot
# framing ONLY when a human restart actually requested it.
static func xi_broadcast_target_look_z(lane_z: float, restart_z: float) -> float:
	if is_equal_approx(restart_z, BROADCAST_BASE_LOOK_Z):
		return lane_z
	if restart_z > BROADCAST_BASE_LOOK_Z:
		return maxf(restart_z, lane_z)
	return minf(restart_z, lane_z)


# Project one grass point onto the camera's vertical axis without moving
# the actual Camera3D. The camera aims in the stage's YZ plane in ordinary
# broadcast; fov is vertical because Godot keeps height by default.
static func xi_broadcast_line_screen_y(
	camera_position: Vector3, look_z: float, grass_z: float,
	vertical_fov: float, viewport_height: float
) -> float:
	if viewport_height <= 0.0 or vertical_fov <= 0.0:
		return INF
	var forward := Vector2(-camera_position.y, look_z - camera_position.z).normalized()
	var up := Vector2(-forward.y, forward.x)
	var to_grass := Vector2(0.02 - camera_position.y, grass_z - camera_position.z)
	var forward_distance: float = to_grass.dot(forward)
	if forward_distance <= 0.01:
		return INF
	var vertical_ratio: float = to_grass.dot(up) / forward_distance
	return viewport_height * 0.5 * (
		1.0 - vertical_ratio / tan(deg_to_rad(vertical_fov) * 0.5)
	)


# Find the MINIMUM broadcast pitch that keeps the actual lower white line
# visible with room for a controlled player's ground ring. This is used
# only near that touchline: midfield/far-side camera zoom stays untouched.
# A short binary search solves the real perspective equation without
# moving the camera or changing any player/world scale.
static func xi_broadcast_near_line_safe_look_z(
	camera_position: Vector3, vertical_fov: float, viewport_height: float,
	near_line_z: float, original_look_z: float, margin_px: float
) -> float:
	if viewport_height <= margin_px or camera_position.y <= 0.0:
		return original_look_z
	var bottom_limit: float = viewport_height - margin_px
	if xi_broadcast_line_screen_y(
		camera_position, original_look_z, near_line_z, vertical_fov, viewport_height
	) <= bottom_limit:
		return original_look_z
	var lower: float = original_look_z
	var upper: float = minf(camera_position.z - 0.5, near_line_z + 8.0)
	if upper <= lower:
		return lower
	for step in range(16):
		var middle: float = (lower + upper) * 0.5
		if xi_broadcast_line_screen_y(
			camera_position, middle, near_line_z, vertical_fov, viewport_height
		) > bottom_limit:
			lower = middle
		else:
			upper = middle
	return upper


static func xi_broadcast_fov_for_aspect(view_size: Vector2, wide_restart: bool = false) -> float:
	if wide_restart or view_size.y <= 0.0:
		return XI_BROADCAST_FOV
	var aspect: float = view_size.x / view_size.y
	var mix: float = clampf(
		(aspect - 16.0 / 9.0) / (XI_BROADCAST_WIDE_ASPECT - 16.0 / 9.0),
		0.0, 1.0
	)
	return lerpf(XI_BROADCAST_FOV, XI_BROADCAST_WIDE_FOV, mix)


# Pure framing contract: central open play may zoom, but near-touchline
# positions and ALL restarts retain the safe viewport-aspect baseline.
static func xi_broadcast_live_fov(
	view_size: Vector2, ball_spot: Vector2, pitch: Rect2,
	wide_restart: bool = false
) -> float:
	var safe_fov: float = xi_broadcast_fov_for_aspect(view_size, wide_restart)
	if wide_restart or pitch.size.y <= 0.0:
		return safe_fov
	var half_depth: float = pitch.size.y * 0.5
	var lane_ratio: float = absf(ball_spot.y - pitch.get_center().y) / half_depth
	var focus_factor: float = 1.0 - smoothstep(
		XI_BROADCAST_FOCUS_LANE_START,
		XI_BROADCAST_FOCUS_LANE_END,
		lane_ratio
	)
	return safe_fov - XI_BROADCAST_CENTER_ZOOM_DEGREES * focus_factor


func _camera_smoothing_factor(speed: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	return 1.0 - exp(-speed * delta)

func _sync_camera(delta: float, mode: String) -> void:
	if camera == null:
		return

	# Ease into the cinematic composition while preparing, then ease back
	# to live follow as soon as the shot is released (also on saves/rebounds).
	# Keeping the last pose while the blend fades avoids a one-frame snap.
	var cinematic_penalty: bool = (
		mode == "broadcast" and match_node.match_team_size == 11
		and bool(match_node.set_piece_active)
		and String(match_node.set_piece_kind) == "PENALTI"
	)
	if cinematic_penalty:
		var penalty_pose: Dictionary = xi_penalty_camera_pose(
			match_node.set_piece_spot, int(match_node.set_piece_team_id),
			match_node.match_pitch
		)
		penalty_camera_position = penalty_pose["position"]
		penalty_camera_target = penalty_pose["look"]
	penalty_camera_mix = lerpf(
		penalty_camera_mix, 1.0 if cinematic_penalty else 0.0,
		_camera_smoothing_factor(XI_PENALTY_CAMERA_BLEND_SPEED, delta),
	)
	if mode == "tactical":
		penalty_camera_mix = 0.0

	var focus := world_to_stage(match_node.ball.global_position)
	# XI's tactical camera is slightly farther back than live broadcast.
	# A single-frame switch check is insufficient: for several rendered
	# frames the interpolated camera remains beyond the corner threshold.
	# Retain this transition state until ordinary broadcast depth returns.
	if match_node.match_team_size == 11:
		if mode == "tactical":
			xi_returning_from_tactical = false
		elif mode == "broadcast" and last_camera_mode == "tactical":
			xi_returning_from_tactical = true
	var easing_corner_release := (
		mode == last_camera_mode
		and not xi_returning_from_tactical
		and broadcast_corner_release_active(
			mode, bool(match_node.set_piece_active), camera.position.z,
			match_node.match_team_size == 11,
		)
	)
	var wanted_position: Vector3
	var wanted_look: Vector3
	var wanted_fov: float
	# The existing guard solves the FINAL camera target. Keep its activity
	# for one last projected-pixel check AFTER the real camera interpolates;
	# otherwise a fast arrival can crop the line for several live frames.
	var near_line_guard_weight: float = 0.0

	if mode != last_camera_mode:
		if mode == "broadcast":
			# A genuine switch from the XI aerial view must immediately
			# re-acquire the live ball, not keep an old broadcast focus.
			smoothed_focus_x = focus.x
			smoothed_lead_x = clampf(match_node.ball.velocity.x * WORLD_SCALE * 0.26, -2.2, 2.2)
		# Remember tactical mode too in XI. Otherwise the returning aerial
		# depth masquerades as a near-corner release and uses the slower
		# corner camera recovery. Legacy 5v5 state handling is unchanged.
		if match_node.match_team_size == 11 or mode == "broadcast":
			last_camera_mode = mode

	if mode == "tactical":
		smoothed_restart_look_z = BROADCAST_BASE_LOOK_Z
		var tactical_height: float = (
			maxf(TACTICAL_HEIGHT, field_depth * 1.36)
			if match_node.match_team_size == 11 else TACTICAL_HEIGHT
		)
		# The original near-vertical XI aerial lens views upright raster
		# players edge-on. A shallow stadiumward tilt keeps all 22 visible
		# without changing the normal 5v5 tactical camera.
		var tactical_depth: float = (
			field_depth * 0.90 if match_node.match_team_size == 11 else 0.35
		)
		wanted_position = Vector3(0.0, tactical_height, tactical_depth)
		wanted_look = Vector3.ZERO
		wanted_fov = 43.0
	else:
		var focus_delta := focus.x - smoothed_focus_x
		if absf(focus_delta) > CAMERA_FOCUS_DEAD_ZONE:
			var focus_target := focus.x - signf(focus_delta) * CAMERA_FOCUS_DEAD_ZONE
			smoothed_focus_x = lerpf(
				smoothed_focus_x,
				focus_target,
				_camera_smoothing_factor(CAMERA_FOCUS_SMOOTH_SPEED, delta),
			)

		var raw_lead := clampf(match_node.ball.velocity.x * WORLD_SCALE * 0.26, -2.2, 2.2)
		smoothed_lead_x = lerpf(
			smoothed_lead_x,
			raw_lead,
			_camera_smoothing_factor(CAMERA_LEAD_SMOOTH_SPEED, delta),
		)

		var set_piece_pan := 0.0
		if (
			match_node.set_piece_active
			and match_node.set_piece_kind != "PENALTI"
			and match_node.set_piece_seconds_remaining > 0.0
		):
			var restart_progress := 1.0 - clampf(
				float(match_node.set_piece_seconds_remaining) / SET_PIECE_CAMERA_PAN_SECONDS,
				0.0,
				1.0,
			)
			var attacking_sign := 1.0 if int(match_node.set_piece_team_id) == 0 else -1.0
			set_piece_pan = (
				attacking_sign
				* smoothstep(0.0, 1.0, restart_progress)
				* SET_PIECE_CAMERA_PAN_DISTANCE
			)

		wanted_position = Vector3(
			smoothed_focus_x + smoothed_lead_x + set_piece_pan,
			BROADCAST_HEIGHT,
			broadcast_corner_camera_depth(
				bool(match_node.set_piece_active),
				int(match_node.set_piece_team_id),
				String(match_node.set_piece_kind),
				match_node.set_piece_spot,
				match_node.match_pitch,
			),
		)
		var camera_x_limit: float = field_width * (
			XI_BROADCAST_X_LIMIT_RATIO if match_node.match_team_size == 11
			else broadcast_live_corner_x_limit_ratio(easing_corner_release)
		)
		wanted_position.x = xi_corner_stadium_camera_x(
			wanted_position.x, match_node.match_team_size == 11,
			bool(match_node.set_piece_active), int(match_node.set_piece_team_id),
			String(match_node.set_piece_kind), match_node.set_piece_spot,
			match_node.match_pitch
		)
		wanted_position.x = clampf(wanted_position.x, -camera_x_limit, camera_x_limit)
		wanted_position.x = xi_penalty_camera_x(
			wanted_position.x, match_node.match_team_size == 11,
			bool(match_node.set_piece_active), String(match_node.set_piece_kind),
			int(match_node.set_piece_team_id)
		)
		if match_node.match_team_size == 11:
			wanted_position.y *= XI_BROADCAST_HEIGHT_SCALE
			wanted_position.z *= XI_BROADCAST_DEPTH_SCALE
		wanted_fov = (
			xi_broadcast_live_fov(
				get_viewport().get_visible_rect().size,
				match_node.ball.global_position, match_node.match_pitch,
				bool(match_node.set_piece_active) or easing_corner_release,
			) if match_node.match_team_size == 11 else 37.5
		)
		var restart_look_z := broadcast_restart_look_z(
			bool(match_node.set_piece_active),
			int(match_node.set_piece_team_id),
			String(match_node.set_piece_kind),
			match_node.set_piece_spot,
			match_node.match_pitch,
		)
		if match_node.match_team_size == 11:
			# Track the vertical ball lane as well as the horizontal one. Keep
			# stronger authored set-piece framing at the extreme edges.
			var lane_z: float = xi_broadcast_lane_look_z(
				match_node.ball.global_position, match_node.match_pitch
			)
			restart_look_z = xi_broadcast_target_look_z(lane_z, restart_look_z)
			# A ball near the goal can leave a selected human winger at the
			# camera-side touchline while the white line drops below the view.
			# Honor that actual line only when play (or the human) is nearby.
			# The ordinary camera and genuine corner/throw framing are intact.
			if not match_node.set_piece_active and not easing_corner_release and penalty_camera_mix < 0.01:
				var near_interest_y: float = match_node.ball.global_position.y
				var human: Footballer = match_node.controlled
				# If the ball is on the OPPOSITE far touchline, keep the
				# ball in frame instead of panning down to a remote selected
				# teammate. A near-side selected winger can share the shot
				# with the goalmouth only while the ball is not far upfield.
				var ball_fraction: float = (
					(match_node.ball.global_position.y - match_node.match_pitch.position.y)
					/ match_node.match_pitch.size.y
				)
				if (
					human != null and human.team_id == 0 and not human.sent_off
					and ball_fraction >= 0.30
				):
					near_interest_y = maxf(near_interest_y, human.global_position.y)
				var near_fraction: float = (
					(near_interest_y - match_node.match_pitch.position.y)
					/ match_node.match_pitch.size.y
				)
				near_line_guard_weight = smoothstep(
					XI_BROADCAST_NEAR_GUARD_START, XI_BROADCAST_NEAR_GUARD_FULL,
					near_fraction
				)
				if near_line_guard_weight > 0.0:
					var line_z: float = (
						match_node.match_pitch.end.y - match_node.match_pitch.get_center().y
					) * WORLD_SCALE
					var minimum_look_z: float = xi_broadcast_near_line_safe_look_z(
						wanted_position, wanted_fov, get_viewport().get_visible_rect().size.y,
						line_z, restart_look_z, XI_BROADCAST_NEAR_LINE_MARGIN_PX
					)
					restart_look_z = lerpf(
						restart_look_z, maxf(restart_look_z, minimum_look_z),
						near_line_guard_weight
					)
		if easing_corner_release:
			restart_look_z = maxf(
				restart_look_z,
				broadcast_live_corner_pitch_floor(
					match_node.ball.global_position, match_node.match_pitch
				),
			)
		var pitch_speed := (
			CAMERA_CORNER_RELEASE_SPEED if easing_corner_release
			else CAMERA_FOCUS_SMOOTH_SPEED
		)
		smoothed_restart_look_z = lerpf(
			smoothed_restart_look_z,
			restart_look_z,
			_camera_smoothing_factor(pitch_speed, delta),
		)
		wanted_look = Vector3(wanted_position.x, 0.0, smoothed_restart_look_z)
		wanted_position = wanted_position.lerp(
			penalty_camera_position, penalty_camera_mix
		)
		wanted_fov = lerpf(
			wanted_fov, XI_PENALTY_CAMERA_FOV, penalty_camera_mix
		)

	var t := _camera_smoothing_factor(CAMERA_LERP_SPEED, delta)
	var previous_depth := camera.position.z
	camera.position = camera.position.lerp(wanted_position, t)
	if (
		xi_returning_from_tactical and mode == "broadcast"
		and camera.position.z <= (
			BROADCAST_DEPTH * XI_BROADCAST_DEPTH_SCALE
			+ CAMERA_CORNER_RELEASE_DEPTH_EPSILON
		)
	):
		xi_returning_from_tactical = false
	if easing_corner_release:
		# Preserve the existing fast follow in X/Y. A slower, matched
		# depth/pitch recovery avoids whipping the shot at ball release.
		camera.position.z = lerpf(
			previous_depth, wanted_position.z,
			_camera_smoothing_factor(CAMERA_CORNER_RELEASE_SPEED, delta),
		)
	camera.fov = lerpf(camera.fov, wanted_fov, t)
	if (
		mode == "broadcast" and match_node.match_team_size == 11
		and near_line_guard_weight >= 0.98
	):
		# The target can be perfect while the ACTUAL camera still lags.
		# Enforce the same white-line margin with the interpolated position
		# and FOV before drawing this frame. The camera moves normally in
		# X/depth and only the necessary downward pitch is corrected.
		# No snap on camera changes, restarts, far/midfield or the 5v5.
		var near_white_z: float = (
			match_node.match_pitch.end.y - match_node.match_pitch.get_center().y
		) * WORLD_SCALE
		var safe_live_look_z: float = xi_broadcast_near_line_safe_look_z(
			camera.position, camera.fov, get_viewport().get_visible_rect().size.y,
			near_white_z, smoothed_restart_look_z, XI_BROADCAST_NEAR_LINE_MARGIN_PX
		)
		smoothed_restart_look_z = maxf(smoothed_restart_look_z, safe_live_look_z)
	var look_target := wanted_look
	if mode == "broadcast":
		# Follow the smoothed body in normal play; blend yaw and pitch smoothly
		# for the dedicated penalty angle and its return after ball release.
		look_target = Vector3(
			camera.position.x, 0.0, smoothed_restart_look_z
		).lerp(penalty_camera_target, penalty_camera_mix)
	camera.look_at(look_target, Vector3.UP)

func screen_position_for_world(world: Vector2, height: float = PLAYER_BASE_Y) -> Vector2:
	if camera == null:
		return Vector2(-10000.0, -10000.0)
	var stage_position := world_to_stage(world, height)
	if camera.is_position_behind(stage_position):
		return Vector2(-10000.0, -10000.0)
	return camera.unproject_position(stage_position)

func world_position_for_screen(screen_position: Vector2) -> Vector2:
	if camera == null:
		return Vector2(-10000.0, -10000.0)
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.0001:
		return Vector2(-10000.0, -10000.0)
	var distance := -ray_origin.y / ray_direction.y
	if distance <= 0.0:
		return Vector2(-10000.0, -10000.0)
	var stage_position := ray_origin + ray_direction * distance
	var center := ChessFootballMath.PITCH_RECT.get_center()
	return ChessFootballMath.clamp_to_pitch(
		Vector2(
			stage_position.x / WORLD_SCALE + center.x,
			stage_position.z / WORLD_SCALE + center.y,
		)
	)

func screen_position_for_player(player: Footballer) -> Vector2:
	if player == null or player.sent_off:
		return Vector2(-10000.0, -10000.0)
	return screen_position_for_world(player.global_position, PLAYER_BASE_Y)

func attack_goal_screen_position(team_id: int) -> Vector2:
	return screen_position_for_world(ChessFootballMath.goal_center(team_id), 0.62)

func debug_camera_smoothed_focus_x() -> float:
	return smoothed_focus_x

func debug_camera_x() -> float:
	return camera.position.x if camera != null else 0.0

func debug_camera_is_3d() -> bool:
	return camera != null and camera is Camera3D

func debug_animated_players() -> int:
	return player_sprites.size()

func debug_visible_players() -> int:
	var visible_count := 0
	for proxy in player_nodes.values():
		if proxy != null and proxy.visible:
			visible_count += 1
	return visible_count

func debug_penalty_aim_visible() -> bool:
	return penalty_aim_marker != null and penalty_aim_marker.visible

func debug_ball_render_height() -> float:
	return ball_node.position.y if ball_node != null else -1.0
