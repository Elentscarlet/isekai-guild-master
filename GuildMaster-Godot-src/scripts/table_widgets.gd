class_name GuildTableWidgets
extends RefCounted

# 桌面与弹窗共用的排版工具和通用小部件。
#
# 本项目沿用 Ren'Py 参考版的绝对坐标布局：at() 把控件摆进给定矩形，
# surface()/caption()/action() 再套上统一的纸张皮肤。具体界面布局见
# table_classic.gd（经典桌面）。

# ---------------------------------------------------------------- 排版工具

static func at(parent: Control, node: Control, rect: Rect2, id: String = "") -> Control:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	if not id.is_empty():
		node.name = id
	return node

static func surface(ui, parent: Control, rect: Rect2, id: String = "", style: StyleBox = null) -> Control:
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", style if style != null else GuildPaperSkin.paper("paper", 0))
	at(parent, panel, rect, id)
	return panel

static func main_surface(ui, parent: Control, rect: Rect2, id: String = "") -> Control:
	return surface(ui, parent, rect, id, GuildPaperSkin.main_frame(0))

static func player_surface(ui, parent: Control, rect: Rect2, id: String = "") -> Control:
	return surface(ui, parent, rect, id, GuildPaperSkin.player_frame(0))

static func caption(ui, parent: Control, text: String, rect: Rect2, points: int = 22, color: Color = Color("343133")) -> Label:
	return at(parent, ui.label(text, points, color), rect)

static func action(ui, parent: Control, text: String, rect: Rect2, callback: Callable, enabled: bool = true, id: String = "", primary: bool = false) -> Button:
	var node = ui.button(text, callback, enabled, primary)
	decorate(ui, node, rect, primary)
	at(parent, node, rect, id)
	return node

