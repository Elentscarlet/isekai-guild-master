class_name GuildTableScreen
extends GuildScreen

# 对局桌面外壳：顶栏、左侧座位列、布局槽与阶段槽都在 table_screen.tscn 里摆好。
# 这里只填状态文字、显隐和回调，并按阶段挂入：
#   table_layout_classic.tscn / table_layout_dashboard.tscn  行动与最终行动
#   table_face.tscn                                          选择黑白面
#   table_selection.tscn                                     轮抽 / 情报收集
#   table_results.tscn                                       终局结算

const CLASSIC_LAYOUT = preload("res://ui/table_layout_classic.tscn")
const DASHBOARD_LAYOUT = preload("res://ui/table_layout_dashboard.tscn")
const FACE_SCENE = preload("res://ui/table_face.tscn")
const SELECTION_SCENE = preload("res://ui/table_selection.tscn")
const RESULTS_SCENE = preload("res://ui/table_results.tscn")

var game: Dictionary
var me: Dictionary
var phase := ""
var active_scene: PackedScene
var active_view: Control
var language := ""

func bind(owner) -> void:
	ui = owner
	$LayoutSlot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$PhaseSlot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()

func refresh() -> void:
	game = ui.session.game
	me = ui.session.me()
	phase = str(game.get("phase", ""))
	ui.player_clocks = []
	var scene = DASHBOARD_LAYOUT if ui.prefs.get("layout", "classic") == "dashboard" else CLASSIC_LAYOUT
	if phase == "finished":
		scene = RESULTS_SCENE
	elif phase == "face":
		scene = FACE_SCENE
	elif (phase == "draft" or (phase == "research" and not me.get("researched", false))) and not me.is_empty():
		scene = SELECTION_SCENE
	var layout = scene == CLASSIC_LAYOUT or scene == DASHBOARD_LAYOUT
	$Header.visible = scene != DASHBOARD_LAYOUT
	$PlayerSeats.visible = scene != DASHBOARD_LAYOUT
	$LayoutSlot.visible = layout
	$PhaseSlot.visible = not layout
	var locale: String = ui.prefs.get("language", "zh_CN")
	if language != locale:
		language = locale
		GuildTableWidgets.reset_scene_fonts($Header)
		GuildTableWidgets.reset_scene_fonts($PlayerSeats)
		apply_language()
	if $Header.visible:
		_bind_header()
		_bind_seats()
	if active_scene != scene or not layout:
		if is_instance_valid(active_view):
			active_view.get_parent().remove_child(active_view)
			active_view.queue_free()
			ui.preview.clear()
		active_scene = scene
		active_view = scene.instantiate() as Control
		var slot = $LayoutSlot if layout else $PhaseSlot
		slot.add_child(active_view)
		GuildTableWidgets.reset_scene_fonts(active_view)
	if scene == DASHBOARD_LAYOUT:
		GuildTableDashboard.fill(ui, self, active_view)
	elif scene == CLASSIC_LAYOUT:
		GuildTableClassic.fill(ui, self, active_view)
	else:
		active_view.call("bind", ui, self)

# ---------------------------------------------------------------- 顶栏

