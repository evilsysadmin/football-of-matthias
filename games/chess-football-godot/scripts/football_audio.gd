class_name ChessFootballAudio
extends Node

const MIX_RATE := 44100
const POOL_SIZE := 10
const CROWD_REACTION_COOLDOWN := 2.8

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _cursor: int = 0
var sfx_enabled: bool = true
var _variation_cursors: Dictionary = {}
var _last_played_key: String = ""
var _crowd_bed: AudioStreamPlayer
var _crowd_reaction: AudioStreamPlayer
var _match_paused: bool = false
var _crowd_clock: float = 0.0
var _last_crowd_reaction_at: float = -CROWD_REACTION_COOLDOWN
var _crowd_reaction_count: int = 0
var _last_crowd_reaction_key: String = ""

func _ready() -> void:
	for index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "FootballVoice_%02d" % index
		add_child(player)
		_players.append(player)
	_build_streams()
	_crowd_bed = AudioStreamPlayer.new()
	_crowd_bed.name = "FootballCrowdBed"
	_crowd_bed.stream = _streams["crowd_bed"]
	_crowd_bed.volume_db = -17.0
	add_child(_crowd_bed)
	_crowd_reaction = AudioStreamPlayer.new()
	_crowd_reaction.name = "FootballCrowdReaction"
	add_child(_crowd_reaction)
	_sync_crowd_bed()

func _process(delta: float) -> void:
	# This audio-only clock stops while the match is paused or muted. It never
	# affects football physics, score, restart timing or match authority.
	if sfx_enabled and not _match_paused:
		_crowd_clock += maxf(0.0, delta)

func _sync_crowd_bed() -> void:
	if _crowd_bed == null:
		return
	if sfx_enabled and not _match_paused:
		if not _crowd_bed.playing:
			_crowd_bed.play()
	else:
		_crowd_bed.stop()

func set_match_paused(paused: bool) -> void:
	_match_paused = paused
	_sync_crowd_bed()
	if paused and _crowd_reaction != null:
		_crowd_reaction.stop()

# Match-local only: do not mute the browser, the host, or other modes.
# Stopping active voices matters for a goal cheer already ringing out.
func set_sfx_enabled(enabled: bool) -> void:
	if sfx_enabled == enabled:
		return
	sfx_enabled = enabled
	if not enabled:
		for player in _players:
			player.stop()
		if _crowd_reaction != null:
			_crowd_reaction.stop()
	_sync_crowd_bed()

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

func play_keeper_save() -> void:
	_play("save", -3.0, 1.0)
	_play_crowd_reaction("crowd_save", -10.0)

func play_goal() -> void:
	# A confirmed goal supersedes a previous gasp. The existing goal swell
	# owns the celebration; do not stack another full-length crowd roar.
	if _crowd_reaction != null:
		_crowd_reaction.stop()
	_last_crowd_reaction_at = _crowd_clock
	_play_variant("goal", ["goal", "goal_alt"], -1.0, 1.0)

func play_goal_frame(impact_speed: float, kind: String = "post") -> void:
	var strength := clampf((impact_speed - 350.0) / 900.0, 0.0, 1.0)
	_play("crossbar" if kind == "crossbar" else "post",
		lerpf(-5.0, -0.4, strength), lerpf(1.08, 0.92, strength))
	_play_crowd_reaction("crowd_gasp", -12.0)

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

func debug_crowd_bed_playing() -> bool:
	return _crowd_bed != null and _crowd_bed.playing

func debug_crowd_reaction_count() -> int:
	return _crowd_reaction_count

func debug_last_crowd_reaction_key() -> String:
	return _last_crowd_reaction_key

func _play_crowd_reaction(key: String, volume_db: float) -> void:
	if not sfx_enabled or _match_paused or _crowd_reaction == null:
		return
	if _crowd_clock - _last_crowd_reaction_at < CROWD_REACTION_COOLDOWN:
		return
	var stream = _streams.get(key)
	if stream == null:
		return
	_crowd_reaction.stop()
	_crowd_reaction.stream = stream
	_crowd_reaction.volume_db = volume_db
	_crowd_reaction.play()
	_last_crowd_reaction_at = _crowd_clock
	_crowd_reaction_count += 1
	_last_crowd_reaction_key = key

# Cycle through curated sound takes. No RNG, no extra gameplay events, and
# muting does not advance the variant so unmuting remains predictable.
func _play_variant(group: String, keys: Array[String], volume_db: float, pitch_scale: float) -> void:
	if not sfx_enabled or keys.is_empty():
		return
	var index := int(_variation_cursors.get(group, 0))
	_variation_cursors[group] = index + 1
	_play(keys[index % keys.size()], volume_db, pitch_scale)

