class_name GuildMobileUI
extends RefCounted

static func sheet(ui, title: String, key: String, closable: bool = true) -> VBoxContainer:
	ui.close_dialog(false);ui.modal_key = key
	var shade = ColorRect.new();shade.color = Color("29232b");ui.modal_layer.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.dialog = shade
	var margin = MarginContainer.new();shade.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	var body = VBoxContainer.new();margin.add_child(ui.panel(body, 14))
	var header = HBoxContainer.new();body.add_child(header)
	var heading = ui.label(title, 32, ui.GOLD);heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL;header.add_child(heading)
	if closable: header.add_child(ui.button("返回", func(): ui.close_dialog()))
	return body

static func home(ui, parent: Control):
	var T = GuildTableWidgets
	T.caption(ui, parent, "异世界公会长", Rect2(42, 50, 760, 86), 62, Color("fff8eb"))
	T.caption(ui, parent, "经营公会 · 探索迷宫 · 与同伴一起成长", Rect2(42, 148, 840, 52), 30, Color("fff8eb"))
	var menu = VBoxContainer.new();menu.add_theme_constant_override("separation", 20);T.at(parent, menu, Rect2(42, 238, 700, 438))
	menu.add_child(ui.button("联机大厅 / 开房 / 观战", func(): ui.dialogs.connect_setup(), true, true))
	menu.add_child(ui.button("离线单人 / 同机客座", func(): ui.session.start_local(ui.prefs.name)))
	var row = HBoxContainer.new();menu.add_child(row)
	for entry in [["设置", func(): ui.dialogs.settings()], ["图鉴", func(): ui.dialogs.gallery()], ["规则", func(): ui.dialogs.help()]]:
		var node = ui.button(entry[0], entry[1]);node.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(node)
	menu.add_child(ui.label("横屏触控 · 点击卡牌查看详情 · 列表可滑动", 26, Color("fff8eb")))
	var portrait = GuildPortrait.new();portrait.texture = ui.store.portrait("hainie_red");portrait.on_click = func(): ui.dialogs.hero_preview("hainie_red")
	T.at(parent, portrait, Rect2(826, 40, 400, 640))

static func room(ui, parent: Control):
	var room_data = ui.session.room;var T = GuildTableWidgets;var mine = {};var host = int(room_data.get("host_id", -1)) == ui.session.player_id
	for player in room_data.get("players", []):
		if int(player.id) == ui.session.player_id: mine = player
	T.caption(ui, parent, room_data.get("name", "公会房间"), Rect2(24, 12, 930, 60), 38, Color("fff8eb"))
	T.at(parent, ui.button("离开", func(): ui.session.leave_room()), Rect2(1110, 12, 144, 72))
	var left = VBoxContainer.new();T.at(parent, ui.panel(ui.scroll(left), 16), Rect2(16, 98, 380, 604))
	for player in room_data.get("players", []): left.add_child(ui.label("P%s %s · %s" % [int(player.id) + 1, player.name, "已准备" if player.get("ready", false) else "等待"], 27))
	left.add_child(ui.button("房间规则", func(): ui.dialogs.room_options()))
	if ui.session.local_mode:
		left.add_child(ui.button("客座人数", func(): ui.dialogs.guest_picker()));left.add_child(ui.button("玩家昵称", func(): ui.dialogs.player_names()));left.add_child(ui.button("读取存档", func(): ui.dialogs.load_picker()))
	elif not room_data.get("drafting", false): left.add_child(ui.button("取消准备" if mine.get("ready", false) else "准备", func(): ui.session.send({"type": "ready", "ready": not mine.get("ready", false)})))
	if not room_data.get("drafting", false) and host: left.add_child(ui.button("开始冒险", func(): ui.session.send({"type": "start"}), room_data.players.all(func(p): return p.get("ready", false) and p.get("connected", true)), true))
	if not ui.session.local_mode: left.add_child(ui.button("弹幕聊天", ui.toggle_chat))
	var right = VBoxContainer.new();T.at(parent, ui.panel(ui.scroll(right), 16), Rect2(410, 98, 854, 604))
	if not room_data.get("drafting", false):
		right.add_child(ui.label("准备后开始，再选择本局看板娘", 32, ui.GOLD));right.add_child(ui.dialogs.wrapped("离线客座会在每位玩家行动前显示交接确认。进度可在游戏菜单中保存。", 30));return
	var offers = room_data.get("hero_offers", [])
	if not offers.has(ui.browsing_character): ui.browsing_character = offers[0] if not offers.is_empty() else ""
	var tabs = HFlowContainer.new();right.add_child(tabs)
	for key in offers:
		var hero_key = str(key);tabs.add_child(ui.button(ui.store.catalog.characters.get(key, {}).get("name", key), func(): ui.browsing_character = hero_key;ui.rerender()))
	var identity = ui.store.catalog.characters.get(ui.browsing_character, {});var variants = HBoxContainer.new();right.add_child(variants)
	for variant in ["white", "black"]:
		var key = identity.get("variants", {}).get(variant, "");var hero = ui.store.catalog.heroes.get(key, {})
		if hero.is_empty(): continue
		var column = VBoxContainer.new();column.custom_minimum_size.x = 384;variants.add_child(column)
		column.add_child(ui.card(hero.get("source", [""])[0], Vector2(380, 260), func(): ui.dialogs.hero_preview(key, 0)))
		column.add_child(ui.button("选择白版" if variant == "white" else "选择黑版", func(): ui.session.send({"type": "set_hero", "character": ui.browsing_character, "variant": variant}), hero.get("available", false), true))