func _bind_header() -> void:
	var header = $Header
	var seasons = ["春", "夏", "秋", "冬"]
	var season_index = clampi(int(game.get("season", 0)), 0, 3)
	(header.get_node("Subtitle") as Label).text = GuildLang.t("观战中") if ui.session.role == "spectator" else str(ui.session.room.get("name", "我的公会"))
	(header.get_node("SeasonLabel") as Label).text = GuildLang.t("第 %s 季 · %s" % [int(game.get("round", 1)), seasons[season_index]])
	var link = header.get_node("SeasonForecast") as RichTextLabel
	link.text = "[u]%s[/u]" % GuildLang.t("季节生产预告: %s" % seasons[(season_index + 1) % 4])
	if not link.has_meta("guild_season_click"):
		link.set_meta("guild_season_click", true)
		link.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				ui.dialogs.season_forecast())
	(header.get_node("PhaseLabel") as Label).text = GuildLang.t(ui.PHASES.get(game.phase, game.phase))
	(header.get_node("CivilizationValue") as Label).text = GuildLang.t("文明 %s" % int(game.civ))
	var remaining = maxi(0, int(game.miasma) - int(game.civ) - 1)
	var progress = header.get_node("CivilizationProgress") as ProgressBar
	progress.show_percentage = false
	progress.min_value = 0
	progress.max_value = maxi(1, int(game.miasma) - 1)
	progress.value = progress.max_value if remaining == 0 else clampi(int(game.civ), 0, int(progress.max_value))
	progress.add_theme_stylebox_override("background", ui.box(Color("c7b9b1"), Color("6b6460"), 6, 0))
	progress.add_theme_stylebox_override("fill", ui.box(Color("64866d") if remaining == 0 else Color("9f4c50"), Color("64866d") if remaining == 0 else Color("9f4c50"), 6, 0))
	progress.tooltip_text = GuildLang.t("文明推进：文明 +1 达到瘴气时达标。\n当前文明 %s / 瘴气 %s" % [int(game.civ), int(game.miasma)])
	var remaining_label = header.get_node("CivilizationRemaining") as Label
	remaining_label.text = GuildLang.t("文明已达标" if remaining == 0 else "还差 %s 文明" % remaining)
	remaining_label.add_theme_color_override("font_color", Color("4c6553") if remaining == 0 else ui.MUTED)
	(header.get_node("MiasmaValue") as Label).text = GuildLang.t("瘴气 %s" % int(game.miasma))

	wire_button("Header/BtnMatchLog", func(): ui.dialogs.game_log())
	wire_button("Header/BtnUndo", func(): ui.undo(), game.get("undo", {}).get("available", false))
	wire_button("Header/BtnAchievements", func(): ui.dialogs.achievements())
	wire_button("Header/BtnMarket", func(): ui.dialogs.market(), ui.session.can_free_action())
	wire_button("Header/BtnTreasures", func(): ui.dialogs.treasures())
	wire_button("Header/BtnLeave", func(): ui.dialogs.leave())
	# 观战者没有撤回与售牌入口：隐藏后把右侧按钮左移，和原来的排法一致。
	var spectator = ui.session.role != "player"
	header.get_node("BtnUndo").visible = not spectator
	header.get_node("BtnMarket").visible = not spectator
	for item in [["BtnAchievements", 1048.0], ["BtnTreasures", 1124.0], ["BtnLeave", 1200.0]]:
		var button = header.get_node(item[0]) as Button
		if not button.has_meta("guild_player_x"):
			button.set_meta("guild_player_x", button.position.x)
		button.position.x = item[1] if spectator else button.get_meta("guild_player_x")
	if GuildTableWidgets.region_changed(header, "flag_rewards", [game.get("flags"), game.get("options"), language]):
		flag_rewards(game)
	var starter = game.players[int(game.get("start_player", 0))]
	(header.get_node("StartPlayer") as Label).text = GuildLang.t("◆ 本季起始玩家：P%s %s" % [int(starter.id) + 1, starter.name])

func flag_rewards(game: Dictionary) -> void:
	var strip = $Header/FlagRewards as Control
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	var options = game.get("options", {})
	var contribution = options.get("guild_board", false) and not options.get("solo", false)
	var flags = game.get("flags", [])
	if flags.is_empty():
		var icon = ui.picture(load("res://ui/symbols/flag.svg"), 26)
		icon.modulate.a = 0.35
		GuildTableWidgets.at(strip, icon, Rect2(0, 14, 26, 26))
		GuildTableWidgets.caption(ui, strip, "旗标已领完" if options.get("flags", false) or contribution else "未开启旗标奖励", Rect2(34, 16, 270, 26), 16, ui.MUTED)
		return
	var grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	GuildTableWidgets.at(strip, grid, Rect2(0, 0, 254, 60))
	for threshold in flags:
		var badge = Control.new()
		badge.custom_minimum_size = Vector2(30, 28)
		badge.name = "FlagThreshold_" + str(int(threshold))
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.tooltip_text = GuildLang.t("文明或瘴气变化经过 %s 时，触发者获得 %s；每个旗标只能领取一次。" % [int(threshold), "1 贡献标记" if contribution else "1 声望"])
		grid.add_child(badge)
		GuildTableWidgets.at(badge, ui.picture(load("res://ui/symbols/flag.svg"), 28), Rect2(0, 0, 30, 28))
		var number = GuildTableWidgets.caption(ui, badge, str(int(threshold)), Rect2(5, 3, 23, 19), 13)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if contribution:
		GuildTableWidgets.caption(ui, strip, "贡献 +1", Rect2(270, 18, 100, 26), 18, ui.GOLD).name = "FlagRewardType"
	else:
		GuildTableWidgets.at(strip, ui.symbol("point", 26), Rect2(270, 16, 26, 26))
		GuildTableWidgets.caption(ui, strip, "+1", Rect2(300, 17, 65, 26), 20, ui.GOLD)
	GuildTableWidgets.caption(ui, strip, "旗标奖励", Rect2(270, 43, 100, 17), 12, ui.MUTED)

# ---------------------------------------------------------------- 左列座位

func _bind_seats() -> void:
	var list = $PlayerSeats/SeatList as VBoxContainer
	var players = game.get("players", [])
	for index in range(5):
		var seat = list.get_node_or_null("Seat%d" % index) as Control
		if seat == null:
			continue
		seat.visible = index < players.size()
		if seat.visible:
			_bind_seat(seat, players[index])
	var private_tiles = list.get_node("ExtraPrivateTiles") as Button
	private_tiles.visible = not me.get("private_tiles", {}).is_empty()
	if private_tiles.visible:
		_extra_button(private_tiles, func(): ui.dialogs.private_tiles())
	var payment = list.get_node("ExtraPayment") as Button
	payment.visible = me.get("strength_as_gold", false)
	if payment.visible:
		_extra_button(payment, func(): ui.dialogs.payment_preference())
	var save = list.get_node("ExtraSave") as Button
	var names = list.get_node("ExtraNames") as Button
	save.visible = ui.session.local_mode
	names.visible = ui.session.local_mode
	if ui.session.local_mode:
		_extra_button(save, func(): ui.dialogs.save_picker())
		_extra_button(names, func(): ui.dialogs.player_names())
	_extra_button(list.get_node("ExtraChat") as Button, func(): ui.dialogs.chat())

