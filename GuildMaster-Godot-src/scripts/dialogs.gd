class_name GuildDialogs
extends RefCounted

# 弹窗的公共底座：几个简单弹窗与共用的小控件。
#
# 参考版式的大多数弹窗在 dialogs_overlay.gd（GuildOverlayDialogs）里重写，
# 这里只保留仍在使用、且不需要参考版排版的弹窗，以及两边都会用到的辅助函数。

var ui

func wrapped(text: String, size: int = 19, color: Color = Color("5b5860")) -> Label:
	var node = ui.label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func integer_row(parent: Control, title: String, maximum: int, value: int = 0, kind: String = "") -> SpinBox:
	var row = HBoxContainer.new()
	parent.add_child(row)
	if not kind.is_empty():
		row.add_child(ui.symbol(kind, 32))
	var title_node = ui.label(title, 19)
	title_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_node)
	var spin = SpinBox.new()
	spin.min_value = 0
	spin.max_value = maximum
	spin.step = 1
	spin.value = value
	spin.custom_minimum_size.x = 140
	row.add_child(spin)
	return spin

func toggle(parent: Control, title: String, value: bool) -> CheckButton:
	var check = CheckButton.new()
	check.text = GuildLang.t(title)
	check.button_pressed = value
	parent.add_child(check)
	return check

func hero_draw_row(parent: Control, value: int, id: String) -> OptionButton:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var title = ui.label("角色候选张数", 19)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var picker = OptionButton.new()
	picker.name = id
	picker.custom_minimum_size.x = 160
	for count in range(1, 6):
		picker.add_item(GuildLang.t("%s 张" % count), count)
	picker.select(clampi(value, 1, 5) - 1)
	row.add_child(picker)
	return picker

func refresh_hero_draw(picker: OptionButton, hint: Label, players: int, banned: Array = []) -> int:
	var limit = GuildRoomSetup.candidate_limit(ui.store.catalog, players, banned)
	for index in range(5):
		picker.set_item_disabled(index, index >= limit)
	if limit > 0 and picker.get_selected_id() > limit:
		picker.select(limit - 1)
	hint.text = "可用角色 %s 名 · 每位最多 %s 张候选" % [GuildRoomSetup.character_pool(ui.store.catalog, banned).size(), limit]
	picker.disabled = limit < 1
	return limit

func submit(kind: String, args: Dictionary = {}):
	ui.session.action(kind, args)
	ui.close_dialog()

func initial_resource_row(parent: Control, key: String, title: String, value, fallback: int, minimum: int) -> Dictionary:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var custom = toggle(row, title + "（自定义）", value != null)
	custom.name = key + "Enabled"
	custom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var amount = SpinBox.new()
	amount.name = key + "Value"
	amount.min_value = minimum
	amount.max_value = 1000
	amount.step = 1
	amount.value = fallback if value == null else int(value)
	amount.editable = custom.button_pressed
	amount.custom_minimum_size.x = 140
	row.add_child(amount)
	custom.toggled.connect( func(enabled): amount.editable = enabled)
	return {"enabled": custom, "amount": amount}

# ---------------------------------------------------------------- 简单弹窗

func enter_room(room: Dictionary, role: String):
	var body = ui.open_dialog("加入 " + room.get("name", "公会"), Vector2(630, 340))
	var password = LineEdit.new()
	password.secret = true
	password.placeholder_text = GuildLang.t("房间密码（无密码可留空）")
	body.add_child(password)
	body.add_child(ui.button("观战" if role == "spectator" else "加入公会", func():
		ui.session.password = password.text
		ui.session.send({"type": "enter_room", "room_id": room.id, "role": role, "password": password.text})
		ui.close_dialog(), true, true))

func create_room():
	var body = ui.open_dialog("创建公会房间", Vector2(710, 780))
	var name = LineEdit.new()
	name.placeholder_text = GuildLang.t("公会名称")
	name.text = "旅人的公会"
	body.add_child(name)
	var password = LineEdit.new()
	password.placeholder_text = GuildLang.t("房间密码（可选）")
	password.secret = true
	body.add_child(password)
	var count = integer_row(body, "最多玩家", 5, 4)
	count.min_value = 1
	count.name = "RoomMaxPlayers"
	var draw = hero_draw_row(body, 2, "CreateHeroDraw")
	var hint = wrapped("", 18)
	hint.name = "HeroPoolHint"
	body.add_child(hint)
	var spectators = toggle(body, "允许观战", true)
	var civ = initial_resource_row(body, "initial_civ", "初始文明", null, 1, 1)
	var miasma = initial_resource_row(body, "initial_miasma", "初始瘴气", null, 40, 0)
	body.add_child(wrapped("不勾选时使用标准初始值；自定义只影响开局，后续照常增减。", 17))
	var create = ui.button("创建", func():
		ui.session.password = password.text
		ui.session.send({"type": "create_room", "room_name": name.text, "password": password.text, "max_players": int(count.value), "allow_spectators": spectators.button_pressed, "options": {"hero_draw": draw.get_selected_id(), "initial_civ": int(civ.amount.value) if civ.enabled.button_pressed else null, "initial_miasma": int(miasma.amount.value) if miasma.enabled.button_pressed else null}})
		ui.close_dialog(), true, true)
	body.add_child(create)
	var refresh = func(): create.disabled = refresh_hero_draw(draw, hint, int(count.value)) < 1
	count.value_changed.connect( func(_value): refresh.call())
	refresh.call()

