extends SceneTree

# 16 frames of stereo PCM at 44.1 kHz, encoded as constant FLAC subframes.
const FLAC_TEST := "ZkxhQ4AAACIQABAAAAAAAAAACsRC8AABAAAyXWbYqOAQt+Q59Ncj/PTW//jJGADCAPzgAAKAH2D/+MkYAcUA/UQAAjBb/f/4yRgCzAD9qAAB4Jqq//jJGAPLAP4MAAGQXET/+MkYBN4A/nAAAUCK8f/4yRgF2QD+1AAA8MgU//jJGAbQAP84AACgADv/+MkYB9cA/5wAAFBFXv/4yRgI+gAAAAAAAINd//jJGAn9AABkAP+wxZb/+MkYCvQAAMgA/2CO3P/4yRgL8wABLAD/EEjc//jJGAzmAAGQAP7AGEj/+MkYDeEAAfQA/nDcjP/4yRgO6AACWAD+IBRN//jJGA/vAAK8AP3Q2zU="
const FLAC_HIGH_RES := "ZkxhQ4AAACIQABAAAAAAAAAAF3ADcAAAgACiYT1UcfWC24zk/FO1YU9F//jLHABAAOunrAANN6z2a//4yxwBRwDwvcEACenB+Z3/+MscAk4A9dPWAAab1hOo//jLHANJAPrp6wADTeuhS//4yxwEXAAAAAAAAAAAt47/+MscBVsABRYVAPyyFXeh//jLHAZSAAosKgD5ZCoj1v/4yxwHVQAPQj8A9hY/L3c="

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func play_to_end(music: GuildMusic) -> void:
	var current = music.selected
	music.player.seek(music.player.stream.get_length() - 0.1)
	var deadline = Time.get_ticks_msec() + 12000
	while music.selected == current and Time.get_ticks_msec() < deadline:
		await process_frame

