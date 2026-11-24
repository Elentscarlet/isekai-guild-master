class_name GuildRoomScreen
extends GuildScreen

# 房间准备页：标题、座位框、左右面板都在 room_screen.tscn 里摆，
# 这里按房间状态显示/隐藏、填文字、接回调。
# 候选角色列表与规则文字是动态内容，生成到 LeftPanel 内（位置随面板一起移动）。

func bind(owner) -> void:
	ui = owner
	var room = ui.session.room
	var host = int(room.get("host_id", -1)) == ui.session.player_id
	var draft = room.get("drafting", false)
	var offers = room.get("hero_offers", [])
	var mine = {}
	for seat in room.get("players", []):
		if int(seat.id) == ui.session.player_id:
			mine = seat
	var selecting = ui.session.character_selector()
	var caption_text = "全部准备后开始对局；先选人物，再开始开局轮抽。"
	if draft:
		if selecting.is_empty():
			caption_text = "等待公会长锁定本局角色。"
		elif selecting.get("hero_chosen", false):
			caption_text = "角色已锁定，等待其他公会长。"
		elif not ui.session.pending_character.is_empty():
			caption_text = "正在确认角色…"
		else:
			caption_text = "%s · 点选肖像，再确认角色。" % selecting.get("name", "")
	apply_language()
	_set_text("Title", room.get("name", "公会房间"))
	_set_text("Caption", caption_text)
	wire_button("Leave", func(): ui.session.leave_room();ui.close_dialog())
	_bind_seats(room, host, draft)
	_bind_left(room, draft, offers, selecting, host)
	_bind_right(room, draft, mine, host)

func _set_text(path: String, text: String) -> void:
	var node = get_node_or_null(path) as Label
	if node != null:
		node.text = GuildLang.t(text)

func _bind_seats(room: Dictionary, host: bool, draft: bool) -> void:
	var players = room.get("players", [])
	var maxp = int(room.get("max_players", 1))
	for i in range(5):
		var frame = get_node_or_null("Seat%d" % i) as Panel
		if frame == null:
			continue
		frame.visible = i < maxp
		if not frame.visible:
			continue
		frame.add_theme_stylebox_override("panel", GuildPaperSkin.paper("paper", 0))
		var seat = players[i] if i < players.size() else {}
		if draft and room.has("selecting_seat") and int(seat.get("id", -1)) == int(room.selecting_seat):
			_mark_selecting(frame)
		(frame.get_node("Name") as Label).text = GuildLang.t(seat.get("name", "等待伙伴"))
		var state = "未准备"
		if not seat.get("connected", true):
			state = "已断线"
		elif seat.get("hero_chosen", false):
			state = "已锁定"
		elif seat.get("ready", false):
			state = "已准备"
		(frame.get_node("Status") as Label).text = GuildLang.t(state)
		var kick = frame.get_node("Kick") as Button
		kick.visible = host and not seat.is_empty() and int(seat.get("id", -1)) != ui.session.player_id
		if kick.visible:
			wire_button("Seat%d/Kick" % i, func(): ui.dialogs.confirm_kick(seat))

# 正在选角的座位加一圈红边。
func _mark_selecting(frame: Panel) -> void:
	var border = Panel.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.name = "SelectingBorder"
	var style = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color("874449")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	border.add_theme_stylebox_override("panel", style)
	border.z_index = 5
	frame.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _bind_left(room: Dictionary, draft: bool, offers: Array, selecting: Dictionary, host: bool) -> void:
	var left = get_node_or_null("LeftPanel") as Panel
	if left == null:
		return
	left.add_theme_stylebox_override("panel", GuildPaperSkin.paper("paper", 0))
	var rules_title = left.get_node("RulesTitle") as Label
	var rules_host = left.get_node("RulesHost") as Button
	rules_host.visible = false
	if draft and not selecting.is_empty():
		rules_title.text = GuildLang.t("候选角色")
		_bind_candidates(room, left, offers, selecting)
	else:
		rules_title.visible = true
		rules_title.text = GuildLang.t("伙伴正在选择本局角色" if draft else "对局规则")
		var labels = GuildScreens.rule_labels(ui, room)
		GuildTableWidgets.at(left, ui.dialogs.wrapped(" · ".join(labels), 24 if labels.size() <= 14 else 20), Rect2(26, 93, 1080, 256))
		rules_host.visible = host and not draft
		if rules_host.visible:
			wire_button("LeftPanel/RulesHost", func(): ui.dialogs.room_options(), true, true)

func _bind_candidates(room: Dictionary, left: Panel, offers: Array, selecting: Dictionary) -> void:
	if offers.is_empty():
		return
	var gap = 16.0
	var top = 76.0
	var slot_width = minf(322.0, (left.size.x - 52.0 - (offers.size() - 1) * gap) / offers.size())
	var row_width = offers.size() * slot_width + (offers.size() - 1) * gap
	var slot_height = left.size.y - top - 18.0
	var selected: String = ui.session.character_choice()
	var solo = bool(room.get("options", {}).get("solo", false))
	var can_select: bool = ui.session.can_select_character()
	for index in range(offers.size()):
		var origin = Vector2((left.size.x - row_width) / 2 + index * (slot_width + gap), top)
		var key = str(offers[index])
		var identity: Dictionary = ui.store.catalog.characters.get(key, {})
		var faces: Dictionary = ui.store.character_faces(key, solo)
		if faces.is_empty():
			continue
		var hero_key = str(faces.get("white", faces.get("black", "")))
		var texture: Texture2D = ui.store.portrait(hero_key)
		if texture == null:
			var sources: Array = ui.store.catalog.heroes[hero_key].get("source", [])
			if not sources.is_empty():
				texture = ui.store.texture(sources[0])
		_place_candidate(left, Rect2(origin, Vector2(slot_width, slot_height)), index, key,
			str(identity.get("pool_name", identity.get("name", key))), texture, key == selected,
			can_select)

