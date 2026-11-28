class_name GuildTableDashboard
extends RefCounted

# 「总览」桌面布局（设置 → 桌面布局 → 总览）。
# 固定面板与按钮都在 ui/table_layout_dashboard.tscn 里摆好；
# 这里只填数值、显隐和动态列表。经典布局见 table_classic.gd。
# 选角、情报收集、选面与结算使用同一套阶段场景（table_screen.gd 负责挂入）。

static func fill(ui, screen, layout: Control) -> void:
	var game = ui.session.game
	var me = ui.session.me()
	var phase = str(game.get("phase", ""))
	var focus = me if not me.is_empty() else game.players[int(game.get("turn", 0))]
	var can = ui.session.can_act()
	# 布局根节点只用于摆位，不接收鼠标，否则阶段切换后会挡住输入。
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in layout.get_children():
		if child is Control:
			child.visible = true
	var sidebar = layout.get_node("Sidebar") as Panel
	(sidebar.get_node("PhaseLabel") as Label).text = GuildLang.t(ui.PHASES.get(phase, phase))
	(sidebar.get_node("PlayersTitle") as Label).text = GuildLang.t("玩家状态")

	var players = game.get("players", [])
	for i in range(5):
		var row = sidebar.get_node("PlayerRow%d" % i) as Panel
		row.visible = i < players.size()
		if not row.visible:
			continue
		var player = players[i]
		var portrait = row.get_node("Portrait") as GuildPortrait
		portrait.texture = ui.store.portrait_bust(player.hero, int(player.get("affection", 0)))
		portrait.on_click = func(): ui.dialogs.player_detail(player)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var name_label = row.get_node("Name") as Label
		name_label.text = GuildLang.t("P%s  %s" % [int(player.id) + 1, player.name])
		name_label.add_theme_color_override("font_color", ui.GOLD if int(game.turn) == i else ui.INK)
		(row.get_node("Info") as Label).text = GuildLang.t("金币 %s  力量 %s  秘药 %s" % [int(player.gold), int(player.strength), int(player.pot)])
		(row.get_node("State") as Label).text = GuildLang.t(GuildTableWidgets.player_status(ui, player, int(game.turn) == i))

	var y = 84 + players.size() * 75 + 8
	for i in range(6):
		var node = sidebar.get_node("BtnAction%d" % i) as Button
		node.position.y = y + i * 45
	var entries = [
		["手牌 / 情报", func(): ui.dialogs.hand(), true],
		["特殊行动", func(): ui.dialogs.abilities(), can],
		["扩充行动", func(): ui.dialogs.expansions(), not me.is_empty()],
		["本季闭店", func(): ui.dialogs.confirm_pass(), can],
		["偏好设置", func(): ui.dialogs.settings(), true],
		["返回 / 离开", func(): ui.dialogs.leave(), true],
	]
	for i in range(entries.size()):
		GuildTableWidgets.scene_button(ui, sidebar.get_node("BtnAction%d" % i) as Button, entries[i][1], entries[i][2])

	# 顶部三个公共区域。
	var potion_zone = layout.get_node("PotionZone") as Panel
	(potion_zone.get_node("Title") as Label).text = GuildLang.t("秘药行动")
	for i in range(6):
		var key = ["gold", "strength", "knowledge", "build", "free_card", "power"][i]
		var ready = GuildTableWidgets.potion_state(ui, key) == "可用"
		GuildTableWidgets.scene_button(ui, potion_zone.get_node("PotionButton%d" % i) as Button, func(): ui.dialogs.potions(), ready)
	var achievement_zone = layout.get_node("AchievementZone") as Panel
	(achievement_zone.get_node("Title") as Label).text = GuildLang.t("公共成就")
	var achievement_button = achievement_zone.get_node("BtnAchievements") as Button
	achievement_button.text = GuildLang.t("%s 张 · 查看成就" % game.get("public_achievements", []).size())
	GuildTableWidgets.scene_button(ui, achievement_button, func(): ui.dialogs.achievements())
	var treasure_zone = layout.get_node("TreasureZone") as Panel
	(treasure_zone.get_node("Title") as Label).text = GuildLang.t("剩余宝箱")
	var treasure_button = treasure_zone.get_node("BtnTreasures") as Button
	treasure_button.text = GuildLang.t("%s 个 · 查看宝物" % game.get("treasure_pool", []).size())
	GuildTableWidgets.scene_button(ui, treasure_button, func(): ui.dialogs.treasures())

	var map_panel = layout.get_node("DashboardMap") as Panel
	var map = map_panel.get_node("DashboardHexMap") as GuildHexMap
	map.store = ui.store
	map.motion = ui.prefs.motion
	map.renpy_geometry = true
	map.set_game(game, ui.session.player_id)
	map.chosen_ids = [ui.selected_tile]
	var selection = map_panel.get_node("DashboardSelection") as Control
	var existing = game.board.filter( func(cell): return cell.id == ui.selected_tile)
	GuildTableWidgets.draw_selection(ui, selection, existing[0] if not existing.is_empty() else {})
	if not map.has_meta("guild_selection_click"):
		map.set_meta("guild_selection_click", true)
		map.cell_clicked.connect(func(cell):
			ui.play_sound("wooden_click")
			ui.selected_tile = cell.id
			map.chosen_ids = [cell.id]
			map.queue_redraw()
			GuildTableWidgets.draw_selection(ui, selection, cell))
	GuildTableWidgets.scene_button(ui, map_panel.get_node("BtnUndo") as Button, func(): ui.undo(), game.get("undo", {}).get("available", false))
	GuildTableWidgets.scene_button(ui, map_panel.get_node("BtnMarket") as Button, func(): ui.dialogs.market(), ui.session.can_free_action())
	GuildTableWidgets.scene_button(ui, map_panel.get_node("BtnDevelop") as Button, func(): ui.dialogs.develop(), can)
	GuildTableWidgets.scene_button(ui, map_panel.get_node("BtnMyTiles") as Button, func(): ui.dialogs.tiles(me), not me.is_empty())

	# 右侧文明 / 瘴气纵向轨道。
	var track = layout.get_node("Track") as Panel
	(track.get_node("Miasma") as Label).text = GuildLang.t("瘴气 %s" % int(game.miasma))
	var bar = track.get_node("CivBar") as ProgressBar
	bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	bar.min_value = 0
	bar.max_value = maxf(1, float(game.miasma))
	bar.value = game.civ
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", ui.box(Color("d6c7b5"), ui.MUTED, 6, 0))
	bar.add_theme_stylebox_override("fill", ui.box(ui.GOLD, ui.GOLD, 6, 0))
	(track.get_node("Civ") as Label).text = GuildLang.t("文明 %s" % int(game.civ))
	(track.get_node("Round") as Label).text = GuildLang.t("第 %s 轮" % int(game.round))
	(track.get_node("Season") as Label).text = GuildLang.t(["春", "夏", "秋", "冬"][clampi(int(game.season), 0, 3)])

	# 底部个人信息与资源条。
	var personal = layout.get_node("Personal") as Panel
	var portrait = personal.get_node("Portrait") as GuildPortrait
	portrait.texture = ui.store.portrait_bust(focus.hero, int(focus.get("affection", 0)))
	portrait.on_click = func(): ui.dialogs.hero_detail(focus)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	(personal.get_node("HeroName") as Label).text = GuildLang.t(str(ui.store.catalog.heroes.get(focus.hero, {}).get("name", "")))
	(personal.get_node("Info") as Label).text = GuildLang.t("好感 %s / 5\n声望 %s" % [int(focus.get("affection", 0)), int(focus.get("score", 0))])
	GuildTableWidgets.scene_button(ui, personal.get_node("BtnDetail") as Button, func(): ui.dialogs.player_detail(focus))

	for i in range(3):
		var resource = ["gold", "strength", "pot"][i]
		var production = ["gold_pro", "str_pro", "pot_pro"][i]
		var panel = layout.get_node("Resource%d" % i) as Panel
		(panel.get_node("Icon") as TextureRect).texture = load("res://ui/symbols/" + resource + ".png")
		(panel.get_node("Value") as Label).text = str(int(focus.get(resource, 0)))
		(panel.get_node("Production") as Label).text = GuildLang.t("产能 %s" % int(focus.get(production, 0)))

	var hand_panel = layout.get_node("HandPanel") as Panel
	(hand_panel.get_node("Count") as Label).text = str(me.get("hand", []).size())
	GuildTableWidgets.scene_button(ui, hand_panel.get_node("BtnBrowse") as Button, func(): ui.dialogs.hand(), not me.is_empty())
	(hand_panel.get_node("Deck") as Label).text = GuildLang.t("事件牌库 %s" % int(game.get("deck_count", 0)))

	var stats = [["迷宫板块", focus.get("tiles", []).size()], ["好感 / 等级", "%s / %s" % [int(focus.get("affection", 0)), int(focus.get("hero_level", 1))]], ["当前声望", focus.get("score", 0)], ["可派冒险者", focus.get("available", 0)], ["已出事件", focus.get("played", []).size()], ["贡献标记", focus.get("contribution", 0)]]
	for i in range(stats.size()):
		var panel = layout.get_node("Stat%d" % i) as Panel
		(panel.get_node("Caption") as Label).text = GuildLang.t(str(stats[i][0]))
		(panel.get_node("Value") as Label).text = str(stats[i][1])

	var log_panel = layout.get_node("LogPanel") as Panel
	GuildTableWidgets.scene_button(ui, log_panel.get_node("BtnPlayed") as Button, func(): ui.dialogs.player_detail(focus))
	GuildTableWidgets.scene_button(ui, log_panel.get_node("BtnLog") as Button, func(): ui.dialogs.game_log())
	var logs = log_panel.get_node("LogScroll/LogList") as VBoxContainer
	var log_entries = game.get("log", [])
	var recent = log_entries.slice(maxi(0, log_entries.size() - 3))
	if GuildTableWidgets.region_changed(logs, "log", [recent, GuildLang.traditional]):
		clear(logs)
		for i in range(recent.size() - 1, -1, -1):
			logs.add_child(ui.dialogs.wrapped(recent[i].get("message", ""), 16, ui.MUTED))

static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