func hero_ability():
	var me = ui.session.me()
	var hero = ui.store.catalog.heroes.get(me.get("hero", ""), {})
	var ability = hero.get("ability", {})
	if ability.get("discard_min", 0) > 0:
		choose_hand("看板娘特别行动 · 选择弃牌", int(ability.discard_min), int(ability.get("discard_max", ability.discard_min)), func(cards): submit("ability", {"cards": cards}))
	else:
		submit("ability")

func choose_hand(title: String, minimum: int, maximum: int, callback: Callable):
	var body = ui.open_dialog(title, Vector2(1090, 790))
	var grid = GridContainer.new()
	grid.columns = 5
	body.add_child(ui.scroll(grid))
	var selected = []
	var hand = ui.session.me().get("hand", [])
	for i in range(hand.size()):
		var art = ui.card(ui.store.card_face(ui.store.card(hand[i])), Vector2(195, 272))
		art.on_click = func():
			if selected.has(i): selected.erase(i)
			elif selected.size() < maximum: selected.append(i)
			art.selected = selected.has(i)
			art.queue_redraw()
		grid.add_child(art)
	body.add_child(ui.button("确认所选事件", func():
		if selected.size() < minimum:
			ui.show_toast("至少选择 " + str(minimum) + " 张事件。")
			return
		var cards = []
		for i in selected: cards.append(int(hand[i]))
		callback.call(cards), true, true))

func gallery():
	var body = ui.open_dialog("卡牌图鉴", Vector2(1170, 860))
	var search = LineEdit.new()
	search.placeholder_text = GuildLang.t("搜索卡名、编号或关键词")
	body.add_child(search)
	var category = OptionButton.new()
	for title in ["事件卡", "看板娘", "王权", "迷宫板块", "委托", "序章"]:
		category.add_item(GuildLang.t(title))
	body.add_child(category)
	var grid = GridContainer.new()
	grid.columns = 5
	body.add_child(ui.scroll(grid))
	var collections = [ui.store.catalog.cards, ui.store.catalog.heroes, ui.store.catalog.achievements, ui.store.catalog.tiles, ui.store.catalog.quests, ui.store.catalog.prologues]
	var state = {"page": 0, "items": []}
	var page_bar = HBoxContainer.new()
	body.add_child(page_bar)
	var page_label = ui.label("", 18, ui.MUTED)
	var redraw = func():
		for child in grid.get_children(): child.queue_free()
		state.page = clamp(int(state.page), 0, max(0, ceili(float(state.items.size()) / 15) - 1))
		for i in range(int(state.page) * 15, min(state.items.size(), (int(state.page) + 1) * 15)):
			var item = state.items[i]
			var column = VBoxContainer.new()
			grid.add_child(column)
			column.add_child(ui.card(item.source, Vector2(210, 290), func():
				if category.selected == 0: ui.dialogs.card_detail(int(item.key))
				else: ui.dialogs.art_detail(item.source, item.name)))
			column.add_child(wrapped(item.name, 17, ui.INK))
		page_label.text = "%s 张卡 · 第 %s / %s 页" % [state.items.size(), int(state.page) + 1, max(1, ceili(float(state.items.size()) / 15))]
	page_bar.add_child(ui.button("上一页", func(): state.page -= 1;redraw.call()))
	page_bar.add_child(page_label)
	page_bar.add_child(ui.button("下一页", func(): state.page += 1;redraw.call()))
	var filter = func():
		state.items = []
		state.page = 0
		var collection = collections[category.selected]
		for key in collection:
			var data = collection[key]
			if not data.get("available", true): continue
			var index = data.get("name", "") + data.get("printed_code", "") + data.get("ui_summary", "") + data.get("description", "")
			if not search.text.is_empty() and not search.text in index: continue
			var sources = data.get("source", "")
			if sources is String: sources = [sources]
			if category.selected == 0: sources = [ui.store.card_face(data)]
			for i in range(sources.size()):
				state.items.append({"key": key, "name": data.get("name", key) + (" / " + data.get("subtitle", "") + " / 等级" + str(i + 1) if category.selected == 1 else ""), "source": sources[i]})
		redraw.call()
	search.text_changed.connect( func(_text): filter.call())
	category.item_selected.connect( func(_index): filter.call())
	filter.call()

# ---------------------------------------------------------------- 共用设置

func frame_settings(body: Control):
	var frame_row = HBoxContainer.new()
	body.add_child(frame_row)
	var frame_title = ui.label("帧率上限", 19)
	frame_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_row.add_child(frame_title)
	var frames = OptionButton.new()
	frames.name = "FrameLimit"
	frame_row.add_child(frames)
	for limit in [60, 120, 144, 240, 0]:
		frames.add_item(GuildLang.t("不限" if limit == 0 else "%s FPS" % limit), limit)
		if limit == int(ui.prefs.frame_limit): frames.select(frames.item_count - 1)
	frames.item_selected.connect( func(_index): ui.prefs.frame_limit = frames.get_selected_id();ui.save_preferences())
	var vsync = toggle(body, "垂直同步", ui.prefs.vsync)
	vsync.name = "VSync"
	vsync.toggled.connect( func(value): ui.prefs.vsync = value;ui.save_preferences())
	body.add_child(wrapped("默认上限 240 FPS。开启垂直同步后，帧率也会受显示器刷新率限制。", 17))
