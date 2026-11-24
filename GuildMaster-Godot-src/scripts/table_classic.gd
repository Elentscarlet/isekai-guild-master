class_name GuildTableClassic
extends RefCounted

# 「经典」桌面布局：地图、命令、手牌三块。布局与控件都在
# ui/table_layout_classic.tscn 里摆好，这里只填文字、显隐与动态列表
# （玩家座位、王权卡、日志行、手牌、秘药按钮内容）。
#
# 顶栏与左侧座位属于 ui/table_screen.tscn，由 table_screen.gd 绑定。

static func fill(ui, screen, layout: Control) -> void:
	var game = ui.session.game
	var me = ui.session.me()
	var phase = str(game.get("phase", ""))
	# 布局根节点只用于摆位，不接收鼠标，否则会挡住顶栏和左侧座位。
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var actor = game.players[int(game.get("turn", 0))]
	var focus = me if not me.is_empty() else actor
	var map_panel = layout.get_node("MapPanel") as Panel
	map_panel.visible = true
	var title = map_panel.get_node("TurnTitle") as Label
	title.text = GuildLang.t(actor.get("name", focus.name) + "的回合" if phase in ["action", "final"] else "等待公会完成情报收集")
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text = title.text
	(map_panel.get_node("MapName") as Label).text = GuildLang.t(str(game.get("map_name", "迷宫疆域")))
	var map = map_panel.get_node("TableMap") as GuildHexMap
	map.store = ui.store
	map.motion = ui.prefs.motion
	map.renpy_geometry = true
	map.set_game(game, ui.session.player_id)
	map.chosen_ids = [ui.selected_tile]
	for legend in ["LegendExplore", "LegendChosen", "LegendHint"]:
		(map_panel.get_node(legend) as Control).visible = phase != "final"
	stock(ui, map_panel, focus)
	commands(ui, layout, map, game, me, focus)
	var hand_strip = layout.get_node("HandStrip") as Panel
	hand_strip.visible = true
	hand(ui, hand_strip, me)
	final_status(ui, layout, game, phase)

static func stock(ui, parent: Control, focus: Dictionary) -> void:
	action_reminders(ui, parent)
	var affection = int(focus.get("affection", 0))
	(parent.get_node("AffectionTitle") as Label).text = GuildLang.t("好感度")
	var hearts_panel = parent.get_node("AffectionHearts") as Panel
	hearts_panel.tooltip_text = GuildLang.t("好感度 %s / 5 · 点按打开发展界面" % affection)
	if not hearts_panel.has_meta("guild_develop_click"):
		hearts_panel.set_meta("guild_develop_click", true)
		hearts_panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				ui.dialogs.develop())
	for i in range(5):
		var heart = hearts_panel.get_node("HeartsRow/Slot%d/Heart" % i) as TextureRect
		heart.modulate.a = 1.0 if i < affection else 0.2
	(parent.get_node("PotionsTitle") as Label).text = GuildLang.t("秘药行动")
	for key in ["gold", "strength", "knowledge", "build", "free_card", "power"]:
		GuildTableWidgets.fill_potion(ui, parent.get_node("Potion_" + key) as Button, key)

