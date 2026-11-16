class_name GuildToaster
extends RefCounted

# 提示条与终局公告：两者都是短暂的浮层，不参与布局，所以单独放这里。

var ui
var label: Label
var final_notice: Control
var toast_serial := 0
var final_serial := 0

func setup(owner) -> void:
	ui = owner
	label = Label.new()
	ui.add_child(label)
	label.z_index = 100
	label.hide()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_stylebox_override("normal", GuildPaperSkin.paper("paper", 18))
	label.add_theme_font_size_override("font_size", 21)

func show(message: String) -> void:
	toast_serial += 1
	var serial = toast_serial
	label.text = GuildLang.t(message)
	label.show()
	label.reset_size()
	label.position = Vector2((ui.size.x - label.size.x) / 2, 25)
	label.modulate.a = 0
	if ui.prefs.motion:
		ui.create_tween().tween_property(label, "modulate:a", 1.0, 0.16)
	else:
		label.modulate.a = 1
	ui.get_tree().create_timer(4.5).timeout.connect( func():
		if serial == toast_serial:
			label.hide())

func show_final() -> void:
	hide_final()
	var serial = final_serial
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	final_notice = ui.panel(body, 32)
	final_notice.name = "FinalNotice"
	final_notice.z_index = 90
	final_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(final_notice)
	var lines = [
		["最终阶段开始", 52, ui.GOLD],
		["文明与瘴气相邻。每位公会长最多再行动两次。", 28, ui.INK],
		["金币产能最多减少20，取得等量金币。", 24, ui.MUTED],
	]
	for line in lines:
		var text = ui.label(line[0], line[1], line[2])
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(text)
	final_notice.size = Vector2(minf(1040, ui.size.x - 64), 240)
	reposition()
	ui.get_tree().create_timer(6.0).timeout.connect( func():
		if serial == final_serial:
			hide_final())

func hide_final() -> void:
	final_serial += 1
	if is_instance_valid(final_notice):
		final_notice.queue_free()
	final_notice = null

func reposition() -> void:
	if not is_instance_valid(final_notice):
		return
	final_notice.size.x = minf(1040, ui.size.x - 64)
	final_notice.position = Vector2((ui.size.x - final_notice.size.x) / 2, ui.size.y * 0.35 - final_notice.size.y / 2)