static func table(ui, parent: Control):
	var T = GuildTableWidgets;var game = ui.session.game;var me = ui.session.me();var phase = str(game.get("phase", ""))
	var actor = game.players[int(game.get("turn", 0))];var focus = me if not me.is_empty() else actor
	var header = T.surface(ui, parent, Rect2(12, 8, 1256, 82), "MobileHeader")
	T.caption(ui, header, "%s · 第%s季" % [ui.PHASES.get(phase, phase), int(game.round)], Rect2(16, 4, 490, 36), 28, ui.GOLD)
	T.caption(ui, header, actor.name + "的回合" if phase in ["action", "final"] else "文明 %s / 瘴气 %s" % [int(game.civ), int(game.miasma)], Rect2(16, 43, 490, 34), 26)
	ui.game_clock = T.caption(ui, header, "", Rect2(494, 25, 400, 40), 28, ui.GOLD);ui.game_clock.name = "ActionClock"
	T.at(header, ui.button("菜单", func(): game_menu(ui)), Rect2(1100, 4, 144, 72))
	if not ui.session.local_mode: T.at(header, ui.button("弹幕", ui.toggle_chat), Rect2(944, 4, 144, 72))
	var resource_panel = T.surface(ui, parent, Rect2(12, 98, 1256, 58))
	var resources = HBoxContainer.new();resources.add_theme_constant_override("separation", 26)
	for kind in ["gold", "strength", "pot"]: resources.add_child(ui.resource(kind, int(focus.get(kind, 0)), kind, 30))
	resources.add_child(ui.label("等级 %s · 好感 %s / 5 · 声望 %s" % [int(focus.get("hero_level", 1)), int(focus.get("affection", 0)), int(focus.get("score", 0))], 28))
	T.at(resource_panel, resources, Rect2(12, 4, 1232, 46))
	if phase in ["draft", "research"] and not me.is_empty() and (phase == "draft" or not me.get("researched", false)):
		selection(ui, parent, game, me, phase);return
	if phase == "finished":
		var body = VBoxContainer.new();T.at(parent, ui.panel(ui.scroll(body), 20), Rect2(14, 162, 1252, 540))
		body.add_child(ui.label("终局结算", 40, ui.GOLD))
		for player in game.players: body.add_child(ui.label("%s · %s 声望" % [player.name, player.get("score", 0)], 36))
		body.add_child(ui.button("查看完整记录", func(): ui.dialogs.game_log()));return
	var map = GuildHexMap.new();map.store = ui.store;map.motion = ui.prefs.motion;map.renpy_geometry = true
	T.at(parent, map, Rect2(12, 160, 810, 452), "MobileMap");map.set_game(game, ui.session.player_id);map.chosen_ids = [ui.selected_tile]
	map.cell_clicked.connect(func(cell): ui.selected_tile = cell.id;tile(ui, cell))
	var commands = GridContainer.new();commands.columns = 2;commands.add_theme_constant_override("h_separation", 12);commands.add_theme_constant_override("v_separation", 16)
	T.at(parent, commands, Rect2(844, 166, 416, 440), "MobileActions")
	var can = ui.session.can_act()
	for entry in [["手牌 %s" % me.get("hand", []).size(), func(): ui.dialogs.hand(), not me.is_empty()], ["秘药", func(): ui.dialogs.potions(), can], ["发展公会", func(): ui.dialogs.develop(), can], ["王权", func(): ui.dialogs.achievements(), true], ["特殊行动", func(): ui.dialogs.abilities(), can], ["扩展行动", func(): ui.dialogs.expansions(), not me.is_empty()], ["玩家 / 等级", func(): players(ui), true], ["本季闭店", func(): ui.dialogs.confirm_pass(), can]]:
		var node = ui.button(entry[0], entry[1], entry[2]);node.custom_minimum_size = Vector2(202, 88);commands.add_child(node)
	var footer = HBoxContainer.new();T.at(parent, footer, Rect2(16, 628, 1248, 80))
	for entry in [["我的板块", func(): ui.dialogs.tiles(focus)], ["公会总览", func(): ui.dialogs.player_detail(focus)], ["售牌 / 王权", func(): ui.dialogs.market()], ["对局日志", func(): ui.dialogs.game_log()]]:
		var node = ui.button(entry[0], entry[1]);node.size_flags_horizontal = Control.SIZE_EXPAND_FILL;footer.add_child(node)