# 迷宫地图右侧、好感度上方：可用行动提醒区（点按直达对应界面）。
static func action_reminders(ui, parent: Control) -> void:
	var hints = ui.session.game.get("hints", {})
	if not hints is Dictionary:
		hints = {}
	var frame = parent.get_node("ActionReminders") as Panel
	var enabled = ui.session.can_act()
	if not GuildTableWidgets.region_changed(frame, "hints", [hints, ui.session.player_id, enabled, GuildLang.traditional]):
		return
	var rows = []
	if hints.get("achievements", []).size() > 0:
		rows.append(["◆ 可完成成就 ×%s" % hints.achievements.size(), func(): ui.dialogs.achievements(), "有已满足条件的王权卡；点按打开王权界面完成"])
	if hints.get("develop", []).size() > 0:
		rows.append(["◆ 可解锁好感度", func(): ui.dialogs.develop(), "有可解锁的发展条件；点按打开发展界面"])
	if bool(hints.get("ability", false)) or int(hints.get("card_actions", 0)) > 0:
		rows.append(["◆ 可用特殊行动", func(): ui.dialogs.abilities(), "看板娘能力或卡牌特别行动可发动；点按打开特殊行动界面"])
	if hints.get("expansions", []).size() > 0:
		rows.append(["◆ 可用扩展行动 ×%s" % hints.expansions.size(), func(): ui.dialogs.expansions(), "扩展行动可执行；点按打开扩展行动界面"])
	if hints.get("potions", []).size() > 0:
		rows.append(["◆ 可用秘药行动 ×%s" % hints.potions.size(), func(): ui.dialogs.potions(), "秘药行动可使用；点按打开秘药工坊"])
	frame.size.y = 50 if rows.is_empty() else 27 + rows.size() * 21 + (rows.size() - 1) * 2 + 7
	var column = frame.get_node("ReminderColumn") as VBoxContainer
	clear(column)
	column.visible = not rows.is_empty()
	var notice = frame.get_node_or_null("EmptyNotice") as Label
	if notice != null:
		notice.visible = rows.is_empty()
	if rows.is_empty():
		var text = "观战中" if ui.session.me().is_empty() else "暂无可操作的行动"
		if notice == null:
			notice = GuildTableWidgets.caption(ui, frame, text, Rect2(10, 27, 174, 18), 14, ui.MUTED)
			notice.name = "EmptyNotice"
		else:
			notice.text = GuildLang.t(text)
		return
	column.position = Vector2(10, 27)
	column.size = Vector2(174, rows.size() * 21 + (rows.size() - 1) * 2)
	for i in range(rows.size()):
		var node = ui.button(rows[i][0], rows[i][1], enabled)
		node.name = "ActionHint" + str(i)
		node.tooltip_text = GuildLang.t(rows[i][2])
		node.custom_minimum_size = Vector2(174, 21)
		node.alignment = HORIZONTAL_ALIGNMENT_LEFT
		node.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed", "disabled"]:
			node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		column.add_child(node)

static func commands(ui, layout: Control, map: GuildHexMap, game: Dictionary, me: Dictionary, focus: Dictionary) -> void:
	var panel = layout.get_node("CommandsPanel") as Panel
	panel.visible = true
	(panel.get_node("RoyalTitle") as Label).text = GuildLang.t("王权议事厅")
	GuildTableWidgets.scene_button(ui, panel.get_node("BtnAllAchievements") as Button, func(): ui.dialogs.achievements())
	var grid = panel.get_node("Royals/RoyalGrid") as GridContainer
	var public_cards = game.get("public_achievements", [])
	if GuildTableWidgets.region_changed(grid, "royals", [public_cards, ui.store.mode]):
		clear(grid)
		for key in public_cards:
			var data = ui.store.catalog.achievements.get(key, {})
			grid.add_child(ui.card(data.get("source", ""), Vector2(148, 140), func(): ui.dialogs.achievements()))
	var selected = panel.get_node("SelectedTile") as Control
	if not map.has_meta("guild_selection_click"):
		map.set_meta("guild_selection_click", true)
		map.cell_clicked.connect(func(cell):
			ui.selected_tile = cell.get("id", "")
			map.chosen_ids = [ui.selected_tile]
			map.queue_redraw()
			GuildTableWidgets.draw_selection(ui, selected, cell))
	var existing = game.board.filter( func(cell): return cell.id == ui.selected_tile)
	GuildTableWidgets.draw_selection(ui, selected, existing[0] if not existing.is_empty() else {})
	var can = ui.session.can_act()
	GuildTableWidgets.scene_button(ui, panel.get_node("BtnSpecial") as Button, func(): ui.dialogs.abilities(), can)
	GuildTableWidgets.scene_button(ui, panel.get_node("BtnPotions") as Button, func(): ui.dialogs.potions(), can)
	GuildTableWidgets.scene_button(ui, panel.get_node("BtnAchievements") as Button, func(): ui.dialogs.achievements(), true)
	GuildTableWidgets.scene_button(ui, panel.get_node("BtnExpansions") as Button, func(): ui.dialogs.expansions(), not me.is_empty())
	GuildTableWidgets.scene_button(ui, panel.get_node("BtnSeasonClose") as Button, func(): ui.dialogs.confirm_pass(), can)
	var log_panel = panel.get_node("MatchLog") as Panel
	(log_panel.get_node("LogTitle") as Label).text = GuildLang.t("对局日志")
	GuildTableWidgets.scene_button(ui, log_panel.get_node("BtnFullLog") as Button, func(): ui.dialogs.game_log())
	var items = log_panel.get_node("LogScroll/LogList") as VBoxContainer
	var entries = game.get("log", [])
	if GuildTableWidgets.region_changed(items, "log", [entries, GuildLang.traditional]):
		clear(items)
		for i in range(entries.size() - 1, -1, -1):
			items.add_child(ui.dialogs.wrapped(entries[i].get("message", ""), 17, ui.MUTED))

