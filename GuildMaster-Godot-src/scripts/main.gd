extends Control

# 客户端主控制器：持有会话、语音与界面状态，负责偏好/音频/输入，
# 并按会话状态把主页、房间、大厅或桌面挂到 content 下。
#
# 具体分工：
#   ui_kit.gd      控件工厂（label/button/panel/card…）
#   preview.gd     按住 Alt 的放大预览
#   toaster.gd     提示条与终局公告
#   preferences.gd preferences.cfg 的键名与读写
#   screens.gd     实例化 home/room 场景
#   dialogs.gd / dialogs_overlay.gd  弹窗内容

const ThemeBuilder = preload("res://scripts/theme_builder.gd")

const PHASES = {"draft": "开局轮抽", "research": "情报收集", "action": "公会行动", "final": "最终行动", "finished": "终局结算"}
const GOLD = Color("874449")
const INK = Color("343133")
const MUTED = Color("6b6460")

var store = GuildArtStore.new()
var session = GuildSession.new()
var prefs = GuildPreferences.defaults()
var kit = GuildUIKit.new()
var preview: GuildPreview
var toaster: GuildToaster
var voice: GuildVoice
var dialogs: GuildOverlayDialogs
var backdrop: GuildBackdrop
var sound: AudioStreamPlayer
var content: Control
var modal_layer: Control
var dialog: Control
var modal_key = ""
var pending_id = -1

var dirty = true
var last_signature = ""
var selected_research = []
var selection_scroll_states = {}
var research_packet = ""
var hand_page = 0
var selected_tile = ""
var browsing_character = ""
var home_portrait = ""
var choice_states = {}
var player_clocks = []
var renpy_reference = {}

var last_feedback = -1
var last_phase = ""
var last_round = -1
var last_view_player = -1
var last_quest_report = -1
var feedback_scope = ""
var last_action_count = -1

var package_check: GuildPackageCheck
var connection_check: RefCounted
var debug_mode = false

func rerender():
	dirty = true
	last_signature = ""

func undo():
	var state = session.game.get("undo", {})
	if state.get("available", false):
		session.action("undo", {"undo_id": state.get("id")})

# ---------------------------------------------------------------- 生命周期

func _ready():
	renpy_reference = JSON.parse_string(FileAccess.get_file_as_string("res://data/renpy_layout_reference.json"))
	_load_preferences()
	GuildLang.traditional = str(prefs.language) == "zh_TW"
	_apply_frame_settings()
	_build_theme()
	session.rules_catalog = store.catalog
	add_child(session)
	DisplayServer.window_set_title(GuildLang.t("异世界公会长 · Godot"))

	backdrop = GuildBackdrop.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.motion = prefs.motion

	content = Control.new()
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	modal_layer = Control.new()
	add_child(modal_layer)
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.z_index = 30

	kit.ui = self
	preview = GuildPreview.new()
	add_child(preview)
	preview.setup(self)

	toaster = GuildToaster.new()
	toaster.setup(self)

	dialogs = GuildOverlayDialogs.new()
	dialogs.ui = self

	_setup_audio()
	voice = GuildVoice.new()
	add_child(voice)
	voice.setup(self)

	session.changed.connect( func(): dirty = true)
	session.notice.connect(show_toast)
	session.connected.connect( func(): show_toast("公会连接成功。" if session.local_mode else "服务器已确认连接。"))
	resized.connect(preview.place)
	resized.connect(toaster.reposition)
	_render()

	var args = OS.get_cmdline_user_args()
	debug_mode = args.has("--ui-test")
	if args.has("--verify-public-connection"):
		connection_check = load("res://scripts/connection_check.gd").new()
		connection_check.run(self)
		return
	if args.has("--verify-package"):
		package_check = GuildPackageCheck.new()
		package_check.run(self)
		return
	if args.has("--demo") or debug_mode:
		call_deferred("_start_demo")

func _exit_tree():
	session.close()
	stop_audio()

# ---------------------------------------------------------------- 控件转发

# 界面代码统一通过 ui.* 取控件；实现都在 ui_kit.gd。
func box(fill: Color, border: Color, radius: int = 12, padding: int = 16) -> StyleBoxFlat:
	return kit.box(fill, border, radius, padding)

func label(text: String, points: int = 20, color: Color = INK) -> Label:
	return kit.label(text, points, color)