static func game_menu(ui):
	var body = sheet(ui, "游戏菜单", "mobile_menu");var list = VBoxContainer.new();body.add_child(ui.scroll(list))
	for entry in [["偏好设置", func(): ui.dialogs.settings()], ["公会详情", func(): ui.dialogs.player_detail(ui.session.me())], ["撤回上一步", func(): ui.undo()], ["查看规则", func(): ui.dialogs.help()], ["离开对局", func(): ui.dialogs.leave()]]: list.add_child(ui.button(entry[0], entry[1]))
	if ui.session.local_mode: list.add_child(ui.button("保存进度", func(): ui.dialogs.save_picker()))
	if ui.session.me().get("strength_as_gold", false): list.add_child(ui.button("金币费用的战力折抵", func(): ui.dialogs.payment_preference()))

static func players(ui):
	var body = sheet(ui, "所有玩家", "mobile_players");var list = VBoxContainer.new();body.add_child(ui.scroll(list))
	for player in ui.session.game.players:
		list.add_child(ui.button("P%s %s · 等级%s · 声望%s" % [int(player.id) + 1, player.name, int(player.get("hero_level", 1)), int(player.get("score", 0))], func(): ui.dialogs.player_detail(player)))
		var clock = ui.label(ui.clock_text(int(player.id)), 28, ui.GOLD);list.add_child(clock);ui.player_clocks.append({"label": clock, "id": str(int(player.id))})