static func hand(ui, parent: Control, me: Dictionary) -> void:
	(parent.get_node("HandTitle") as Label).text = GuildLang.t("我的手牌" if not me.is_empty() else "冒险纪事")
	var cards = me.get("hand", [])
	ui.hand_page = min(ui.hand_page, max(0, (cards.size() - 1) / 9))
	(parent.get_node("HandCount") as Label).text = GuildLang.t("%s 张情报" % cards.size())
	var my_tiles = parent.get_node("BtnMyTiles") as Button
	my_tiles.visible = not me.is_empty()
	if my_tiles.visible:
		GuildTableWidgets.scene_button(ui, my_tiles, func(): ui.dialogs.tiles(me), true)
	var sell = parent.get_node("BtnSellCards") as Button
	sell.visible = not me.is_empty()
	if sell.visible:
		GuildTableWidgets.scene_button(ui, sell, func(): ui.dialogs.market(), ui.session.can_free_action())
	var expand = parent.get_node("ExpandHand") as Button
	expand.visible = not me.is_empty()
	if expand.visible:
		GuildTableWidgets.scene_button(ui, expand, func(): ui.dialogs.hand(), true)
	var previous = parent.get_node("BtnPrevHand") as Button
	var following = parent.get_node("BtnNextHand") as Button
	previous.visible = cards.size() > 9
	following.visible = cards.size() > 9
	if previous.visible:
		var back = func():
			ui.hand_page -= 1
			ui.rerender()
		var forward = func():
			ui.hand_page += 1
			ui.rerender()
		GuildTableWidgets.scene_button(ui, previous, back, ui.hand_page > 0)
		GuildTableWidgets.scene_button(ui, following, forward, (ui.hand_page + 1) * 9 < cards.size())
	var shown = cards.slice(ui.hand_page * 9, (ui.hand_page + 1) * 9)
	if not GuildTableWidgets.region_changed(parent, "hand", [shown, ui.store.mode, ui.session.player_id]):
		return
	for child in parent.get_children():
		if str(child.name).begins_with("HandCard"):
			parent.remove_child(child)
			child.queue_free()
	for i in range(shown.size()):
		var number = int(shown[i])
		GuildTableWidgets.at(parent, ui.card(ui.store.card_face(ui.store.card(number)), Vector2(100, 140), func(): ui.dialogs.card_detail(number, true)), Rect2(190 + i * 116, 18, 100, 140), "HandCard" + str(i))

static func final_status(ui, layout: Control, game: Dictionary, phase: String) -> void:
	var frame = layout.get_node("FinalStatus") as Panel
	frame.visible = phase == "final"
	if not frame.visible:
		return
	var row = frame.get_node("FinalRow") as HBoxContainer
	clear(row)
	row.add_child(ui.label("最终行动", 21, ui.GOLD))
	for index in range(game.players.size()):
		var remaining = int(game.final_remaining[index])
		var text = ui.label("P%s  %s次" % [int(game.players[index].id) + 1, remaining], 20)
		text.name = "FinalRemaining" + str(int(game.players[index].id))
		row.add_child(text)

static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
