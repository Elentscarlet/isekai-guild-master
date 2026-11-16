extends RefCounted

# 从 main.gd 抽出的主题构建：字体、按钮/输入框/滚动条样式。
# 通过 preload 使用（无 class_name），避免依赖编辑器的全局类缓存。

static func build(ui) -> Theme:
	var style = Theme.new();style.default_font = GuildLang.font();style.default_font_size = 20
	for type in ["Label", "Button", "CheckButton", "CheckBox", "OptionButton", "LineEdit", "SpinBox", "PopupMenu"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: style.set_color(state, type, ui.INK)
		style.set_color("font_disabled_color", type, Color("8c877e"))
	for state in ["normal", "hover", "pressed", "disabled"]: style.set_stylebox(state, "Button", GuildPaperSkin.banner(state, 46))
	style.set_stylebox("focus", "Button", ui.box(Color.TRANSPARENT, ui.GOLD, 0, 4))
	for type in ["OptionButton", "CheckButton", "CheckBox"]:
		for state in ["normal", "hover", "pressed", "disabled"]: style.set_stylebox(state, type, GuildPaperSkin.paper(state, 10))
		style.set_stylebox("focus", type, ui.box(Color.TRANSPARENT, ui.GOLD, 0, 4))
	for type in ["PanelContainer", "PopupMenu", "TooltipPanel"]: style.set_stylebox("panel", type, GuildPaperSkin.paper("paper", 20))
	style.set_color("font_color", "TooltipLabel", ui.INK)
	style.set_stylebox("normal", "LineEdit", GuildPaperSkin.paper("paper", 13))
	style.set_stylebox("focus", "LineEdit", GuildPaperSkin.paper("hover", 13))
	for type in ["CheckBox", "CheckButton"]:
		style.set_icon("checked", type, load("res://ui/comic/checked.svg"));style.set_icon("unchecked", type, load("res://ui/comic/unchecked.svg"))
	var rail = ui.box(Color("b4afb1"), Color("b4afb1"), 0, 2)
	style.set_stylebox("slider", "HSlider", rail);style.set_stylebox("grabber_area", "HSlider", ui.box(ui.GOLD, ui.GOLD, 0, 2))
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]: style.set_icon(state, "HSlider", load("res://ui/comic/knob.svg"))
	for type in ["VScrollBar", "HScrollBar"]:
		style.set_stylebox("scroll", type, ui.box(Color("d7d0c9"), Color("d7d0c9"), 0, 1))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]: style.set_stylebox(state, type, ui.box(ui.INK, ui.INK, 0, 1))
	style.set_constant("separation", "VBoxContainer", 12);style.set_constant("separation", "HBoxContainer", 12)
	return style