static func tile(ui, cell: Dictionary):
	var body = sheet(ui, cell.get("name", "迷宫") + " · " + str(cell.id), "mobile_tile");var me = ui.session.me()
	var row = HBoxContainer.new();body.add_child(row)
	var source = ui.store.catalog.tiles.get(cell.get("loot", ""), {}).get("source", "")
	if not source.is_empty(): row.add_child(ui.card(source, Vector2(430, 420)))
	var actions = VBoxContainer.new();actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(actions)
	actions.add_child(ui.label("区域声望 %s" % int(cell.get("region", 0)), 32))
	actions.add_child(ui.button("探索这里", func(): ui.close_dialog(false);ui.session.action("explore", {"tile": cell.id}), ui.session.can_act() and cell.get("eligible_for", []).has(ui.session.player_id), true))
	actions.add_child(ui.button("建设据点 · %s 金币" % int(cell.get("build_gold", 10)), func(): ui.close_dialog(false);ui.session.action("build", {"tile": cell.id}), ui.session.can_act() and cell.get("owner") != null and int(cell.owner) == int(me.get("id", -1)) and not cell.get("base", false)))

static func selection(ui, parent: Control, game: Dictionary, me: Dictionary, phase: String):
	var draft = phase == "draft";var cards = me.get("draft_cards", []) if draft else me.get("offered", []);var signature = JSON.stringify([phase, game.round, game.get("draft_step"), cards])
	if ui.research_packet != signature: ui.research_packet = signature;ui.selected_research = []
	var grid = GridContainer.new();grid.columns = 4;grid.add_theme_constant_override("h_separation", 12);grid.add_theme_constant_override("v_separation", 14)
	var scroller = ui.scroll(grid);GuildTableWidgets.at(parent, scroller, Rect2(16, 162, 918, 542));ui.preserve_selection_scroll(scroller, "research", signature)
	for i in range(cards.size()):
		var art = ui.card(ui.store.card_face(ui.store.card(cards[i])), Vector2(214, 300), func():
			if ui.selected_research.has(i): ui.selected_research.erase(i)
			elif draft: ui.selected_research = [i]
			else: ui.selected_research.append(i)
			ui.rerender())
		art.selected = ui.selected_research.has(i);art.name = "SelectionCard" + str(i);grid.add_child(art)
	var side = VBoxContainer.new();GuildTableWidgets.at(parent, ui.panel(ui.scroll(side), 12), Rect2(948, 162, 316, 542))
	side.add_child(ui.label("已选 %s 张" % ui.selected_research.size(), 32, ui.GOLD))
	if draft:
		side.add_child(ui.button("确认留牌", func(): ui.session.action("draft_pick", {"index": int(ui.selected_research[0]), "draft_step": int(game.draft_step)}), ui.selected_research.size() == 1 and not me.get("draft_ready", false) and game.get("pending") == null, true))
	else:
		var selected = []
		for index in ui.selected_research: selected.append(int(cards[index]))
		var total = GuildRulesLogic.research_price(me, game, selected.size());var limit = int(me.get("research_initial_limit", 8)) if int(game.round) == 1 else cards.size()
		side.add_child(ui.label("费用 %s 金币" % total, 28));side.add_child(ui.button("确认情报", func(): ui.session.action("research", {"cards": selected}), GuildRulesLogic.can_pay_gold(me, total) and selected.size() <= limit and game.get("pending") == null, true))
		if int(game.round) == 1 and not me.get("mulligan_done", false): side.add_child(ui.button("更换所选牌", func(): ui.session.action("mulligan", {"cards": selected});ui.selected_research = [], selected.size() > 0 and selected.size() <= 5 and game.get("pending") == null))
	side.add_child(ui.button("查看手牌", func(): ui.dialogs.hand()));side.add_child(ui.button("全部取消", func(): ui.selected_research = [];ui.rerender()))
	if not ui.selected_research.is_empty(): side.add_child(ui.button("查看选中卡", func(): ui.dialogs.card_detail(cards[ui.selected_research[-1]])))

