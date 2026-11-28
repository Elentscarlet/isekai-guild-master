class_name GuildUIKit
extends RefCounted

# 控件工厂：按钮、标签、纸张面板、卡图等外观统一在这里拼。
# main.gd 只保留流程（会话、渲染分发、输入），并把这些方法原样转发给调用方，
# 所以界面代码仍然写 ui.label(...) / ui.button(...)。
#
# ui 指向 main.gd 实例，用来取 store、prefs、音效和放大预览。

var ui

func box(fill: Color, border: Color, radius: int = 12, padding: int = 16) -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result

func label(text: String, points: int = 20, color: Color = Color("343133")) -> Label:
	var node = Label.new()
	node.text = GuildLang.t(text)
	node.add_theme_font_size_override("font_size", points)
	node.add_theme_color_override("font_color", color)
	if points >= 27:
		node.add_theme_font_override("font", GuildPaperSkin.title_font())
	return node

func button(text: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var node = Button.new()
	node.text = GuildLang.t(text)
	node.custom_minimum_size.y = 46
	node.custom_minimum_size.x = 200
	return wire_button(node, callback, enabled, primary)

# 给场景里已经摆好的按钮接上点击音效、悬停动画与回调，语义与原 button() 一致。
func wire_button(node: Button, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	node.disabled = not enabled
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		for state in ["normal", "hover", "pressed"]:
			node.add_theme_stylebox_override(state, GuildPaperSkin.banner(GuildPaperSkin.primary_state(state), 46))
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			node.add_theme_color_override(state, Color("fffdf7"))
	var already_wired = node.has_meta("guild_pressed")
	node.set_meta("guild_pressed", callback)
	if already_wired:
		return node
	node.pressed.connect( func():
		if not node.get_meta("guild_silent_click", false):
			ui.play_sound("click")
		var action: Callable = node.get_meta("guild_pressed")
		action.call())
	node.mouse_entered.connect( func():
		if not ui.prefs.motion or node.disabled: return
		node.create_tween().tween_property(node, "modulate", Color(0.94, 0.91, 0.86), 0.12))
	node.mouse_exited.connect( func():
		node.create_tween().tween_property(node, "modulate", Color.WHITE, 0.12))
	return node

func symbol(kind: String, points: int = 32) -> TextureRect:
	return picture(load("res://ui/symbols/" + kind + ".png"), points)

func picture(texture: Texture2D, points: int = 32) -> TextureRect:
	var node = TextureRect.new()
	node.texture = texture
	node.custom_minimum_size = Vector2(points, points)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func resource(kind: String, value, help: String, points: int = 25) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.tooltip_text = GuildLang.t(help)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 6)
	row.add_child(symbol(kind, points + 7))
	row.add_child(label(str(value), points, ui.INK))
	return row

func box_button(text: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var node = button(text, callback, enabled, primary)
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, GuildPaperSkin.paper(GuildPaperSkin.primary_state(state) if primary else state, 10))
	return node

# 所有加减步进钮：统一 46×46 方形与 plaque 样式。
func step_button(text: String, callback: Callable, enabled: bool = true) -> Button:
	var node = button(text, callback, enabled)
	node.custom_minimum_size = Vector2(46, 46)
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, GuildPaperSkin.plaque(state, 8))
	return node

func symbol_button(kind: String, help: String, callback: Callable, enabled: bool = true) -> Button:
	var node = button("", callback, enabled)
	node.custom_minimum_size = Vector2(66, 52)
	node.tooltip_text = GuildLang.t(help)
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, GuildPaperSkin.paper(state, 6))
	var image = symbol(kind, 32)
	node.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_left = 15
	image.offset_right = -15
	image.offset_top = 10
	image.offset_bottom = -10
	if not enabled:
		image.modulate.a = 0.3
	return node

func art_button(source: String, help: String, callback: Callable, enabled: bool = true) -> Button:
	var node = button("", callback, enabled)
	node.custom_minimum_size = Vector2(75, 58)
	node.tooltip_text = GuildLang.t(help)
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, GuildPaperSkin.paper(state, 6))
	var art = GuildCardArt.new()
	art.configure(ui.store, source, Vector2(48, 43))
	node.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 12
	art.offset_right = -12
	art.offset_top = 8
	art.offset_bottom = -8
	if not enabled:
		art.modulate.a = 0.3
	return node

func cost_button(title: String, kind: String, value, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var node = button("", callback, enabled, primary)
	node.tooltip_text = GuildLang.t(title)
	var line = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 16
	line.offset_right = -16
	line.offset_top = 8
	line.offset_bottom = -8
	var caption = label(title, 18, Color("fffdf7") if primary else ui.INK)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(caption)
	line.add_child(symbol(kind, 27))
	line.add_child(label(str(value), 21, Color("fffdf7") if primary else ui.INK))
	node.custom_minimum_size.x = caption.get_minimum_size().x + 96
	return node

func panel(child: Control, padding: int = 20) -> PanelContainer:
	var node = PanelContainer.new()
	node.add_theme_stylebox_override("panel", GuildPaperSkin.paper("paper", padding))
	node.add_child(child)
	return node

func scroll(child: Control, dimensions: Vector2 = Vector2.ZERO) -> ScrollContainer:
	var node = ScrollContainer.new()
	node.custom_minimum_size = dimensions
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.add_child(child)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

# 换页或重新渲染后保持滚动位置（例如情报收集时翻看候选卡）。
func preserve_selection_scroll(scroller: ScrollContainer, context: String, packet: String) -> void:
	if ui.selection_scroll_states.get(context, {}).get("packet", "") != packet:
		ui.selection_scroll_states[context] = {"packet": packet, "vertical": 0}
	restore_selection_scroll.call_deferred(scroller, ui.selection_scroll_states[context])

func restore_selection_scroll(scroller: ScrollContainer, state: Dictionary) -> void:
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if not is_instance_valid(scroller) or not scroller.is_inside_tree():
		return
	scroller.scroll_vertical = int(state.vertical)
	scroller.get_v_scroll_bar().value_changed.connect( func(value): state.vertical = int(value))

func card(source: String, dimensions: Vector2 = Vector2(150, 208), callback: Callable = Callable()) -> GuildCardArt:
	var art: GuildCardArt = GuildTileArt.new() if ui.store.is_tile(source) else GuildCardArt.new()
	art.interactive = true
	art.motion = ui.prefs.motion
	art.on_click = func():
		if callback.is_valid():
			ui.play_sound("card")
			callback.call()
	art.mouse_entered.connect(ui.preview.hover.bind(art))
	art.mouse_exited.connect(ui.preview.leave.bind(art))
	art.tree_exiting.connect(ui.preview.forget.bind(art))
	art.configure(ui.store, source, dimensions)
	return art
