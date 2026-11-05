class_name ChessFootballAudio
extends Node

const MIX_RATE := 44100
const POOL_SIZE := 10

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _cursor: int = 0
var sfx_enabled: bool = true
var _variation_cursors: Dictionary = {}
var _last_played_key: String = ""
func _ready() -> void:
	for index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "FootballVoice_%02d" % index
		add_child(player)
		_players.append(player)
	_build_streams()

# Match-only controls. Never mute the global bus or other application audio.
var _match_paused: bool = false


func set_match_paused(paused: bool) -> void:
	_match_paused = paused
	if paused:
		for player in _players:
			player.stop()


func set_sfx_enabled(enabled: bool) -> void:
	if sfx_enabled == enabled:
		return
	sfx_enabled = enabled
	if not enabled:
		for player in _players:
			player.stop()


func play_whistle() -> void:
	# Referee cue, not an alarm: short, slightly lower and tucked behind the ball audio.
	_play("whistle", -9.0, 0.94)

func play_pass() -> void:
	_play_variant("pass", ["pass", "pass_soft", "pass_crisp"], -4.0, 1.0)

func play_shot(charge_ratio: float) -> void:
	var ratio := clampf(charge_ratio, 0.0, 1.0)
	_play_variant("shot", ["shot", "shot_low", "shot_snap"],
		lerpf(-3.5, -0.5, ratio), lerpf(1.04, 0.92, ratio))

func play_tackle(is_foul: bool = false) -> void:
	if is_foul:
		_play("tackle_foul", -2.3, 0.96)
	else:
		_play_variant("tackle", ["tackle", "tackle_boot"], -2.5, 1.0)

func play_close_miss() -> void:
	# Tracked misses still drive the match, but no fake breathy crowd gasp.
	pass

func play_keeper_save(spectacular: bool = false) -> void:
	# Keep only the glove/dive impacts. Synthetic applause is removed.
	if spectacular:
		_play("save_dive", -2.0, 0.96)
	else:
		_play("save", -3.0, 1.0)

func play_goal() -> void:
	# Short, clean score cue; never a synthetic crowd roar.
	_play_variant("goal", ["goal", "goal_alt"], -8.0, 1.0)

func play_goal_frame(impact_speed: float, kind: String = "post") -> void:
	var strength := clampf((impact_speed - 350.0) / 900.0, 0.0, 1.0)
	_play("crossbar" if kind == "crossbar" else "post",
		lerpf(-5.0, -0.4, strength), lerpf(1.08, 0.92, strength))

func debug_stream_names() -> Array[String]:
	var names: Array[String] = []
	for key in _streams.keys():
		names.append(String(key))
	names.sort()
	return names

func debug_stream_duration(key: String) -> float:
	var stream = _streams.get(key) as AudioStreamWAV
	return stream.get_length() if stream != null else 0.0

func debug_last_played_key() -> String:
	return _last_played_key

# Cycle through curated sound takes. No RNG, no extra gameplay events, and
# muting does not advance the variant so unmuting remains predictable.
func _play_variant(group: String, keys: Array[String], volume_db: float, pitch_scale: float) -> void:
	if not sfx_enabled or keys.is_empty():
		return
	var index := int(_variation_cursors.get(group, 0))
	_variation_cursors[group] = index + 1
	_play(keys[index % keys.size()], volume_db, pitch_scale)

func _play(key: String, volume_db: float, pitch_scale: float) -> void:
	if not sfx_enabled or _match_paused:
		return
	var stream = _streams.get(key)
	if stream == null or _players.is_empty():
		return
	var voice := _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	voice.stop()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch_scale
	voice.play()
	_last_played_key = key

func _build_streams() -> void:
	_streams["pass"] = _make_ball_strike(0.070, 190.0, 118.0, 0.46, 0.18, 101)
	_streams["pass_soft"] = _make_ball_strike(0.085, 165.0, 105.0, 0.39, 0.15, 107)
	_streams["pass_crisp"] = _make_ball_strike(0.060, 217.0, 133.0, 0.47, 0.24, 109)
	_streams["shot"] = _make_ball_strike(0.135, 150.0, 62.0, 0.82, 0.31, 211)
	_streams["shot_low"] = _make_ball_strike(0.145, 137.0, 55.0, 0.88, 0.28, 223)
	_streams["shot_snap"] = _make_ball_strike(0.128, 165.0, 71.0, 0.74, 0.38, 227)
	_streams["tackle"] = _make_impact(0.105, 94.0, 48.0, 0.72, 0.52, 307)
	_streams["tackle_boot"] = _make_impact(0.115, 112.0, 55.0, 0.63, 0.65, 311)
	_streams["tackle_foul"] = _make_impact(0.160, 81.0, 36.0, 0.88, 0.70, 313)
	_streams["save"] = _make_impact(0.082, 260.0, 105.0, 0.52, 0.66, 401)
	_streams["save_dive"] = _make_impact(0.160, 206.0, 69.0, 0.67, 0.72, 409)
	_streams["whistle"] = _make_whistle(0.20)
	# Crossbar has a lower, longer ringing timbre than a vertical post.
	_streams["post"] = _make_metal_ring(0.46, 740.0)
	_streams["crossbar"] = _make_metal_ring(0.57, 580.0)
	# A short, gentle two-note score cue replaces the long crowd-like swell.
	# No stadium hiss, gasps or applause is generated or played.
	_streams["goal"] = _make_goal_cue(0.42, 495.0)
	_streams["goal_alt"] = _make_goal_cue(0.42, 523.0)

