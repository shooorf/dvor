extends Node
## Процедурный генератор звуковых эффектов (16-bit PCM WAV в памяти).
## Не требует внешних платных аудиофайлов и работает в 3D-пространстве (AudioStreamPlayer3D).

const MIX_RATE: int = 22050

var _streams: Dictionary = {}
var _headless: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	_streams["swing_light"] = _build_noise_sweep(0.16, 900.0, 220.0, 0.35, 0.0)
	_streams["swing_heavy"] = _build_noise_sweep(0.28, 520.0, 110.0, 0.50, 85.0)
	_streams["hit_punch"] = _build_impact(0.14, 150.0, 48.0, 0.55, false)
	_streams["hit_kick"] = _build_impact(0.24, 115.0, 34.0, 0.80, false)
	_streams["hit_blade"] = _build_impact(0.20, 620.0, 180.0, 0.65, true)
	_streams["hit_blunt"] = _build_impact(0.22, 180.0, 52.0, 0.75, false)
	_streams["block_clang"] = _build_clang(0.30, 880.0, 1340.0, 0.60)
	_streams["wood_break"] = _build_crunch(0.34, 0.65)
	_streams["explosion"] = _build_explosion(0.75, 0.90)
	_streams["jump"] = _build_noise_sweep(0.12, 180.0, 420.0, 0.22, 140.0)
	_streams["pickup"] = _build_clang(0.18, 520.0, 780.0, 0.35)
	_streams["throw"] = _build_noise_sweep(0.20, 680.0, 240.0, 0.42, 120.0)


func play_3d(sfx_name: String, world_pos: Vector3, pitch_jitter: float = 0.08, volume_db: float = 0.0) -> void:
	if _headless or not _streams.has(sfx_name):
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = _streams[sfx_name]
	player.unit_size = 8.0
	player.max_distance = 45.0
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	scene_root.add_child(player)
	player.global_position = world_pos
	player.finished.connect(player.queue_free)
	player.play()


func play_ui(sfx_name: String, volume_db: float = -6.0) -> void:
	if _headless or not _streams.has(sfx_name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[sfx_name]
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _build_noise_sweep(duration: float, f_start: float, f_end: float, amp: float, tone_hz: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f_start * 13.0 + f_end)
	var lp: float = 0.0
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = sin(t * PI) * (1.0 - t * 0.45)
		var cutoff_hz: float = lerpf(f_start, f_end, t)
		var alpha: float = clampf((2.0 * PI * cutoff_hz) / float(MIX_RATE), 0.02, 0.95)
		var white: float = rng.randf_range(-1.0, 1.0)
		lp = lp + alpha * (white - lp)
		var sig: float = lp
		if tone_hz > 0.0:
			phase += (tone_hz * lerpf(1.2, 0.7, t)) / float(MIX_RATE)
			sig = sig * 0.75 + sin(phase * TAU) * 0.25
		out[i] = clampf(sig * env * amp * 2.2, -1.0, 1.0)
	return _make_wav(out)


func _build_impact(duration: float, f_start: float, f_end: float, amp: float, metallic: bool) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f_start * 31.0)
	var phase: float = 0.0
	var ring_phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = pow(1.0 - t, 2.6)
		var freq: float = lerpf(f_start, f_end, pow(t, 0.45))
		phase += freq / float(MIX_RATE)
		var punch: float = sin(phase * TAU)
		var burst: float = rng.randf_range(-1.0, 1.0) * pow(1.0 - t, 4.5) * 0.7
		var sig: float = punch * 0.8 + burst
		if metallic:
			ring_phase += 1420.0 / float(MIX_RATE)
			sig += (sin(ring_phase * TAU) + 0.5 * sin(ring_phase * TAU * 1.63)) * pow(1.0 - t, 3.0) * 0.35
		out[i] = clampf(sig * env * amp, -1.0, 1.0)
	return _make_wav(out)


func _build_clang(duration: float, f1: float, f2: float, amp: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t: float = float(i) / float(count)
		var sec: float = float(i) / float(MIX_RATE)
		var env: float = pow(1.0 - t, 2.2)
		var sig: float = (
			sin(sec * f1 * TAU) * 0.50
			+ sin(sec * f2 * TAU) * 0.32
			+ sin(sec * (f1 * 2.41) * TAU) * 0.18
		)
		out[i] = clampf(sig * env * amp, -1.0, 1.0)
	return _make_wav(out)


func _build_crunch(duration: float, amp: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var lp: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var crack: float = 1.0 if (i % 1600 < 260) else 0.35
		var white: float = rng.randf_range(-1.0, 1.0)
		lp = lp + 0.28 * (white - lp)
		var env: float = pow(1.0 - t, 1.8) * crack
		out[i] = clampf(lp * env * amp * 1.8, -1.0, 1.0)
	return _make_wav(out)


func _build_explosion(duration: float, amp: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp: float = 0.0
	var sub_phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = pow(1.0 - t, 1.65)
		var white: float = rng.randf_range(-1.0, 1.0)
		var alpha: float = lerpf(0.32, 0.04, t)
		lp = lp + alpha * (white - lp)
		sub_phase += lerpf(95.0, 28.0, t) / float(MIX_RATE)
		var sig: float = lp * 0.85 + sin(sub_phase * TAU) * 0.55
		out[i] = clampf(sig * env * amp * 1.4, -1.0, 1.0)
	return _make_wav(out)
