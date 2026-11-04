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
const BROADCAST_HEIGHT := 9.8
const BROADCAST_DEPTH := 17.8
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
const PLAYER_RUN_BOB := 0.050
const PLAYER_SPRINT_BOB := 0.072
# The approved keeper frames do move, but many poses are only a few pixels
# apart at broadcast zoom. Make the real stride readable using a modest
# diegetic lean/sway/weight transfer; do not change canonical raster anatomy.
const KEEPER_STRIDE_EXTRA_SWAY := 0.095
const KEEPER_STRIDE_EXTRA_BOB := 0.035
const KEEPER_STRIDE_EXTRA_LEAN_DEGREES := 13.0
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
# Keep the established visual spin rate, but roll around the axis
# perpendicular to the ball's actual 2D travel on the X/Z pitch plane.
# This changes no movement, velocity, 2D authority, collisions or ball art.
const BALL_VISUAL_SPIN_PER_PIXEL := 0.004

var match_node: Node
var camera: Camera3D
var player_nodes: Dictionary = {}
var player_sprites: Dictionary = {}
# 11v11-only QuadMesh bodies fed by the canonical AnimatedSprite3D frames.
# Legacy 5v5 continues to render AnimatedSprite3D directly.
var xi_raster_meshes: Dictionary = {}
# Mesh fallback for far-camera actor readability in the full 11v11 field.
# The approved animated raster still overlays each model at close range.
var xi_actor_models: Dictionary = {}
var player_run_views: Dictionary = {}
# Keeper run/action poses tick independently in the visible 3D runtime.
# Hidden authoritative 2D AnimatedSprite2D nodes are not a reliable clock.
var keeper_visual_phases: Dictionary = {}
var keeper_visual_names: Dictionary = {}
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
# Keep the static sponsor signs as the source of truth outside a real goal.
var ad_default_messages: Array[String] = []
var ad_default_accents: Array[Color] = []
var ad_last_goal_team: int = -1

func _request_idle_front_from_r2() -> void:
	# The shared loader owns URL validation, single-fetch, timeout and SHA.
	# Club-specific colour mapping stays in the sprite bank.
	if not OS.has_feature("web"):
		return
	var loader := ChessFootballR2AtlasLoader.new()
	loader.name = "OptionalIdleFrontR2"
	add_child(loader)
	loader.atlas_ready.connect(_on_idle_front_atlas_ready)
	loader.start(ChessFootballSpriteBank.optional_idle_meta())


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
			var index: int = 2 + int(player.team_id) if player.role == "keeper" else int(player.team_id)
			frames.set_frame(&"idle_front", 0, textures[index])
	# A late successful optional sheet invalidates any cached tonal correction.
	tone_gain_cache.clear()


# Staged activation: metadata remains disabled until Infra has publicly
# accredited both R2 sheets and exact byte/CORS parity.
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
			if animation == &"tackle" and _tackle_r2_loaded.has("%d:tackle" % team_id):
				continue
			var poses: Array = ChessFootballSpriteBank.CANONICAL_ACTION_POSES.get(String(animation), [])
			for index in range(8):
				var source := index if animation in [&"run", &"sprint"] else int(poses[index])
				frames.set_frame(animation, index, textures[source])
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
	_request_lateral_run_from_r2()
	_request_tackle_atlases_from_r2()
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

# XI-only raster mirrors the existing AnimatedSprite3D clock and atlas.
# Initialize after the 3D scene entered the tree, exactly like the real
# 22-proxy visual diagnostic. The shipped 5v5 has no extra raster nodes.
# In the expanded XI, Godot's GLES3 Sprite3D batches intermittently skip
# distant bodies. A normal textured QuadMesh renders the approved atlas on
# the exact same actor transform. The animated Sprite3D remains the clock;
# only this 11v11 preview uses these static 3D raster meshes.
func _build_xi_quad_bodies() -> void:
	if match_node.match_team_size != 11:
		return
	for team in match_node.teams:
		for player in team:
			var key: int = int(player.get_instance_id())
			var driver: AnimatedSprite3D = player_sprites.get(key)
			var proxy: Node3D = player_nodes.get(key)
			assert(driver != null and proxy != null)
			var frame_texture: Texture2D = driver.sprite_frames.get_frame_texture(driver.animation, driver.frame)
			var panel := QuadMesh.new()
			panel.size = Vector2(frame_texture.get_width(), frame_texture.get_height()) * driver.pixel_size
			var material := StandardMaterial3D.new()
			material.albedo_texture = frame_texture
			material.albedo_color = driver.modulate
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.12
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
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
			driver.hide()