func _make_ball_strike(
	duration: float,
	start_hz: float,
	end_hz: float,
	body_gain: float,
	noise_gain: float,
	seed: int,
) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	var noise_state := seed
	var previous_noise := 0.0

	for index in range(sample_count):
		var seconds := float(index) / float(MIX_RATE)
		var t := float(index) / float(sample_count)
		var hz := lerpf(start_hz, end_hz, t)
		phase += TAU * hz / float(MIX_RATE)
		noise_state = int((noise_state * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(noise_state) / 1073741824.0) - 1.0
		var snap := noise - previous_noise * 0.70
		previous_noise = noise
		var transient := exp(-seconds * 180.0)
		var body_env := exp(-seconds * 31.0)
		# A little leather resonance and low-frequency thump separate a boot
		# strike from a synthetic single-frequency click.
		var leather := sin(phase * 1.96) * body_gain * exp(-seconds * 65.0) * 0.17
		var thump := sin(phase * 0.53) * body_gain * exp(-seconds * 29.0) * 0.24
		var raw := sin(phase) * body_gain * body_env + snap * noise_gain * transient + leather + thump
		var sample := raw / (1.0 + absf(raw) * 0.34)
		data.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))

	return _wav_from_data(data)

func _make_impact(
	duration: float,
	start_hz: float,
	end_hz: float,
	tone_gain: float,
	noise_gain: float,
	seed: int,
) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	var noise_state := seed

	for index in range(sample_count):
		var seconds := float(index) / float(MIX_RATE)
		var t := float(index) / float(sample_count)
		var hz := lerpf(start_hz, end_hz, t)
		phase += TAU * hz / float(MIX_RATE)
		noise_state = int((noise_state * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(noise_state) / 1073741824.0) - 1.0
		var envelope := exp(-seconds * 34.0)
		var click := noise * exp(-seconds * 220.0)
		var raw := sin(phase) * tone_gain * envelope + click * noise_gain
		var sample := raw / (1.0 + absf(raw) * 0.42)
		data.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))

	return _wav_from_data(data)

func _make_whistle(duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase_a := 0.0
	var phase_b := 0.0

	for index in range(sample_count):
		var t := float(index) / float(sample_count)
		var seconds := float(index) / float(MIX_RATE)
		var vibrato := sin(TAU * 7.2 * seconds) * 22.0
		phase_a += TAU * (1980.0 + vibrato) / float(MIX_RATE)
		phase_b += TAU * (2440.0 + vibrato * 0.65) / float(MIX_RATE)
		var attack := minf(1.0, t / 0.035)
		var release := minf(1.0, (1.0 - t) / 0.12)
		var envelope := attack * release
		var raw := (sin(phase_a) * 0.58 + sin(phase_b) * 0.25) * envelope
		data.encode_s16(index * 2, int(round(clampf(raw, -1.0, 1.0) * 32767.0)))

	return _wav_from_data(data)

func _make_metal_ring(duration: float, fundamental_hz: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase_a := 0.0
	var phase_b := 0.0
	var phase_c := 0.0

	for index in range(sample_count):
		var seconds := float(index) / float(MIX_RATE)
		phase_a += TAU * fundamental_hz / float(MIX_RATE)
		phase_b += TAU * fundamental_hz * 1.61 / float(MIX_RATE)
		phase_c += TAU * fundamental_hz * 2.80 / float(MIX_RATE)
		var ring_env := exp(-seconds * 7.8)
		var bright_env := exp(-seconds * 15.0)
		var transient := exp(-seconds * 120.0)
		var raw := (
			sin(phase_a) * 0.50 * ring_env
			+ sin(phase_b) * 0.27 * ring_env
			+ sin(phase_c) * 0.16 * bright_env
			+ sin(phase_c * 1.71) * 0.10 * transient
		)
		var sample := raw / (1.0 + absf(raw) * 0.22)
		data.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))

	return _wav_from_data(data)

# Soft two-tone UI cue, not a fake human/crowd recording.
func _make_goal_cue(duration: float, root_hz: float) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(duration * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for index in range(sample_count):
		var seconds: float = float(index) / float(MIX_RATE)
		var second_note: bool = seconds >= duration * 0.44
		var note_start: float = duration * 0.44 if second_note else 0.0
		var note_time: float = seconds - note_start
		var hz: float = root_hz * (1.25 if second_note else 1.0)
		phase += TAU * hz / float(MIX_RATE)
		var attack: float = minf(1.0, note_time / 0.012)
		var decay: float = exp(-note_time * 14.0)
		var raw: float = sin(phase) * attack * decay * 0.42
		data.encode_s16(index * 2, int(round(clampf(raw, -1.0, 1.0) * 32767.0)))
	return _wav_from_data(data)


func _wav_from_data(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
