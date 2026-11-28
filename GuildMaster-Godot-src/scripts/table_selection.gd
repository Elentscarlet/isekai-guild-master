class_name GuildTableSelection
extends GuildScreen

# 开局轮抽与情报收集：标题、说明、卡牌网格、右侧操作栏都在
# ui/table_selection.tscn 里。这里只按模式显隐侧栏控件、填文字、接回调，
# 卡牌本身是动态内容，仍然按数据生成。

func bind(owner, screen = null) -> void:
	ui = owner
	var game = ui.session.game
	var me = ui.session.me()
	var phase = str(game.get("phase", ""))
	var draft = phase == "draft"
	var cards = me.get("draft_cards", []) if draft else me.get("offered", [])
	var signature = JSON.stringify([phase, game.get("round"), game.get("draft_step"), cards])
	if ui.research_packet != signature:
		ui.research_packet = signature
		ui.selected_research = []
	apply_language()
	GuildTableWidgets.reset_scene_fonts(self)
	(get_node("Title") as Label).text = GuildLang.t("开局轮抽 / 第 %s 次选择" % int(game.get("draft_step", 0)) if draft else "初次情报收集" if int(game.round) == 1 else "新的情报收集")
	(get_node("Caption") as Label).text = GuildLang.t("留1张，其余传给左侧。轮抽后再选择付费保留，最后1张自动留下。" if draft else "选择要保留的事件卡；保留费用与打出费用分别计算。")
	var grid = get_node("CardsScroll/CardsGrid") as GridContainer
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for index in range(cards.size()):
		var art = ui.card(ui.store.card_face(ui.store.card(cards[index])), Vector2(205, 270), func():
			if ui.selected_research.has(index):
				ui.selected_research.erase(index)
			elif draft:
				ui.selected_research = [index]
			else:
				ui.selected_research.append(index)
			ui.rerender())
		art.name = "SelectionCard" + str(index)
		art.selected = ui.selected_research.has(index)
		art.interactive = not me.get("draft_ready", false) and game.get("pending") == null
		grid.add_child(art)
	var scroller = get_node("CardsScroll") as ScrollContainer
	ui.preserve_selection_scroll(scroller, "research", signature)

	var side = get_node("SideScroll/SideBox") as VBoxContainer
	for child in side.get_children():
		if child is Button or child is Label:
			(child as Control).visible = false
	_side_button("BtnProfile", "查看我的资料", func(): ui.dialogs.player_detail(ui.session.me()))
	if draft:
		_side_label("DraftTitle", "等待其他公会" if me.get("draft_ready", false) else "选择要留下的牌", 27, ui.GOLD)
		_side_label("DraftPack", "当前牌包 %s 张" % cards.size(), 24, ui.INK)
		_side_label("DraftKept", "已经留下 %s / 8 张" % me.get("draft_kept", []).size(), 24, ui.INK)
		_side_button("BtnConfirmDraft", "已确认，等待传牌" if me.get("draft_ready", false) else "确认留牌", func(): ui.session.action("draft_pick", {"index": int(ui.selected_research[0]), "draft_step": int(game.draft_step)}), ui.selected_research.size() == 1 and not me.get("draft_ready", false) and game.get("pending") == null, true)
		_side_button("BtnViewKept", "查看已留牌", func(): ui.dialogs.hand(me.get("draft_kept", []), "轮抽已留牌 / 仅自己可见"))
		_side_button("BtnViewHandDraft", "查看已有手牌", func(): ui.dialogs.hand())
		return
	var total = GuildRulesLogic.research_price(me, game, ui.selected_research.size())
	_side_label("ResearchTitle", "为公会做好准备", 29, ui.GOLD)
	_side_label("ResearchGold", "可用金币  %s" % int(me.gold), 25, ui.INK)
	_side_label("ResearchSelected", "已选 %s 张" % ui.selected_research.size(), 26, ui.INK)
	_side_label("ResearchTotal", "合计 %s 金币" % total, 32, ui.GOLD)
	var selected = []
	for index in ui.selected_research:
		selected.append(int(cards[index]))
	var limit = int(me.get("research_initial_limit", 8)) if int(game.round) == 1 else cards.size()
	_side_button("BtnConfirmResearch", "确认情报", func(): ui.session.action("research", {"cards": selected}), GuildRulesLogic.can_pay_gold(me, total) and selected.size() <= limit and game.get("pending") == null, true)
	_side_button("BtnCancelAll", "全部取消", func():
		ui.selected_research = []
		ui.rerender())
	_side_button("BtnViewHand", "查看已有手牌（%s张）" % me.get("hand", []).size(), func(): ui.dialogs.hand())
	if int(game.round) == 1 and not me.get("mulligan_done", false):
		var mulligan = func():
			ui.session.action("mulligan", {"cards": selected})
			ui.selected_research = []
		_side_button("BtnMulligan", "更换所选牌（最多5张，仅一次）", mulligan, selected.size() > 0 and selected.size() <= 5 and game.get("pending") == null)
	_side_button("BtnPrivateGoals", "查看私人目标", func(): ui.dialogs.achievements())

func _side_label(path: String, text: String, points: int, ink: Color) -> void:
	var node = get_node("SideScroll/SideBox/" + path) as Label
	node.visible = true
	node.text = GuildLang.t(text)
	node.add_theme_color_override("font_color", ink)

func _side_button(path: String, text: String, callback: Callable, enabled: bool = true, primary: bool = false) -> void:
	var node = get_node("SideScroll/SideBox/" + path) as Button
	node.visible = true
	node.text = GuildLang.t(text)
	# 场景里的按钮样式只用于编辑器预览；运行时的侧栏按钮沿用主题横幅。
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.remove_theme_stylebox_override(state)
	node.custom_minimum_size = Vector2(300, 46)
	var font: Font = ui.theme.default_font
	var points = 20
	while points > 13 and font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x + 80.0 > 300.0:
		points -= 1
	node.add_theme_font_size_override("font_size", points)
	node.clip_text = points <= 13
	if node.clip_text:
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui.wire_button(node, callback, enabled, primary)
