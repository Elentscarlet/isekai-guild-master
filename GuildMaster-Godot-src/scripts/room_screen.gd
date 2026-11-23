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
	var selecting_name = ""
	for entry in room.get("players", []):
		if draft and int(entry.get("id", -1)) == int(room.get("selecting_seat", 0)):
			selecting_name = entry.get("name", "")
	var caption_text = "全部准备后开始对局；先选人物，再开始开局轮抽。"
	if draft:
		caption_text = "选择本局人物 · %s 正在选择" % selecting_name if selecting_name else "选择本局人物（黑白面在情报收集后选择）/ 候选仅自己可见"
	apply_language()
	_set_text("Title", room.get("name", "公会房间"))
	_set_text("Caption", caption_text)
	wire_button("Leave", func(): ui.session.leave_room();ui.close_dialog())
	_bind_seats(room, host, draft)
	_bind_left(room, draft, offers, mine, host)
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
		if draft and int(seat.get("id", -1)) == int(room.get("selecting_seat", 0)):
			_mark_selecting(frame)
		(frame.get_node("Name") as Label).text = GuildLang.t(seat.get("name", "等待伙伴"))
		var state = "未准备"
		if not seat.get("connected", true):
			state = "已断线"
		elif seat.get("hero_chosen", false):
			state = "已选择"
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

func _bind_left(room: Dictionary, draft: bool, offers: Array, mine: Dictionary, host: bool) -> void:
	var left = get_node_or_null("LeftPanel") as Panel
	if left == null:
		return
	left.add_theme_stylebox_override("panel", GuildPaperSkin.paper("paper", 0))
	var rules_title = left.get_node("RulesTitle") as Label
	var rules_host = left.get_node("RulesHost") as Button
	rules_host.visible = false
	if draft and not mine.is_empty():
		rules_title.visible = false
		if not offers.has(ui.browsing_character):
			ui.browsing_character = offers[0] if not offers.is_empty() else ""
			ui.candidate_variant = "white"
		for i in range(offers.size()):
			var key = offers[i]
			var identity = ui.store.catalog.characters.get(key, {})
			GuildTableWidgets.action(ui, left, identity.get("pool_name", identity.get("name", key)),
				Rect2(26, 24 + i * 65, 220, 50), func(): ui.browsing_character = key;ui.candidate_variant = "white";ui.rerender())
		_bind_candidates(room, left, mine)
	else:
		rules_title.visible = true
		rules_title.text = GuildLang.t("伙伴正在选择本局角色" if draft else "对局规则")
		var labels = GuildScreens.rule_labels(ui, room)
		GuildTableWidgets.at(left, ui.dialogs.wrapped(" · ".join(labels), 24 if labels.size() <= 14 else 20), Rect2(26, 93, 1080, 256))
		rules_host.visible = host and not draft
		if rules_host.visible:
			wire_button("LeftPanel/RulesHost", func(): ui.dialogs.room_options(), true, true)

func _bind_candidates(room: Dictionary, left: Panel, mine: Dictionary) -> void:
	var identity = ui.store.catalog.characters.get(ui.browsing_character, {})
	var variants = identity.get("variants", {})
	var preview_variant = str(ui.candidate_variant)
	if not _variant_available(variants, preview_variant):
		for variant in ["white", "black"]:
			if _variant_available(variants, variant):
				preview_variant = variant
				break
	ui.candidate_variant = preview_variant
	var hero_key = str(variants.get(preview_variant, ""))
	var hero = ui.store.catalog.heroes.get(hero_key, {})
	if hero.is_empty():
		return
	var solo_replacement = str(hero.get("solo_replacement", "")) if room.get("options", {}).get("solo", false) else ""
	if not solo_replacement.is_empty():
		hero = ui.store.catalog.heroes.get(solo_replacement, hero)
	var x = 420
	GuildTableWidgets.caption(ui, left, identity.get("pool_name", hero.get("name", ui.browsing_character)), Rect2(x, 24, 450, 40), 26, ui.GOLD)
	var portrait = ui.store.portrait(hero_key)
	if portrait == null:
		# 没有独立肖像的角色仍回退到卡面，避免选人页出现空白。
		GuildTableWidgets.at(left, ui.card(hero.source[0], Vector2(350, 500)), Rect2(x, 70, 350, 500))
	else:
		var frame_style = StyleBoxFlat.new()
		frame_style.bg_color = Color("070f14")
		frame_style.border_color = Color("c39a4d")
		frame_style.set_border_width_all(2)
		frame_style.border_width_bottom = 4
		frame_style.set_corner_radius_all(9)
		frame_style.shadow_color = Color(0, 0, 0, 0.38)
		frame_style.shadow_size = 5
		frame_style.shadow_offset = Vector2(2, 2)
		var frame = Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", frame_style)
		GuildTableWidgets.at(left, frame, Rect2(x, 70, 350, 500), "CandidatePortraitFrame")
		var art = GuildPortrait.new()
		GuildTableWidgets.at(frame, art, Rect2(4, 4, 342, 492), "CandidatePortrait")
		art.texture = portrait
		# 选人页展示完整立绘（contain），对局内座位才用裁切半身像（cover）。
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.on_click = func(): ui.dialogs.hero_detail({"hero": hero_key})
	var chosen = mine.get("hero_chosen", false) and mine.get("hero_character", "") == ui.browsing_character
	GuildTableWidgets.action(ui, left, "已选择" if chosen else "选择此角色", Rect2(x+400, 500, 300, 65), func(): ui.session.send({"type": "set_hero", "character": ui.browsing_character}), hero.get("available", false), "ChooseCharacter", true)
	GuildTableWidgets.action(ui, left, "查看三级能力（%s）" % ("白版" if preview_variant == "white" else "黑版"), Rect2(x + 400, 400, 300, 65), func(): ui.dialogs.hero_detail({"hero": hero_key}, 2))
	var other_variant = "black" if preview_variant == "white" else "white"
	var can_switch = _variant_available(variants, other_variant)
	var switch_text = "切换能力预览：%s" % ("黑版" if other_variant == "black" else "白版") if can_switch else "仅有一个可用版本"
	var switch_preview = func():
		ui.candidate_variant = other_variant
		ui.rerender()
	var switch_button = GuildTableWidgets.action(ui, left, switch_text, Rect2(x + 400, 300, 300, 65), switch_preview, can_switch, "SwitchAbilityVariant")
	switch_button.tooltip_text = "只切换能力预览，不决定本局的黑白面。"

func _variant_available(variants: Dictionary, variant: String) -> bool:
	var key = str(variants.get(variant, ""))
	return not key.is_empty() and ui.store.catalog.heroes.get(key, {}).get("available", false)

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