func click(control: Control) -> void:
	var point = control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func run() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	var music: GuildMusic = ui.music
	var folder = ProjectSettings.globalize_path("user://music-qa-" + str(Time.get_ticks_usec()))
	music.stop()
	music.directory = folder
	music.rescan()
	var panel = ui.music_bar as GuildMusicPanel
	check(panel != null and panel.is_visible_in_tree() and ui.dialog == null and panel.play_pause.disabled,
		"the music bar is visible directly on the home screen with an empty playlist")
	check(DirAccess.dir_exists_absolute(folder), "the music directory is created")
	if panel == null:
		quit(1)
		return

	var tone = AudioStreamWAV.new()
	tone.mix_rate = 8000
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	var silence = PackedByteArray()
	silence.resize(80000)
	tone.data = silence
	check(tone.save_to_wav(folder.path_join("01.片头.wav")) == OK, "WAV test fixture written")
	var ogg = ProjectSettings.globalize_path(GuildVoice.PREFIX + "card-white-r1.ogg")
	check(DirAccess.copy_absolute(ogg, folder.path_join("02.OGG")) == OK, "Ogg test fixture copied")
	# MPEG-1 Layer III silence, 128 kbps at 44.1 kHz.
	var mp3_frame = PackedByteArray([0xff, 0xfb, 0x90, 0x00])
	mp3_frame.resize(417)
	var mp3 = FileAccess.open(folder.path_join("03.mp3"), FileAccess.WRITE)
	for _index in range(96):
		mp3.store_buffer(mp3_frame)
	mp3.close()
	var expected = PackedStringArray(["01.片头.wav", "02.OGG", "03.mp3"])
	if OS.has_feature("windows"):
		var flac_name = "04-测试 '曲目'.FLAC"
		var flac = FileAccess.open(folder.path_join(flac_name), FileAccess.WRITE)
		flac.store_buffer(Marshalls.base64_to_raw(FLAC_TEST))
		flac.close()
		expected.append(flac_name)
	var note = FileAccess.open(folder.path_join("notes.txt"), FileAccess.WRITE)
	note.store_string("not an audio file")
	note.close()
	music.rescan()
	check(music.tracks == expected, "rescan shows supported extensions in order")
	check(panel.picker.get_item_text(0) == "01.片头" and panel.picker.get_item_text(1) == "02"
		and panel.picker.tooltip_text == "01.片头", "song names retain inner periods and omit their filename extensions")

	var startup = GuildMusic.new()
	root.add_child(startup)
	var default_volume: float = GuildPreferences.defaults().music_volume
	startup.setup(default_volume, folder)
	check(startup.player.playing and startup.selected == 0, "starting with tracks plays the first track automatically")
	var bus_index = AudioServer.get_bus_index("Music")
	check(is_equal_approx(default_volume, 0.3375)
		and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.3375)
		and is_equal_approx(panel.volume.value, 0.3375), "default music volume is exactly 33.75 percent")
	startup.stop()
	root.remove_child(startup)
	startup.queue_free()

	panel.play_pause.pressed.emit()
	check(music.player.playing and music.player.stream is AudioStreamWAV, "play opens an external WAV track")
	panel.play_pause.pressed.emit()
	check(music.player.stream_paused, "pause keeps the current track")
	panel.play_pause.pressed.emit()
	check(not music.player.stream_paused, "play resumes the paused track")
	panel.picker.item_selected.emit(1)
	check(music.selected == 1 and music.player.stream is AudioStreamOggVorbis, "selecting a track plays external Ogg")
	panel.previous.pressed.emit()
	check(music.selected == 0, "previous plays the preceding track")
	panel.next.pressed.emit()
	check(music.selected == 1, "next plays the following track")
	await play_to_end(music)
	check(music.selected == 2 and music.player.stream is AudioStreamMP3, "finishing a track advances to external MP3")
	await play_to_end(music)
	if OS.has_feature("windows"):
		var decoded = music.player.stream as AudioStreamWAV
		check(music.selected == 3 and decoded != null and decoded.stereo and decoded.mix_rate == 44100,
			"finishing MP3 advances to FLAC and preserves its stereo sample rate")
		await play_to_end(music)
	check(music.selected == 0 and music.player.playing, "the playlist wraps when a track finishes")
	if OS.has_feature("windows"):
		panel.picker.item_selected.emit(3)
		check(not music.loading_track.is_empty(), "choosing FLAC starts a background decode")
		panel.picker.item_selected.emit(0)
		check(music.loading_track.is_empty() and music.selected == 0 and music.player.stream is AudioStreamWAV,
			"changing tracks cancels an in-progress FLAC decode")
		var temporary = DirAccess.get_files_at("user://")
		check(not Array(temporary).any(func(name): return name.begins_with("music-flac-")),
			"completed and canceled decodes leave no temporary WAV files")

	var slider = panel.volume
	slider.value = 0.2
	var saved = GuildPreferences.defaults()
	GuildPreferences.load_into(saved)
	check(is_equal_approx(saved.music_volume, 0.2), "music volume persists in preferences")
	var music_bus = AudioServer.get_bus_index("Music")
	var sound_bus = AudioServer.get_bus_index("SFX")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.2)
		and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sound_bus)), float(ui.prefs.sound_volume)),
		"music volume is independent of sound effects")
	var fixture = GuildSession.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://data/qa-2.json")))
	ui.session.set_process(false)
	ui.session.game = fixture.game
	ui.session.room = fixture.room
	ui.session.player_id = 0
	ui._render()
	await process_frame
	var hand = ui.content.find_child("HandStrip", true, false) as Control
	check(ui.music_bar == panel and panel.is_visible_in_tree() and hand != null
		and ui.get_global_rect().encloses(panel.get_global_rect())
		and not panel.get_global_rect().intersects(hand.get_global_rect()), "the same music bar remains below the game controls")
	ui.dialogs.settings()
	await process_frame
	await click(panel.play_pause)
	check(ui.modal_key == "settings" and music.player.stream_paused, "the music bar accepts clicks while a game dialog is open")
	await click(panel.play_pause)
	check(not music.player.stream_paused, "the exterior music bar can also resume playback")
	ui.close_dialog(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-screenshot="):
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(arg.trim_prefix("--qa-screenshot=")) == OK, "music panel screenshot written")
	await process_frame
	check(music.player.playing, "music keeps playing after closing the game dialog")
	music.rescan()
	check(music.selected == 0 and music.player.playing, "rescanning retains the currently playing track")
	if OS.has_feature("windows"):
		var high_res = FileAccess.open(folder.path_join("05-hires.flac"), FileAccess.WRITE)
		high_res.store_buffer(Marshalls.base64_to_raw(FLAC_HIGH_RES))
		high_res.close()
		music.rescan()
		music.play_track(4)
		var deadline = Time.get_ticks_msec() + 12000
		while not music.loading_track.is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		var decoded = music.player.stream as AudioStreamWAV
		check(music.selected == 4 and decoded != null and decoded.stereo and decoded.mix_rate == 96000,
			"24-bit FLAC plays at its original 96 kHz sample rate")
	ui.stop_audio()
	print("MUSIC_QA " + ("PASSED" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)
