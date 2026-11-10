extends Node
class_name CastleAudioManager

var music_enabled := true
var sfx_enabled := true
var music_volume := 0.32
var sfx_volume := 0.78
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_player_cursor := 0
var sfx_streams: Dictionary = {}

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "ProceduralMedievalMusic"
	music_player.stream = _make_music_stream()
	add_child(music_player)
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%02d" % i
		add_child(player)
		sfx_players.append(player)
	sfx_streams = {
		"cannon": _make_sfx_stream("cannon"),
		"enemy_cannon": _make_sfx_stream("enemy_cannon"),
		"stone_impact": _make_sfx_stream("stone_impact"),
		"explosion": _make_sfx_stream("explosion"),
		"fire_impact": _make_sfx_stream("fire_impact"),
		"debris": _make_sfx_stream("debris"),
		"upgrade": _make_sfx_stream("upgrade"),
		"menu": _make_sfx_stream("menu")
	}
	_update_music()

func configure(music_on: bool, sfx_on: bool, music_level: float, sfx_level: float) -> void:
	music_enabled = music_on
	sfx_enabled = sfx_on
	music_volume = clampf(music_level, 0.0, 1.0)
	sfx_volume = clampf(sfx_level, 0.0, 1.0)
	_update_music()

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	_update_music()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if enabled:
		play("menu")

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_update_music()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)

func play(kind: String) -> void:
	if not sfx_enabled or sfx_players.is_empty() or not sfx_streams.has(kind):
		return
	var player := sfx_players[sfx_player_cursor]
	sfx_player_cursor = (sfx_player_cursor + 1) % sfx_players.size()
	player.stop()
	player.stream = sfx_streams[kind]
	player.volume_db = linear_to_db(maxf(sfx_volume, 0.001))
	player.play()

func _update_music() -> void:
	if not is_instance_valid(music_player):
		return
	music_player.volume_db = linear_to_db(maxf(music_volume, 0.001))
	if music_enabled and music_volume > 0.001:
		if not music_player.playing:
			music_player.play()
	else:
		music_player.stop()

func _make_sfx_stream(kind: String) -> AudioStreamWAV:
	const RATE := 22050
	var duration := 0.42
	match kind:
		"cannon", "enemy_cannon":
			duration = 0.48
		"stone_impact", "debris":
			duration = 0.28
		"explosion":
			duration = 0.95
		"fire_impact":
			duration = 0.62
		"upgrade":
			duration = 0.58
		"menu":
			duration = 0.12
	var sample_count := int(RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(RATE)
		var envelope := 0.0
		var wave := 0.0
		match kind:
			"cannon", "enemy_cannon":
				envelope = exp(-t * 8.0)
				var pitch := 72.0 if kind == "cannon" else 58.0
				wave = sin(TAU * pitch * t) * 0.72 + randf_range(-1.0, 1.0) * 0.34 * exp(-t * 24.0)
			"stone_impact", "debris":
				envelope = exp(-t * 17.0)
				wave = sin(TAU * (105.0 - 45.0 * t) * t) * 0.5 + randf_range(-1.0, 1.0) * 0.48
			"explosion":
				envelope = exp(-t * 3.7)
				wave = sin(TAU * (48.0 + 22.0 * exp(-t * 5.0)) * t) * 0.52 + randf_range(-1.0, 1.0) * 0.72
			"fire_impact":
				envelope = exp(-t * 5.5)
				wave = sin(TAU * (180.0 - 95.0 * t) * t) * 0.45 + randf_range(-1.0, 1.0) * 0.42
			"upgrade":
				envelope = exp(-t * 3.2)
				wave = (sin(TAU * 523.25 * t) + sin(TAU * 659.25 * t) + sin(TAU * 783.99 * t)) * 0.22
			"menu":
				envelope = exp(-t * 19.0)
				wave = sin(TAU * 440.0 * t) * 0.42
		var sample := clampf(wave * envelope, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(roundi(sample * 25000.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = pcm
	return stream

func _make_music_stream() -> AudioStreamWAV:
	const RATE := 22050
	const DURATION := 8.0
	var sample_count := int(RATE * DURATION)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var chord_roots := [110.0, 130.81, 98.0, 146.83]
	var melody := [220.0, 261.63, 293.66, 261.63, 196.0, 220.0, 246.94, 220.0]
	for i in range(sample_count):
		var t := float(i) / float(RATE)
		var section := int(floor(t / 2.0)) % chord_roots.size()
		var root_note: float = chord_roots[section]
		var chord := sin(TAU * root_note * t) * 0.18
		chord += sin(TAU * root_note * 1.5 * t) * 0.075
		chord += sin(TAU * root_note * 2.0 * t) * 0.035
		var beat := fposmod(t, 1.0)
		var note_index := int(floor(t)) % melody.size()
		var pluck_envelope := exp(-beat * 4.2) * clampf(1.0 - beat * 7.0, 0.0, 1.0)
		var pluck := sin(TAU * melody[note_index] * t) * pluck_envelope * 0.13
		var air := sin(TAU * 55.0 * t) * 0.025 + sin(TAU * 82.41 * t) * 0.018
		var fade := minf(1.0, minf(t / 0.25, (DURATION - t) / 0.25))
		var sample := clampf((chord + pluck + air) * fade, -0.8, 0.8)
		pcm.encode_s16(i * 2, int(roundi(sample * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream
