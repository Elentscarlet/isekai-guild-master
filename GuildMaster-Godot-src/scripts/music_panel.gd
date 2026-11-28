class_name GuildMusicPanel
extends PanelContainer

var ui
var music: GuildMusic
var picker: OptionButton
var previous: Button
var play_pause: Button
var next: Button
var volume: HSlider
var _labels := {}
var _last_error := ""

func setup(owner) -> void:
	ui = owner
	music = ui.music
	z_index = 40
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -802
	offset_top = -36
	offset_right = -16
	offset_bottom = -4
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_stylebox_override("panel", ui.box(Color("ece1cc"), Color("846c50"), 6, 3))

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	add_child(row)
	row.add_child(_label("音乐"))

	picker = OptionButton.new()
	picker.name = "MusicTracks"
	picker.custom_minimum_size = Vector2(188, 26)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_compact_style(picker)
	row.add_child(picker)
	picker.item_selected.connect(music.play_track)

	previous = _button("上一首", music.skip.bind(-1))
	play_pause = _button("播放", music.toggle, 82, true)
	play_pause.name = "MusicPlayPause"
	next = _button("下一首", music.skip.bind(1))
	for control in [previous, play_pause, next]:
		row.add_child(control)

	row.add_child(_label("音量"))
	volume = HSlider.new()
	volume.name = "MusicVolume"
	volume.custom_minimum_size.x = 103
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.0025
	volume.value = float(ui.prefs.music_volume)
	row.add_child(volume)
	volume.value_changed.connect(func(value):
		ui.prefs.music_volume = value
		ui.save_preferences()
		_update_volume_label())

	row.add_child(_button("文件夹", _open_folder))
	row.add_child(_button("刷新", music.rescan, 46))

	music.changed.connect(_refresh)
	apply_language()

func apply_language() -> void:
	for control in _labels:
		control.text = GuildLang.t(_labels[control])
	_update_volume_label()
	_refresh()

func _label(text: String) -> Label:
	var label = ui.label(text, 16, ui.GOLD)
	_labels[label] = text
	return label

func _button(text: String, callback: Callable, width: float = 62.0, accent: bool = false) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(width, 26)
	_compact_style(button, accent)
	ui.wire_button(button, callback)
	_labels[button] = text
	return button

func _compact_style(button: Button, accent: bool = false) -> void:
	button.add_theme_font_size_override("font_size", 16)
	var base = Color("874449") if accent else Color("f6ecd9")
	var border = Color("9b7851")
	button.add_theme_stylebox_override("normal", ui.box(base, border, 4, 3))
	button.add_theme_stylebox_override("hover", ui.box(base.lightened(0.10), border, 4, 3))
	button.add_theme_stylebox_override("pressed", ui.box(base.darkened(0.12), border, 4, 3))
	button.add_theme_stylebox_override("disabled", ui.box(Color("e5dbca"), Color("aa9a84"), 4, 3))
	if accent:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(key, Color("fff6e5"))

func _update_volume_label() -> void:
	volume.tooltip_text = GuildLang.t("音乐音量") + " %.2f%%" % (volume.value * 100.0)

func _open_folder() -> void:
	if OS.shell_open(music.directory) != OK:
		ui.show_toast("无法打开音乐文件夹。")

func _refresh() -> void:
	picker.clear()
	var has_tracks = not music.tracks.is_empty()
	picker.disabled = not has_tracks
	previous.disabled = not has_tracks
	play_pause.disabled = not has_tracks
	next.disabled = not has_tracks
	if has_tracks:
		for track in music.tracks:
			picker.add_item(track.get_basename())
		var indicated = music.selected if music.loading_track.is_empty() else music.tracks.find(music.loading_track)
		picker.select(indicated)
		picker.tooltip_text = music.tracks[indicated].get_basename()
	else:
		picker.add_item(GuildLang.t("暂无曲目"))
		picker.tooltip_text = GuildLang.t("把音乐放入文件夹，然后刷新曲目。")
	var playing = music.player.playing and not music.player.stream_paused
	play_pause.text = GuildLang.t("取消读取" if not music.loading_track.is_empty() else "暂停" if playing else "继续播放" if music.player.stream_paused else "播放")
	if not music.loading_track.is_empty():
		picker.tooltip_text = GuildLang.t("正在读取 FLAC") + " · " + music.loading_track.get_basename()
	elif not music.error_message.is_empty() and music.error_message != _last_error:
		ui.show_toast(music.error_message)
	_last_error = music.error_message