func _play(key: String, volume_db: float, pitch_scale: float) -> void:
	if not sfx_enabled:
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
	_streams["whistle"] = _make_whistle(0.20)
	# Crossbar has a lower, longer ringing timbre than a vertical post.
	_streams["post"] = _make_metal_ring(0.46, 740.0)
	_streams["crossbar"] = _make_metal_ring(0.57, 580.0)
	_streams["goal"] = _make_goal_swell(2.25, 503)
	_streams["goal_alt"] = _make_goal_swell(2.10, 619)
	# One low-level loop and two short one-shot cues, generated on startup.
	# No external samples, media licensing or runtime R2 dependencies.
	_streams["crowd_bed"] = _make_crowd_bed(2.4, 727)
	_streams["crowd_gasp"] = _make_crowd_reaction(1.05, 733, false)
	_streams["crowd_save"] = _make_crowd_reaction(1.25, 739, true)

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

func _make_goal_swell(duration: float, seed: int) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_state := seed
	var low_phase := 0.0
	var clap_phase := 0.0
	var filtered_noise := 0.0

	for index in range(sample_count):
		var t := float(index) / float(sample_count)
		var seconds := float(index) / float(MIX_RATE)
		noise_state = int((noise_state * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(noise_state) / 1073741824.0) - 1.0
		low_phase += TAU * 82.0 / float(MIX_RATE)
		clap_phase += TAU * 5.6 / float(MIX_RATE)
		# Filter broadband noise into a low stadium roar. Keep discrete handclap
		# transients on top; the sustained noise must not sound like TV static.
		filtered_noise = filtered_noise * 0.87 + noise * 0.13
		var attack := minf(1.0, t / 0.06)
		var decay := pow(maxf(0.0, 1.0 - t), 0.80)
		var crowd := filtered_noise * 0.41 + sin(low_phase) * 0.08
		var clap_gate := pow(maxf(0.0, sin(clap_phase)), 13.0)
		var claps := (noise - filtered_noise) * clap_gate * 0.37
		var stinger := sin(TAU * 620.0 * seconds) * exp(-seconds * 7.0) * 0.15
		var raw := (crowd + claps) * attack * decay + stinger
		var sample := raw / (1.0 + absf(raw) * 0.30)
		data.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))

	return _wav_from_data(data)

func _make_crowd_bed(duration: float, seed: int) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_state := seed
	var low_noise := 0.0
	var mid_noise := 0.0
	for index in range(sample_count):
		var seconds := float(index) / float(MIX_RATE)
		var t := float(index) / float(sample_count)
		noise_state = int((noise_state * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(noise_state) / 1073741824.0) - 1.0
		low_noise = low_noise * 0.975 + noise * 0.025
		mid_noise = mid_noise * 0.84 + noise * 0.16
		# Periodic breath and quiet midrange chatter, not a wideband hiss.
		# Gentle fade at the loop boundary prevents clicks in Web Audio.
		var breath := 0.82 + 0.12 * sin(TAU * t)
		var seam := minf(1.0, minf(seconds, duration - seconds) / 0.14)
		var raw := (low_noise * 0.66 + mid_noise * 0.28) * breath * seam
		data.encode_s16(index * 2, int(round(clampf(raw, -1.0, 1.0) * 32767.0)))
	var stream := _wav_from_data(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func _make_crowd_reaction(duration: float, seed: int, applause: bool) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_state := seed
	var low_noise := 0.0
	var phase := 0.0
	for index in range(sample_count):
		var seconds := float(index) / float(MIX_RATE)
		var t := float(index) / float(sample_count)
		noise_state = int((noise_state * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(noise_state) / 1073741824.0) - 1.0
		low_noise = low_noise * 0.91 + noise * 0.09
		phase += TAU * (5.2 if applause else 2.4) / float(MIX_RATE)
		var attack := minf(1.0, seconds / 0.095)
		var decay := pow(maxf(0.0, 1.0 - t), 1.35)
		var pulse := pow(maxf(0.0, sin(phase)), 12.0) if applause else 0.0
		var hush := 0.20 * sin(TAU * 164.0 * seconds) if not applause else 0.0
		var raw := (low_noise * 0.76 + noise * pulse * 0.22 + hush) * attack * decay
		data.encode_s16(index * 2, int(round(clampf(raw, -1.0, 1.0) * 32767.0)))
	return _wav_from_data(data)

func _wav_from_data(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
