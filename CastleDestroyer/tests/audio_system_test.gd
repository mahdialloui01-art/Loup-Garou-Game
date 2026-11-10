extends SceneTree

const GameScript = preload("res://scripts/game.gd")

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var game = GameScript.new()
	root.add_child(game)
	await process_frame
	if game.audio_manager == null:
		push_error("Game did not create its audio manager")
		quit(1)
		return
	var audio = game.audio_manager
	if audio.sfx_players.size() < 4 or audio.sfx_streams.size() < 8:
		push_error("Audio manager did not create the required overlapping SFX bank")
		quit(1)
		return
	if audio.music_player.stream == null or audio.music_player.stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		push_error("Procedural background music is missing or not looped")
		quit(1)
		return
	game._set_music_enabled(false)
	if audio.music_player.playing:
		push_error("Music mute setting did not stop background music")
		quit(1)
		return
	game._set_music_enabled(true)
	game._start_game()
	game._fire_selected()
	if game.projectiles.size() != 1:
		push_error("Player firing did not create a projectile")
		quit(1)
		return
	var sfx_started := false
	for player in audio.sfx_players:
		if player.playing:
			sfx_started = true
	if not sfx_started:
		push_error("Cannon firing did not trigger a sound effect")
		quit(1)
		return
	game._set_sfx_enabled(false)
	if audio.sfx_enabled:
		push_error("SFX mute setting did not update the audio manager")
		quit(1)
		return
	print("Audio system tests passed: looping music, volume controls, mute controls and cannon SFX.")
	game.queue_free()
	quit(0)