static func card_detail(ui, number: int, playable: bool, free: bool):
	var data = ui.store.card(number);var me = ui.session.me();var state = ui.dialogs.card_state
	var body = sheet(ui, data.get("name", "事件卡"), "card");var row = HBoxContainer.new();row.size_flags_vertical = Control.SIZE_EXPAND_FILL;body.add_child(row)
	row.add_child(ui.card(ui.store.card_face(data), Vector2(416, 560)))
	var options = VBoxContainer.new();row.add_child(ui.scroll(options))
	options.add_child(ui.dialogs.wrapped(data.get("ui_summary", data.get("description", "")), 28))
	if not playable or not me.get("hand", []).has(number): return
	if me.get("hero") == "vee_white": options.add_child(ui.button("● 双倍打出" if state.double else "双倍打出", func(): state.double = not state.double;state.pieces = [];state.strength = 0;card_detail(ui, number, playable, free)))
	var cap = GuildRulesLogic.strength_cap(data, me, free, 2 if state.double else 1);state.strength = mini(state.strength, cap)
	if cap > 0: ui.dialogs.adjust(options, "战力折抵", cap, state.strength, func(value): state.strength = value;card_detail(ui, number, playable, free))
	options.add_child(ui.label("金币费用 %s · 投入战力 %s" % [0 if free else maxi(0, int(data.price) * (2 if state.double else 1) - 5 * int(state.strength)), int(state.strength)], 28, ui.GOLD))
	var required = GuildRulesLogic.piece_cost(data, me, state.double)
	if required > 0:
		options.add_child(ui.label("选择支付板块 %s / %s" % [state.pieces.size(), required], 28));var tiles = HFlowContainer.new();options.add_child(tiles)
		for index in range(me.get("tiles", []).size()):
			var tile_data = ui.store.catalog.tiles.get(me.tiles[index], {});var art = ui.card(tile_data.get("source", ""), Vector2(126, 120), func():
				if state.pieces.has(index): state.pieces.erase(index)
				elif state.pieces.size() < required: state.pieces.append(index)
				card_detail(ui, number, playable, free))
			art.selected = state.pieces.has(index);tiles.add_child(art)
	options.add_child(ui.button("免费打出" if free else "打出这张牌", func():
		var pieces = []
		for index in state.pieces: pieces.append(me.tiles[index])
		var args = {"card": number, "strength": int(state.strength), "pieces": pieces, "double": state.double}
		ui.close_dialog(false)
		if free: ui.session.action("potion", {"option": "free_card", "target": args})
		else: ui.session.action("play", args), ui.session.can_act() and state.pieces.size() == required, true))
	options.add_child(ui.button("售卖 / +1金币", func(): ui.session.action("sell_event", {"card": number}), ui.session.can_free_action()))