func _place_candidate(left: Panel, slot: Rect2, index: int, key: String, title: String, texture: Texture2D, selected: bool, enabled: bool) -> void:
	var natural = texture.get_size() if texture != null else Vector2(9, 16)
	var portrait_size = natural * minf((slot.size.x - 12.0) / natural.x, (slot.size.y - 44.0) / natural.y)
	var frame_size = portrait_size + Vector2(12, 12)
	var frame_position = slot.position + (slot.size - frame_size - Vector2(0, 26)) / 2
	var frame = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color = Color("e5b449")  
	var resting = _candidate_border(color if selected else Color("8d795c"), 6 if selected else 2)
	frame.add_theme_stylebox_override("panel", resting)
	GuildTableWidgets.at(left, frame, Rect2(frame_position, frame_size), "CandidateFrame%d" % index)

	var select_portrait = func():
		ui.play_sound("card")
		ui.session.select_character(key)
	var portrait = GuildPortrait.new()
	portrait.texture = texture
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	GuildTableWidgets.at(frame, portrait, Rect2(Vector2(6, 6), portrait_size), "CandidatePortrait%d" % index)
	portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	if enabled:
		var hovered = _candidate_border(Color("a05459"), 4)
		if selected:
			hovered = resting
		portrait.on_click = select_portrait
		portrait.mouse_entered.connect(func(): frame.add_theme_stylebox_override("panel", hovered))
		portrait.mouse_exited.connect(func(): frame.add_theme_stylebox_override("panel", hovered if portrait.has_focus() else resting))
		portrait.focus_mode = Control.FOCUS_ALL
		portrait.focus_entered.connect(func(): frame.add_theme_stylebox_override("panel", hovered))
		portrait.focus_exited.connect(func(): frame.add_theme_stylebox_override("panel", resting))
		portrait.gui_input.connect(func(event):
			if event.is_action_pressed("ui_accept"):
				select_portrait.call()
				portrait.accept_event())
	var label = GuildTableWidgets.caption(ui, left, title, Rect2(slot.position.x, frame_position.y + frame_size.y + 2, slot.size.x, 26), 20, ui.GOLD if selected else ui.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _candidate_border(color: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = ui.box(Color("211b1b"), color, 8, 0)
	style.set_border_width_all(width)
	return style

func _bind_right(room: Dictionary, draft: bool, mine: Dictionary, host: bool) -> void:
	var right = get_node_or_null("RightPanel") as Panel
	if right == null:
		return
	right.add_theme_stylebox_override("panel", GuildPaperSkin.paper("paper", 0))
	var local = ui.session.local_mode
	(right.get_node("InfoTitle") as Label).text = GuildLang.t("离线单人挑战" if local else "房间信息")
	var guest_label = right.get_node("GuestLabel") as Label
	var guest = right.get_node("GuestButton") as Button
	var load_button = right.get_node("LoadButton") as Button
	var names = right.get_node("NamesButton") as Button
	var ready = right.get_node("ReadyButton") as Button
	var start = right.get_node("StartButton") as Button
	var chat = right.get_node("ChatButton") as Button
	for node in [guest_label, guest, load_button, names, ready, start, chat]:
		node.visible = false
	if local and not draft:
		guest_label.visible = true
		guest_label.text = GuildLang.t("客座模式：%s 位客座玩家" % maxi(0, int(room.get("max_players", 1)) - 1))
		_place(guest, 134)
		wire_button("RightPanel/GuestButton", func(): ui.dialogs.guest_picker())
		_place(load_button, 202)
		wire_button("RightPanel/LoadButton", func(): ui.dialogs.load_picker())
		_place(names, 270)
		wire_button("RightPanel/NamesButton", func(): ui.dialogs.player_names())
	if local and draft:
		_place(names, 96)
		wire_button("RightPanel/NamesButton", func(): ui.dialogs.player_names())
	var chosen: String = ui.session.character_choice()
	if not chosen.is_empty():
		var identity: Dictionary = ui.store.catalog.characters.get(chosen, {})
		var name: String = identity.get("pool_name", identity.get("name", chosen))
		var selected_name = right.get_node("CandidateName") as Label
		var confirmed: bool = ui.session.character_selector().get("hero_chosen", false)
		selected_name.text = GuildLang.t(("已锁定 · " if confirmed else "已选中 · ") + name)
		selected_name.show()
		var confirm = wire_button("RightPanel/CandidateConfirm", ui.session.confirm_character, ui.session.can_select_character(), true)
		confirm.text = GuildLang.t("已确认" if confirmed else "确认中…" if not ui.session.pending_character.is_empty() else "确认角色")
		wire_button("RightPanel/CandidateDetails", func(): ui.dialogs.candidate_details(chosen))
	if not draft and not mine.is_empty():
		if not local:
			_place(ready, 180)
			ready.text = GuildLang.t("取消准备" if mine.get("ready", false) else "准备好了")
			wire_button("RightPanel/ReadyButton", func(): ui.session.send({"type": "ready", "ready": not mine.get("ready", false)}), true, true)
		if host:
			_place(start, 338 if local else 269)
			wire_button("RightPanel/StartButton", func(): ui.session.send({"type": "start"}), room.get("players", []).all(func(seat): return seat.get("ready", false) and seat.get("connected", true)), true)
	if not local:
		_place(chat, 358)
		wire_button("RightPanel/ChatButton", func(): ui.dialogs.chat())

func _place(node: Button, y: float) -> void:
	node.position = Vector2(30, y)
