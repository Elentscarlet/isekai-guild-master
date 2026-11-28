class_name GuildMusic
extends Node

signal changed

const BUS := "Music"
const EXTENSIONS := ["mp3", "ogg", "wav"]
const FlacDecoder = preload("res://scripts/flac_decoder.gd")

var directory := ""
var tracks := PackedStringArray()
var selected := -1
var error_message := ""
var loading_track := ""
var player: AudioStreamPlayer
var _flac_pid := -1
var _flac_output := ""
var _next_direction := 0
var _remaining_attempts := 0

func setup(initial_volume: float, music_directory: String = "") -> void:
	var root = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	directory = root.path_join("music").simplify_path() if music_directory.is_empty() else music_directory
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	player = AudioStreamPlayer.new()
	player.bus = BUS
	add_child(player)
	player.finished.connect(func():
		if loading_track.is_empty():
			skip(1))
	set_process(false)
	set_volume(initial_volume)
	rescan()
	if not tracks.is_empty():
		_play_candidates(selected, 1, tracks.size())

func rescan() -> void:
	var previous = tracks[selected] if selected >= 0 else ""
	error_message = ""
	tracks.clear()
	var folder = DirAccess.open(directory)
	if folder == null and not DirAccess.dir_exists_absolute(directory):
		if DirAccess.make_dir_recursive_absolute(directory) == OK:
			folder = DirAccess.open(directory)
	if folder == null:
		error_message = "无法访问音乐文件夹。"
	else:
		for file in folder.get_files():
			var extension = file.get_extension().to_lower()
			if extension in EXTENSIONS or (extension == "flac" and FlacDecoder.supported()):
				tracks.append(file)
		tracks.sort()
	selected = tracks.find(previous)
	if selected < 0:
		stop()
		if not tracks.is_empty():
			selected = 0
	elif not loading_track.is_empty() and not tracks.has(loading_track):
		_cancel_flac()
	changed.emit()

func set_volume(value: float) -> void:
	var index = AudioServer.get_bus_index(BUS)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(value, 0.0001, 1.0)))
	AudioServer.set_bus_mute(index, value <= 0.0)

func toggle() -> void:
	if not loading_track.is_empty():
		_cancel_flac()
	elif player.stream_paused:
		player.stream_paused = false
	elif player.playing:
		player.stream_paused = true
	else:
		play_track(selected)
		return
	error_message = ""
	changed.emit()

func play_track(index: int) -> void:
	if index >= 0 and index < tracks.size():
		_cancel_flac()
		_play_candidates(index, 0, 1)

func skip(direction: int) -> void:
	if tracks.is_empty():
		return
	var current = tracks.find(loading_track) if not loading_track.is_empty() else selected
	_cancel_flac()
	_play_candidates(posmod(current + direction, tracks.size()), direction, tracks.size())

func _play_candidates(index: int, direction: int, attempts: int) -> void:
	for offset in range(attempts):
		var candidate = posmod(index + direction * offset, tracks.size())
		if _start_track(candidate, direction, attempts - offset - 1):
			break
	changed.emit()

func stop() -> void:
	_cancel_flac()
	if is_instance_valid(player):
		player.stop()
		player.stream_paused = false
		player.stream = null

func _start_track(index: int, direction: int, remaining: int) -> bool:
	var path = directory.path_join(tracks[index])
	if path.get_extension().to_lower() == "flac" and FileAccess.file_exists(path):
		_flac_output = ProjectSettings.globalize_path("user://music-flac-%s-%s.wav" % [OS.get_process_id(), Time.get_ticks_usec()])
		_flac_pid = FlacDecoder.start(path, _flac_output)
		if _flac_pid >= 0:
			loading_track = tracks[index]
			_next_direction = direction
			_remaining_attempts = remaining
			error_message = ""
			set_process(true)
			return true
		_cancel_flac()
	var stream = _load_audio(path) if FileAccess.file_exists(path) else null
	if stream == null or stream.get_length() <= 0.0:
		error_message = "无法播放：%s" % tracks[index].get_basename()
		return false
	_play_stream(stream, index)
	return true

func _play_stream(stream: AudioStream, index: int) -> void:
	player.stream = stream
	player.stream_paused = false
	selected = index
	error_message = ""
	player.play()

func _process(_delta: float) -> void:
	if OS.is_process_running(_flac_pid):
		return
	var stream: AudioStreamWAV
	if OS.get_process_exit_code(_flac_pid) == 0 and FileAccess.file_exists(_flac_output):
		stream = AudioStreamWAV.load_from_file(_flac_output, {"compress/mode": 0})
	var track = loading_track
	var index = tracks.find(track)
	var direction = _next_direction
	var remaining = _remaining_attempts
	_cancel_flac()
	if index >= 0 and stream != null and stream.get_length() > 0.0:
		_play_stream(stream, index)
	elif index >= 0:
		error_message = "无法播放 FLAC：%s" % track.get_basename()
		if remaining > 0:
			_play_candidates(posmod(index + direction, tracks.size()), direction, remaining)
			return
	changed.emit()

func _cancel_flac() -> void:
	set_process(false)
	if _flac_pid >= 0 and OS.is_process_running(_flac_pid):
		OS.kill(_flac_pid)
	_flac_pid = -1
	loading_track = ""
	if not _flac_output.is_empty():
		if FileAccess.file_exists(_flac_output):
			DirAccess.remove_absolute(_flac_output)
		_flac_output = ""

func _exit_tree() -> void:
	_cancel_flac()

func _load_audio(path: String) -> AudioStream:
	match path.get_extension().to_lower():
		"mp3": return AudioStreamMP3.load_from_file(path)
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
		"wav": return AudioStreamWAV.load_from_file(path)
	return null