static func pending(ui, request: Dictionary):
	var body = sheet(ui, request.get("title", "结算卡牌效果"), "pending", false);ui.pending_id = int(request.id)
	var cache = ui.choice_states.get(str(ui.pending_id), {"selected": [], "strength": 0, "pot": 0, "flash": false, "lab": false});ui.choice_states = {str(ui.pending_id): cache}
	var selected = cache.selected;var options = request.get("options", []);var row = HBoxContainer.new();row.size_flags_vertical = Control.SIZE_EXPAND_FILL;body.add_child(row)
	var choices = VBoxContainer.new();var scroller = ui.scroll(choices);scroller.custom_minimum_size.x = 818;row.add_child(scroller);ui.preserve_selection_scroll(scroller, "pending", JSON.stringify([request.id, options]))
	var choose = func(index):
		if selected.has(index): selected.erase(index)
		elif int(request.get("max", 1)) == 1: selected.clear();selected.append(index)
		elif selected.size() < int(request.get("max", 1)): selected.append(index)
		pending(ui, request)
	if options.any(func(option): return option.get("board", false)):
		var map = GuildHexMap.new();map.store = ui.store;map.selection_only = true;map.renpy_geometry = true;map.custom_minimum_size = Vector2(800, 530)
		var snapshot = ui.session.game.duplicate(true)
		for i in range(options.size()):
			var option = options[i]
			if not option.get("board", false): continue
			var id = "%s,%s" % [int(option.q), int(option.r)];map.option_ids[id] = i
			if not snapshot.board.any(func(cell): return cell.id == id): snapshot.board.append({"id": id, "q": int(option.q), "r": int(option.r), "owner": null, "region": 0, "outer": true})
			if selected.has(i): map.chosen_ids.append(id)
		map.set_game(snapshot, ui.session.player_id);choices.add_child(map);map.cell_clicked.connect(func(cell): if map.option_ids.has(cell.id): choose.call(map.option_ids[cell.id]))
	else:
		var grid = GridContainer.new();grid.columns = 3;grid.add_theme_constant_override("h_separation", 12);grid.add_theme_constant_override("v_separation", 14);choices.add_child(grid)
		for i in range(options.size()):
			var option = options[i];var image = str(option.get("image", ""))
			if int(option.get("card", -1)) >= 0: image = ui.store.card_face(ui.store.card(int(option.card)))
			if not image.is_empty():
				var art = ui.card(image, Vector2(256, 334), func(): choose.call(i));art.selected = selected.has(i);art.name = "ChoiceCard" + str(i);grid.add_child(art)
			else:
				var node = ui.button(("● " if selected.has(i) else "") + option.get("label", "选项"), func(): choose.call(i));node.custom_minimum_size.x = 256;node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;grid.add_child(node)
	var payment = request.get("payment", {})
	if options.is_empty() and payment.has("target_image"): choices.add_child(ui.card(payment.target_image, Vector2(640, 500)))
	var side = VBoxContainer.new();side.custom_minimum_size.x = 354;row.add_child(ui.scroll(side))
	side.add_child(ui.label("已选 %s / %s" % [selected.size(), int(request.get("max", 0))], 30, ui.GOLD))
	var limits = GuildRulesLogic.payment_limits(payment, selected, int(cache.strength), int(cache.pot), cache.flash);cache.strength = limits[2];cache.pot = limits[3]
	if payment.get("target", false): side.add_child(ui.label("金币 %s" % maxi(0, int(payment.get("gold_flash" if cache.flash else "gold_base", 0)) - 5 * (int(cache.strength) + int(cache.pot) * int(payment.get("potion_strength", 0)) + (selected.size() if payment.get("tiles_as_strength", false) else 0))), 30))
	if int(payment.get("strength_max", 0)) > 0: ui.dialogs.adjust(side, "战力", limits[0], cache.strength, func(value): cache.strength = value;pending(ui, request))
	if int(payment.get("pot_max", 0)) > 0: ui.dialogs.adjust(side, "秘药", limits[1], cache.pot, func(value): cache.pot = value;pending(ui, request))
	for key in ["flash", "lab"]:
		if payment.get(key, false): side.add_child(ui.button(("● " if cache[key] else "") + ("使用一闪" if key == "flash" else "派遣实验室"), func(): cache[key] = not cache[key];pending(ui, request)))
	var ready = ui.session.can_choose() and selected.size() >= int(request.get("min", 0)) and selected.size() <= int(request.get("max", 1))
	if payment.get("tiles_as_strength", false): ready = ready and selected.size() <= ceili(float(payment.get("gold_flash" if cache.flash else "gold_base", 0)) / 5)
	side.add_child(ui.button("确认并继续", func(): ui.session.action("choice", {"choice_id": int(request.id), "selected": selected.duplicate(), "action": {"strength": int(cache.strength), "pot": int(cache.pot), "flash": cache.flash, "lab": cache.lab}}), ready, true))
	if request.get("optional", false): side.add_child(ui.button("跳过此效果", func(): ui.session.action("choice", {"choice_id": int(request.id), "skip": true})))
	side.add_child(ui.button("售卖卡牌", func(): ui.dialogs.market()));side.add_child(ui.button("卖1秘药", func(): ui.session.action("exchange", {"amount": 1}), int(ui.session.me().get("pot", 0)) > 0))
	side.add_child(ui.button("查看我的公会", func(): ui.dialogs.player_detail(ui.session.me())))
	if ui.session.me().get("strength_as_gold", false): side.add_child(ui.button("金币费用折抵", func(): ui.dialogs.payment_preference()))