# Full-pitch cameras can cull tiny raster billboards in Godot GLES3.
# Keep a small, physical team-coloured athlete UNDER the approved animated
# raster, so 22 actors remain identifiable at aerial and distant zooms.
# Restricted to the unshipped XI preview; 5v5 visuals are untouched.
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

			var shadow := MeshInstance3D.new()
			shadow.name = "ContactShadow"
			var shadow_mesh := CylinderMesh.new()
			shadow_mesh.top_radius = 0.30
			shadow_mesh.bottom_radius = 0.30
			shadow_mesh.height = 0.010
			shadow.mesh = shadow_mesh
			shadow.position.y = 0.012
			shadow.material_override = _material(Color(0.012, 0.020, 0.015), 1.0)
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
	sphere.radius = 0.16
	sphere.height = 0.32
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
	shadow_mesh.top_radius = 0.105
	shadow_mesh.bottom_radius = 0.105
	shadow_mesh.height = 0.008
	ball_shadow.mesh = shadow_mesh
	ball_shadow.material_override = _material(Color(0.012, 0.020, 0.015), 1.0)
	ball_shadow.position.y = 0.010
	add_child(ball_shadow)

	penalty_aim_marker = MeshInstance3D.new()
	penalty_aim_marker.name = "PenaltyAimMarker"
	var aim_mesh := TorusMesh.new()
	aim_mesh.inner_radius = 0.12
	aim_mesh.outer_radius = 0.20
	penalty_aim_marker.mesh = aim_mesh
	penalty_aim_marker.material_override = _material(Color(1.0, 0.73, 0.16), 0.28)
	penalty_aim_marker.position.y = 0.040
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
	var scale_factor := 1.35 if match_node.match_team_size == 11 else 1.0
	camera.position = Vector3(focus.x, BROADCAST_HEIGHT * scale_factor, BROADCAST_DEPTH * scale_factor)
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
				# Keep locomotion animations in phase with the authoritative 2D actor.
				# Non-locomotion actions preserve their established side-facing frames.
				var run_view := ChessFootballRunDirection.view_for_velocity(
					player.velocity, String(player_run_views.get(key, "front"))
				)
				player_run_views[key] = run_view
				var directional_animation := ChessFootballRunDirection.animation_for(wanted_animation, run_view)
				if sprite.sprite_frames.has_animation(directional_animation):
					wanted_animation = directional_animation
				var authored_catch: bool = (
					player.role == "keeper" and player == holding_keeper
					and _keeper_catch_r2_loaded.has(int(player.team_id))
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
					sprite.flip_h = player.visual.flip_h
			sprite.pixel_size = TACTICAL_PLAYER_PIXEL_SIZE if mode == "tactical" else PLAYER_PIXEL_SIZE
			_sync_player_secondary_motion(player, sprite, proxy)
			var tone_gain := _tonal_view_gain(sprite)
			sprite.modulate = Color(tone_gain, tone_gain, tone_gain, 1.0)
			var depth_scale := perspective_body_scale(camera, proxy.global_position)
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
			# A visible XI QuadMesh uses the original animation frame, position,
			# mirroring and footline. No separate animation or physics authority.
			var xi_quad: MeshInstance3D = xi_raster_meshes.get(key)
			if xi_quad != null:
				var panel: QuadMesh = xi_quad.mesh
				var canvas: StandardMaterial3D = xi_quad.material_override
				var current_frame: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
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
				if xi_quad.position != sprite.position:
					xi_quad.position = sprite.position
				if xi_quad.rotation != sprite.rotation:
					xi_quad.rotation = sprite.rotation
				if xi_quad.scale != sprite.scale:
					xi_quad.scale = sprite.scale
				if canvas.albedo_color != sprite.modulate:
					canvas.albedo_color = sprite.modulate
			# The existing secondary motion includes deliberate running bob,
			# which stays independent from depth and untouched here.
			var is_controlled: bool = player == match_node.controlled
			var active_disc := proxy.get_node_or_null("ActiveDisc") as MeshInstance3D
			if active_disc != null:
				active_disc.visible = is_controlled
			var receiver_disc := proxy.get_node_or_null("SetPieceReceiverDisc") as MeshInstance3D
			if receiver_disc != null:
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

	if ball_node != null:
		var grip_progress := 1.0
		var ball_at := world_to_stage(
			match_node.ball.global_position,
			0.18 + float(match_node.ball.flight_height) * WORLD_SCALE,
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
		ball_node.position = ball_at
		_sync_ball_visual_roll(delta)
		_sync_keeper_catch_hands(holding_keeper, ball_at, grip_progress)
	if ball_shadow != null:
		# The carried ball is not simultaneously painted at the keeper's boots.
		ball_shadow.visible = holding_keeper == null
		if ball_shadow.visible:
			ball_shadow.position = world_to_stage(match_node.ball.global_position, 0.010)
			var shadow_scale: float = lerpf(1.0, 0.62, clampf(float(match_node.ball.flight_height) / 90.0, 0.0, 1.0))
			ball_shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

	if penalty_aim_marker != null:
		penalty_aim_marker.visible = match_node.penalty_preview_visible()
		if penalty_aim_marker.visible:
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
	if ball_node == null or delta <= 0.0 or match_node.ball.carrier != null:
		return
	var velocity: Vector2 = match_node.ball.velocity
	var axis := ball_roll_axis(velocity)
	if axis == Vector3.ZERO:
		return
	ball_node.rotate(axis, velocity.length() * delta * BALL_VISUAL_SPIN_PER_PIXEL)


static func _keeper_locomotion(animation_name: StringName) -> bool:
	var name := String(animation_name)
	return name == "run" or name == "sprint" or name.begins_with("run_") or name.begins_with("sprint_")


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
		if not (_keeper_locomotion(previous) and _keeper_locomotion(wanted)):
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
	if _keeper_locomotion(wanted):
		# Movement-phase continuity survives turns and run/sprint switches.
		# A stationary actor must not run in place.
		if player.velocity.length() >= 12.0:
			phase += advance * maxf(player.visual.speed_scale, 0.0)
	elif not String(wanted).begins_with("idle"):
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


func _canonical_body_scale(sprite: AnimatedSprite3D, role: String = "") -> float:
	var current_name := String(sprite.animation)
	# Idle is a deliberately fixed stance. Normalize its actual silhouette,
	# not a sampled running gait (which can be significantly shorter).
	# The height was measured during the CPU crop, never read back from WebGL.
	if current_name == "idle" or current_name.begins_with("idle_"):
		var stance := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var height := ChessFootballSpriteBank.frame_height(stance)
		if height >= 60.0:
			return normalized_body_scale(height)
	var view := "side"
	if current_name.begins_with("run_"):
		view = current_name.trim_prefix("run_")
	elif current_name.begins_with("sprint_"):
		view = current_name.trim_prefix("sprint_")
	# Keepers now have a distinct approved body; their height sample must never
	# borrow a previously cached field-player measurement (or vice versa).
	var cache_key := ("keeper:" if role == "keeper" else "field:") + view
	if body_scale_cache.has(cache_key):
		return float(body_scale_cache[cache_key])
	var reference_name := ChessFootballRunDirection.animation_for(&"run", view)
	if not sprite.sprite_frames.has_animation(reference_name):
		push_error("Chess Football: missing approved run reference " + String(reference_name))
		return 1.0
	# Measure once per authored view from three cycle poses, not once per
	# player/frame. This avoids size pumping as legs alternate and avoids
	# repeated GPU readbacks during play.
	var heights: Array[float] = []
	for frame_id in [0, 3, 6]:
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


func _sync_player_secondary_motion(player: Footballer, sprite: AnimatedSprite3D, proxy: Node3D) -> void:
	var animation_name := String(sprite.animation)
	var frame_count := maxi(1, sprite.sprite_frames.get_frame_count(sprite.animation))
	var phase := TAU * float(sprite.frame) / float(frame_count)
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

	if animation_name == "run" or animation_name.begins_with("run_"):
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
	elif animation_name in ["tackle", "slide_tackle"]:
		if player.tackle_aggressive_active():
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

	# One body-height reference for both teams, all views and all roles.
	var canonical_scale := _canonical_body_scale(sprite, player.role)
	var view_adjust := view_compensation(sprite.animation)
	stretch_x *= canonical_scale * view_adjust.x
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
		shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

# Human-owned touchline restarts need a little extra camera clearance on
# either edge: far away from the top chyron, near restarts above the bottom crop.
# Penalties, CPU restarts, tactical view and normal play remain unaffected.
static func broadcast_restart_look_z(
	active: bool, team_id: int, kind: String, spot: Vector2
) -> float:
	var pitch := ChessFootballMath.PITCH_RECT
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
	active: bool, team_id: int, kind: String, spot: Vector2
) -> float:
	var pitch := ChessFootballMath.PITCH_RECT
	if (
		active and team_id == 0 and kind == "CÓRNER"
		and spot.y >= pitch.get_center().y + pitch.size.y * 0.35
	):
		return BROADCAST_DEPTH + NEAR_CORNER_CAMERA_RETREAT
	return BROADCAST_DEPTH


# The corner is the only broadcast state that pushes the camera backward.
# Detect the outgoing composition from the real interpolated camera depth,
# not the new target: set_piece_active is cleared before the first ball frame.
static func broadcast_corner_release_active(
	mode: String, restart_active: bool, current_depth: float
) -> bool:
	return (
		mode == "broadcast"
		and not restart_active
		and current_depth > BROADCAST_DEPTH + CAMERA_CORNER_RELEASE_DEPTH_EPSILON
	)


static func broadcast_live_corner_x_limit_ratio(easing_corner_release: bool) -> float:
	return CORNER_CROSS_X_LIMIT_RATIO if easing_corner_release else BROADCAST_X_LIMIT_RATIO


# The real corner cross can be intercepted near the near touchline while
# the lens is already easing upward to the normal midfield view. Until the
# ball moves infield, retain enough downward pitch to keep that first touch
# and its selected-player ring visible. This only runs during near-corner
# release; no change to normal play, far corners or CPU restarts.
static func broadcast_live_corner_pitch_floor(ball_spot: Vector2) -> float:
	var pitch := ChessFootballMath.PITCH_RECT
	var near_fraction := (ball_spot.y - pitch.get_center().y) / pitch.size.y
	var side_influence := smoothstep(0.30, 0.42, near_fraction)
	return BROADCAST_BASE_LOOK_Z + NEAR_CORNER_LOOK_SHIFT * side_influence


func _camera_smoothing_factor(speed: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	return 1.0 - exp(-speed * delta)

func _sync_camera(delta: float, mode: String) -> void:
	if camera == null:
		return

	var focus := world_to_stage(match_node.ball.global_position)
	var easing_corner_release := broadcast_corner_release_active(
		mode, bool(match_node.set_piece_active), camera.position.z
	)
	var wanted_position: Vector3
	var wanted_look: Vector3
	var wanted_fov: float

	if mode != last_camera_mode:
		if mode == "broadcast":
			smoothed_focus_x = focus.x
			smoothed_lead_x = clampf(match_node.ball.velocity.x * WORLD_SCALE * 0.26, -2.2, 2.2)
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
			),
		)
		var camera_x_limit := field_width * broadcast_live_corner_x_limit_ratio(
			easing_corner_release
		)
		wanted_position.x = clampf(wanted_position.x, -camera_x_limit, camera_x_limit)
		if match_node.match_team_size == 11:
			# Wider preview lens framing, without touching the calibrated 5v5 camera.
			wanted_position.y *= 1.35
			wanted_position.z *= 1.45
		var restart_look_z := broadcast_restart_look_z(
			bool(match_node.set_piece_active),
			int(match_node.set_piece_team_id),
			String(match_node.set_piece_kind),
			match_node.set_piece_spot,
		)
		if easing_corner_release:
			restart_look_z = maxf(
				restart_look_z,
				broadcast_live_corner_pitch_floor(match_node.ball.global_position),
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
		wanted_fov = 37.5

	var t := _camera_smoothing_factor(CAMERA_LERP_SPEED, delta)
	var previous_depth := camera.position.z
	camera.position = camera.position.lerp(wanted_position, t)
	if easing_corner_release:
		# Preserve the existing fast follow in X/Y. A slower, matched
		# depth/pitch recovery avoids whipping the shot at ball release.
		camera.position.z = lerpf(
			previous_depth, wanted_position.z,
			_camera_smoothing_factor(CAMERA_CORNER_RELEASE_SPEED, delta),
		)
	camera.fov = lerpf(camera.fov, wanted_fov, t)
	var look_target := wanted_look
	if mode == "broadcast":
		# Follow the already-smoothed camera body instead of snapping the yaw
		# toward the raw destination while position is still catching up.
		look_target = Vector3(camera.position.x, 0.0, smoothed_restart_look_z)
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