func _extra_button(node: Button, callback: Callable) -> void:
	# 场景按钮只保留编辑器预览样式；运行时回到主题横幅，和 ui.button() 一致。
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.remove_theme_stylebox_override(state)
	node.remove_theme_font_override("font")
	node.remove_theme_font_size_override("font_size")
	node.visible = true
	ui.wire_button(node, callback)

func _bind_seat(seat: Control, player: Dictionary) -> void:
	var card = seat.get_node("Card") as Panel
	card.add_theme_stylebox_override("panel", GuildPaperSkin.player_frame(0))
	var player_id = int(player.id)
	(card.get_node("Token") as TextureRect).texture = ui.store.adventurer_token(player_id)
	(card.get_node("Name") as Label).text = GuildLang.t("P%s %s%s" % [player_id + 1, str(player.name).left(8), " 你" if player_id == ui.session.player_id else ""])
	var portrait = card.get_node("Portrait") as GuildPortrait
	portrait.texture = ui.store.portrait_bust(player.hero, int(player.get("affection", 0)))
	portrait.on_click = func(): ui.dialogs.player_detail(player)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var resources = card.get_node("Resources") as HBoxContainer
	if GuildTableWidgets.region_changed(resources, "balance", [player.get("gold"), player.get("strength"), player.get("pot"), language]):
		_clear(resources)
		for kind in ["gold", "strength", "pot"]:
			resources.add_child(ui.resource(kind, int(player.get(kind, 0)), kind, 20))
	var income = card.get_node("Income") as HBoxContainer
	if GuildTableWidgets.region_changed(income, "income", [player.get("gold_pro"), player.get("str_pro"), player.get("pot_pro"), language]):
		_clear(income)
		for kind in ["gold_pro", "str_pro", "pot_pro"]:
			income.add_child(ui.resource(kind, int(player.get(kind, 0)), kind, 17))
	(card.get_node("Score") as Label).text = GuildLang.t("声望 %s / 撤退 -%s" % [int(player.get("score", 0)), int(player.get("retreat", 0))])

	var state = GuildTableWidgets.player_status(ui, player, int(game.players[int(game.turn)].id) == player_id)
	if game.get("phase") == "face":
		state = "已选择黑白面" if player.get("face_chosen") else "选择黑白面"
	if state in ["行动中", "等待行动"]:
		state = ""
	if state.is_empty() and game.get("phase") == "final":
		state = "剩余 %s 次行动" % int(game.final_remaining[game.players.find(player)])
	var passed = player.get("passed", false)
	var status = card.get_node("SeatStatus") as Label
	status.text = GuildLang.t(state)
	status.position = Vector2(150, 139) if passed else Vector2(102, 115)
	status.size = Vector2(150, 20) if passed else Vector2(190, 21)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if passed else HORIZONTAL_ALIGNMENT_LEFT

	var bank = game.get("clock", {})
	bank = bank if bank is Dictionary else {}
	var counters = card.get_node("Counters") as HBoxContainer
	counters.position.y = 137 if (not state.is_empty() and not passed) or not bank.is_empty() else 115
	_clear(counters)
	counters.add_child(GuildTableWidgets.adventurers(ui, player, 17))
	var hearts = HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 3)
	hearts.tooltip_text = GuildLang.t("好感度")
	hearts.mouse_filter = Control.MOUSE_FILTER_STOP
	hearts.add_child(ui.symbol("affection", 16))
	hearts.add_child(ui.label(str(int(player.get("affection", 0))), 15))
	counters.add_child(hearts)
	if state.is_empty() and bank.has(str(player_id)):
		ui.player_clocks.append({"label": status, "id": str(player_id)})
	GuildTableWidgets.status_masks(ui, card, player, status)
	var existing_border = card.get_node_or_null("TurnBorder")
	var current = game.get("phase") in ["action", "final"] and int(game.players[int(game.turn)].id) == player_id
	if existing_border != null:
		existing_border.visible = current
	elif current:
		var border = Panel.new()
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.name = "TurnBorder"
		var bstyle = StyleBoxFlat.new()
		bstyle.draw_center = false
		bstyle.border_color = Color("ffd23f")
		bstyle.set_border_width_all(4)
		bstyle.set_corner_radius_all(10)
		border.add_theme_stylebox_override("panel", bstyle)
		border.z_index = 5
		card.add_child(border)
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not card.has_meta("guild_player_click"):
		card.set_meta("guild_player_click", true)
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				portrait.on_click.call())

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