# 场景里已经摆好的按钮：接回调并套用与 action() 相同的字号与纸张样式。
static func scene_button(ui, node: Button, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var rect = Rect2(node.position, node.size)
	ui.wire_button(node, callback, enabled, primary)
	decorate(ui, node, rect, primary)
	node.position = rect.position
	node.size = rect.size
	return node

# 场景里的文字默认用项目字体预览；运行时改回主题字体，切繁简时才会换成繁体字型。
static func reset_scene_fonts(root: Node) -> void:
	for node in root.find_children("*", "Label", true, false):
		if node.get_theme_font_size("font_size") >= 27:
			node.add_theme_font_override("font", GuildPaperSkin.title_font())
		else:
			node.remove_theme_font_override("font")
	for node in root.find_children("*", "RichTextLabel", true, false):
		node.remove_theme_font_override("normal_font")
	for node in root.find_children("*", "Button", true, false):
		node.remove_theme_font_override("font")

# 场景里已经摆好的按钮：按它的矩形套上同样的字号与纸张样式，口径与原 action() 一致。
static func decorate(ui, node: Button, rect: Rect2, primary: bool = false, keep_min : bool = false) -> void:
	var saved_min = node.custom_minimum_size
	node.custom_minimum_size = Vector2.ZERO
	if keep_min:
		node.custom_minimum_size = saved_min
	node.add_theme_font_override("font", ui.theme.default_font)
	var wide = rect.size.x >= 150.0 and rect.size.y >= 44.0
	var base = 18 if rect.size.x <= 120 or rect.size.y < 40 else 24 if rect.size.y == 50 else 21
	if wide:
		var flat = maxf(30.0, rect.size.x - 251.0 * rect.size.y / 167.0)
		base = clampi(mini(base, int(flat / maxf(1.0, float(node.text.length()) * 1.05))), 12, 26)
	node.add_theme_font_size_override("font_size", base)
	for state in ["normal", "hover", "pressed", "disabled"]:
		if wide: node.add_theme_stylebox_override(state, GuildPaperSkin.banner(GuildPaperSkin.primary_state(state) if primary else state, 4))
		else: node.add_theme_stylebox_override(state, GuildPaperSkin.paper("primary" if primary and state == "normal" else state, 4))
	var points = 21
	while (node.get_combined_minimum_size().x > rect.size.x or node.get_combined_minimum_size().y > rect.size.y) and points > 12:
		points -= 1
		node.add_theme_font_size_override("font_size", points)

# 选牌画面右侧栏按钮：固定 300 宽。不能在树外用 get_combined_minimum_size：
# 那时主题还没挂上，估出的宽度偏小，所以按项目字体直接估算并自动缩小字号。
static func side_button(ui, text: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var node = ui.button(text, callback, enabled, primary)
	node.custom_minimum_size = Vector2(300, 46)
	var font: Font = ui.theme.default_font
	var points = 20
	while points > 13 and font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x + 80.0 > 300.0:
		points -= 1
	node.add_theme_font_size_override("font_size", points)
	if points <= 13:
		node.clip_text = true
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return node

# ---------------------------------------------------------------- 通用小部件

static func resources(ui, player: Dictionary, production: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var entries = [["gold_pro", "金币生产力"], ["str_pro", "战力生产力"], ["pot_pro", "秘药生产力"]] if production else [["gold", "金币"], ["strength", "战力"], ["pot", "秘药"]]
	for pair in entries:
		var column = VBoxContainer.new()
		column.custom_minimum_size.x = 43
		column.tooltip_text = GuildLang.t(pair[1])
		column.mouse_filter = Control.MOUSE_FILTER_STOP
		column.add_theme_constant_override("separation", 3)
		column.add_child(ui.symbol(pair[0], 19 if production else 25))
		var number = ui.label(str(int(player.get(pair[0], 0))), 18 if production else 22)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(number)
		row.add_child(column)
	return row

static func adventurers(ui, player: Dictionary, points: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.tooltip_text = GuildLang.t("未使用冒险者碎片")
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 4)
	var icon = ui.picture(ui.store.adventurer_token(int(player.id)), points + 6)
	icon.name = "AdventurerIcon"
	row.add_child(icon)
	var count = ui.label(str(int(player.get("available", 0))), points)
	count.name = "AdventurerCount"
	row.add_child(count)
	return row

static func player_connected(ui, player: Dictionary) -> bool:
	var connected = player.get("connected", true)
	for seat in ui.session.room.get("players", []):
		if int(seat.id) == int(player.id): connected = connected and seat.get("connected", true)
	if int(player.id) == ui.session.player_id and not ui.session.local_mode: connected = connected and ui.session.active and ui.session.synchronized and ui.session.room_connected
	return connected

static func region_changed(node: Node, name: String, values: Array) -> bool:
	var key = "guild_region_" + name
	if node.has_meta(key) and node.get_meta(key) == values:
		return false
	node.set_meta(key, values.duplicate(true))
	return true

static func status_masks(ui, panel: Control, player: Dictionary, status: Label) -> void:
	var disconnected = not player_connected(ui, player)
	for entry in [["ClosedMask", player.get("passed", false), Color(0.72, 0.7, 0.66, 0.42), 2], ["DisconnectedMask", disconnected, Color(0.19, 0.2, 0.22, 0.45), 3]]:
		var mask = panel.get_node_or_null(entry[0]) as ColorRect
		if mask != null:
			mask.visible = entry[1]
			continue
		if not entry[1]: continue
		mask = ColorRect.new()
		mask.name = entry[0]
		mask.color = entry[2]
		mask.z_index = entry[3]
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(mask)
		mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if disconnected or player.get("passed", false):
		status.z_index = 8
		status.add_theme_color_override("font_color", Color("fffdf7"))
		status.add_theme_color_override("font_outline_color", Color("343133"))
		status.add_theme_constant_override("outline_size", 2)
	else:
		status.z_index = 0
		status.remove_theme_color_override("font_color")
		status.remove_theme_color_override("font_outline_color")
		status.remove_theme_constant_override("outline_size")

static func player_status(ui, player: Dictionary, current: bool) -> String:
	if not player_connected(ui, player):
		var seconds = ui.session.room.get("disconnect_remaining", {}).get(str(int(player.id)))
		var state = "断线中 · %s秒" % int(seconds) if seconds != null else "断线中"
		return state + " · 本季闭店" if player.get("passed", false) else state
	if player.get("passed", false): return "本季闭店"
	return "行动中" if current else "等待行动"

static func potion_state(ui, key: String) -> String:
	return GuildRulesLogic.potion_state(ui.session.me(), ui.session.game, ui.store.catalog, key, ui.session.can_act())

# 场景 ui/potion_button.tscn 摆好按钮与两行内容，这里只填费用、图标、状态与回调。
static func potion_button(ui, key: String) -> Button:
	var node: Button = load("res://ui/potion_button.tscn").instantiate()
	fill_potion(ui, node, key)
	return node

static func fill_potion(ui, node: Button, key: String) -> Button:
	var potion = ui.store.catalog.potions[key]
	var state = potion_state(ui, key)
	node.name = "Potion_" + key
	node.text = ""
	node.tooltip_text = GuildLang.t(potion.get("name", key) + " · " + str(int(potion.cost)) + "秘药 · " + state + "\n" + potion.get("description", ""))
	for entry in [["normal", Color("f5eee0"), Color("1c1a1e")], ["hover", Color("fdf7ea"), Color("1c1a1e")], ["pressed", Color("eae1ce"), Color("1c1a1e")], ["disabled", Color("e7e1d7"), Color("8c877e")]]:
		var style = StyleBoxFlat.new()
		style.bg_color = entry[1]
		style.border_color = entry[2]
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		node.add_theme_stylebox_override(entry[0], style)
	var column = node.get_node("Column")
	var line = column.get_node("Line")
	var alchemy = line.get_node("Alchemy") as Label
	alchemy.visible = key.begins_with("alchemy_")
	alchemy.text = GuildLang.t({"alchemy_gem": "宝石", "alchemy_card": "召唤", "alchemy_scout": "侦察", "alchemy_build": "筑城", "alchemy_draw": "情报"}.get(key, "炼金"))
	(line.get_node("Cost") as Label).text = str(int(potion.cost))
	(line.get_node("Equals") as Label).text = "="
	(line.get_node("PotIcon") as TextureRect).texture = load("res://ui/symbols/pot.png")
	(line.get_node("RewardIcon") as TextureRect).texture = load("res://ui/symbols/" + {"gold": "gold", "strength": "strength", "knowledge": "event", "build": "territory", "free_card": "event", "power": "strength"}.get(key, "pot") + ".png")
	(line.get_node("Amount") as Label).text = "×" + str({"gold": 8, "strength": 2, "knowledge": 2, "build": 1, "free_card": 1, "power": 5}.get(key, 1))
	var civ = line.get_node_or_null("CivIcon")
	if key == "knowledge" and civ == null:
		civ = ui.picture(load("res://ui/symbols/civ_plus1.png"), 16)
		civ.name = "CivIcon"
		line.add_child(civ)
	elif key != "knowledge" and civ != null:
		civ.queue_free()
	var status = column.get_node("Status") as Label
	status.text = GuildLang.t(state)
	status.add_theme_color_override("font_color", Color("4c6553") if state == "可用" else ui.MUTED)
	ui.wire_button(node, func(): ui.session.action("potion", {"option": key}), state == "可用")
	var mask = node.get_node_or_null("PotionMask")
	if state == "未开放" or state == "本轮已用":
		if mask == null:
			mask = ColorRect.new()
			mask.name = "PotionMask"
			mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mask.z_index = 6
			node.add_child(mask)
			mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mask.color = Color(0.72, 0.7, 0.66, 0.5) if state == "未开放" else Color(0.529, 0.267, 0.286, 0.62)
	elif mask != null:
		mask.queue_free()
	return node

# 地图右侧「已选板块」详情面板（经典桌面使用）。
static func draw_selection(ui, parent: Control, cell: Dictionary) -> void:
	if not region_changed(parent, "selected_tile", [cell, GuildLang.traditional, ui.session.can_act(), ui.session.player_id]):
		return
	for child in parent.get_children(): parent.remove_child(child);child.queue_free()
	var data = ui.store.catalog.tiles.get(cell.get("loot", ""), {}) if cell.get("revealed", false) else {}
	var source = data.get("source", cell.get("back_source", "images/piece_png/17.png"))
	var text_width := parent.size.x - 172.0
	at(parent, ui.card(source, Vector2(126, 126), func(): ui.dialogs.art_detail(source, data.get("name", "未揭示板块"))), Rect2(10, 14, 126, 126))
	caption(ui, parent, data.get("name", "选择一个迷宫板块" if cell.is_empty() else "未揭示的迷宫"), Rect2(160, 0, text_width, 35), 23)
	if cell.is_empty():
		caption(ui, parent, "选择地图亮边区域开始探索" if ui.session.can_act() else "等待其他公会完成行动", Rect2(160, 43, text_width, 65), 20, ui.MUTED)
		return
	var owner = cell.get("owner")
	var me = ui.session.me()
	if owner != null:
		caption(ui, parent, "P%s / %s" % [int(owner) + 1, "据点" if cell.get("base", false) else "营地"], Rect2(160, 43, text_width, 30), 21)
		action(ui, parent, "建设据点", Rect2(160, 81, 200, 50), func(): ui.session.action("build", {"tile": cell.id}), ui.session.can_act() and not me.is_empty() and int(owner) == int(me.id) and not cell.get("base", false), "BuildBase", true)
	else:
		caption(ui, parent, "★ %s / 声望 %s" % [int(data.get("star", 0)), int(data.get("point", 0))] if not data.is_empty() else "翻开后支付探索费用", Rect2(160, 43, text_width, 30), 19, ui.MUTED)
		action(ui, parent, "派遣冒险者", Rect2(160, 81, 200, 50), func(): ui.session.action("explore", {"tile": cell.id}), ui.session.can_act() and cell.get("eligible_for", []).has(ui.session.player_id), "Explore", true)