func button(text: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	return kit.button(text, callback, enabled, primary)

func wire_button(node: Button, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	return kit.wire_button(node, callback, enabled, primary)

func symbol(kind: String, points: int = 32) -> TextureRect:
	return kit.symbol(kind, points)

func picture(texture: Texture2D, points: int = 32) -> TextureRect:
	return kit.picture(texture, points)

func resource(kind: String, value, help: String, points: int = 25) -> HBoxContainer:
	return kit.resource(kind, value, help, points)

func box_button(text: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	return kit.box_button(text, callback, enabled, primary)

func step_button(text: String, callback: Callable, enabled: bool = true) -> Button:
	return kit.step_button(text, callback, enabled)

func symbol_button(kind: String, help: String, callback: Callable, enabled: bool = true) -> Button:
	return kit.symbol_button(kind, help, callback, enabled)

func art_button(source: String, help: String, callback: Callable, enabled: bool = true) -> Button:
	return kit.art_button(source, help, callback, enabled)

func cost_button(title: String, kind: String, value, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	return kit.cost_button(title, kind, value, callback, enabled, primary)

func panel(child: Control, padding: int = 20) -> PanelContainer:
	return kit.panel(child, padding)

func scroll(child: Control, dimensions: Vector2 = Vector2.ZERO) -> ScrollContainer:
	return kit.scroll(child, dimensions)

func preserve_selection_scroll(scroller: ScrollContainer, context: String, packet: String) -> void:
	kit.preserve_selection_scroll(scroller, context, packet)

func card(source: String, dimensions: Vector2 = Vector2(150, 208), callback: Callable = Callable(), magnification: float = 2.5) -> GuildCardArt:
	return kit.card(source, dimensions, callback, magnification)

# ---------------------------------------------------------------- 偏好与外观

func _load_preferences():
	GuildPreferences.load_into(prefs)

func save_preferences():
	GuildPreferences.save(prefs)
	backdrop.motion = prefs.motion
	_apply_audio()
	if is_instance_valid(voice):
		voice.apply_settings()
	_apply_frame_settings()

func apply_language(persist: bool = false):
	prefs.language = "zh_TW" if str(prefs.get("language", "zh_CN")) == "zh_TW" else "zh_CN"
	GuildLang.traditional = prefs.language == "zh_TW"
	if persist:
		save_preferences()
	_build_theme()
	DisplayServer.window_set_title(GuildLang.t("异世界公会长 · Godot"))

func set_language(code: String):
	prefs.language = "zh_TW" if str(code) == "zh_TW" else "zh_CN"
	apply_language(true)
	rerender()

func _build_theme():
	theme = ThemeBuilder.build(self)

func _apply_frame_settings():
	var limit = int(prefs.frame_limit)
	if limit not in [0, 60, 120, 144, 240]:
		limit = 240
	prefs.frame_limit = limit
	Engine.max_fps = limit
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if prefs.vsync else DisplayServer.VSYNC_DISABLED)

# ---------------------------------------------------------------- 音频

func _setup_audio():
	for bus in ["SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	sound = AudioStreamPlayer.new()
	sound.bus = "SFX"
	sound.max_polyphony = 4
	add_child(sound)
	_apply_audio()

func _apply_audio():
	if sound == null:
		return
	var index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(index, linear_to_db(max(0.0001, float(prefs.sound_volume))))
	AudioServer.set_bus_mute(index, not prefs.sounds)

func play_sound(kind: String = "click"):
	if not prefs.sounds:
		return
	var path = "res://audio/guild_" + kind + ".wav"
	if ResourceLoader.exists(path):
		sound.stream = load(path)
		sound.play()

func stop_audio():
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null
	if is_instance_valid(voice):
		voice.stop()

# ---------------------------------------------------------------- 每帧状态

func _process(_delta):
	# 单人 / 多人各有一版印刷卡面（face_variants.solo）；模式变化时重建画面。
	var wanted_mode = "multi"
	if not session.game.is_empty() and bool(session.game.get("options", {}).get("solo", false)):
		wanted_mode = "solo"
	if store.mode != wanted_mode:
		store.mode = wanted_mode
		dirty = true
	preview.set_zoomed(Input.is_key_pressed(KEY_ALT))
	if preview.visible:
		preview.place()
	if dirty:
		dirty = false
		var copy = session.game.duplicate(true)
		copy.erase("clock")
		var signature = JSON.stringify([session.room, copy, session.rooms, session.active, session.synchronized, session.directory, session.room_connected, session.role, session.player_id])
		if signature != last_signature:
			last_signature = signature
			_render()
			dialogs.refresh_snapshot()
	var banks = session.game.get("clock", {})
	banks = banks if banks is Dictionary else {}
	for item in player_clocks:
		if is_instance_valid(item.label) and banks.has(item.id):
			item.label.text = "%ss + %ss" % [int(banks[item.id].base), int(banks[item.id].reserve)]

func _input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if modal_key == "pending":
			dialogs.settings()
			return
		if dialog:
			close_dialog()
		else:
			dialogs.settings()
	elif event.keycode == KEY_F11:
		get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

# ---------------------------------------------------------------- 画面分发

func _render():
	if is_instance_valid(voice):
		voice.sync()
	if session.game.is_empty():
		toaster.hide_final()
		last_phase = ""
		last_feedback = -1
		last_round = -1
		last_action_count = -1
		feedback_scope = ""
		last_view_player = -1
		last_quest_report = -1
	elif session.game.get("phase") == "finished" and last_phase != "finished":
		toaster.hide_final()
		if modal_key != "settings":
			close_dialog(false)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	preview.clear()
	var freshly_home = session.game.is_empty() and session.room.is_empty() and not session.directory
	if freshly_home and not backdrop.home:
		home_portrait = ""
	backdrop.home = freshly_home
	backdrop.queue_redraw()
	if session.game.is_empty():
		selection_scroll_states.clear()
	if session.game.is_empty() and not session.room.is_empty():
		GuildScreens.room(self, content)
		return
	if session.game.is_empty() and not session.directory:
		GuildScreens.home(self, content)
		return
	if not session.game.is_empty():
		_render_game(content)
		_sync_game_feedback()
		var current_pending = session.game.get("pending")
		if current_pending is Dictionary and int(current_pending.player) == session.player_id:
			if modal_key not in ["market", "settings", "payment_preference", "seat"] and pending_id != int(current_pending.id):
				dialogs.pending(current_pending)
		elif modal_key == "pending":
			close_dialog()
		return
	var screen = load("res://ui/lobby_screen.tscn").instantiate()
	content.add_child(screen)
	screen.bind(self)
	var pending = session.game.get("pending")
	if pending is Dictionary and int(pending.player) == session.player_id:
		if modal_key != "seat" and pending_id != int(pending.id):
			dialogs.pending(pending)
	elif modal_key == "pending":
		close_dialog()

func _render_game(root: Control):
	if prefs.get("layout", "classic") == "dashboard":
		GuildTableDashboard.draw(self, root)
	else:
		GuildTableClassic.draw(self, root)

func _sync_game_feedback():
	var game = session.game
	var phase = game.get("phase", "")
	var feedback = game.get("feedback", {})
	var scope = session.room_id
	var event_id = int(feedback.get("id", 0))
	var round_number = int(game.get("round", 1))
	var actions = int(game.get("action_count", 0))
	var was_scope = feedback_scope
	var was_phase = last_phase
	if not was_phase.is_empty() and was_scope == scope:
		if phase == "final" and was_phase != "final":
			play_sound("final")
			toaster.show_final()
		elif last_feedback != event_id:
			play_sound(feedback.get("kind", "card"))
			show_toast(feedback.get("message", ""))
		elif was_phase != phase or last_round != round_number:
			play_sound("season")
		elif last_action_count != actions:
			play_sound("card")
	feedback_scope = scope
	last_feedback = event_id
	last_phase = phase
	last_round = round_number
	last_action_count = actions
	# 客座模式：行动席换人时弹公告，确认后继续（终局结算不再弹）。
	var seat = int(game.view_player) if game.get("view_player") != null else -1
	if session.local_mode and phase != "finished" and seat >= 0 and last_view_player >= 0 and seat != last_view_player and modal_key != "seat":
		dialogs.seat_change(seat)
	last_view_player = seat
	# 公会委托板：每季结算后弹出完成公告。
	var report = game.get("quest_report", {})
	var report_serial = int(report.get("serial", 0)) if report is Dictionary else 0
	if was_scope == scope and not was_phase.is_empty() and report_serial > 0 and report_serial != last_quest_report and modal_key != "quest_report":
		dialogs.quest_report(report)
	last_quest_report = report_serial

# ---------------------------------------------------------------- 弹窗外壳

# 简单弹窗（公会大厅/创建房间等）直接搭一个遮罩 + 纸张外框。
# 参考版式的弹窗走 dialogs_overlay.overlay()，使用 ui/dialog_frame.tscn 场景。
func open_dialog(title: String, dimensions: Vector2 = Vector2(1020, 760), key: String = "") -> VBoxContainer:
	close_dialog(false)
	modal_key = key
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.68)
	modal_layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog = shade
	var container = PanelContainer.new()
	container.add_theme_stylebox_override("panel", GuildPaperSkin.player_frame(20))
	shade.add_child(container)
	container.size = dimensions
	container.position = (size - dimensions) / 2
	var body = VBoxContainer.new()
	container.add_child(body)
	var header = HBoxContainer.new()
	body.add_child(header)
	var heading = label(title, 28, GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if key != "pending":
		header.add_child(button("关闭", close_dialog))
	if prefs.motion:
		container.modulate.a = 0
		container.position.y += 16
		var tween = create_tween().set_parallel(true)
		tween.tween_property(container, "modulate:a", 1.0, 0.18)
		tween.tween_property(container, "position:y", container.position.y - 16, 0.18)
	return body

func close_dialog(restore_pending: bool = true):
	if dialog:
		dialog.queue_free()
		dialog = null
	modal_key = ""
	pending_id = -1
	preview.clear()
	if restore_pending:
		rerender()

func show_toast(message: String):
	toaster.show(message)

# ---------------------------------------------------------------- 演示 / 测试入口

func _start_demo():
	if FileAccess.file_exists("res://data/demo.json"):
		var state = GuildSession.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://data/demo.json")))
		session.set_process(false)
		session.game = state.game
		session.room = state.room
		session.player_id = 0
		session.role = "player"
		session.active = true
		dirty = true
		session.synchronized = true
		session.room_connected = true
