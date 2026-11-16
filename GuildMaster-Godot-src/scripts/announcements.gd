class_name GuildAnnouncements
extends Control

var ui
var messages: Array = []
var actions: Array = []
var next_message = 0.0
var popup: Control
var popup_seconds = 0.0
var lane = 0

func setup(owner_ui):
	ui = owner_ui;mouse_filter = MOUSE_FILTER_IGNORE;z_index = 65
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func chat(name_text: String, message: String):
	messages.append(name_text + "：" + message.replace("\n", " ").replace("\r", " "))

func action(title: String, message: String):
	if not message.is_empty(): actions.append({"title": title, "message": message})

func clear_actions():
	actions.clear()
	if is_instance_valid(popup): popup.queue_free();popup = null

func _process(delta):
	next_message -= delta
	if not messages.is_empty() and next_message <= 0:
		var text = ui.label(messages.pop_front(), 30 if ui.mobile else 28, Color("fff8eb"))
		text.name = "ChatDanmaku";text.mouse_filter = MOUSE_FILTER_IGNORE
		text.add_theme_color_override("font_outline_color", Color("241e29"));text.add_theme_constant_override("outline_size", 7)
		add_child(text);text.position = Vector2(size.x + 16, 78 + lane * 46);lane = (lane + 1) % 3
		var distance = size.x + text.get_minimum_size().x + 32
		var tween = text.create_tween();tween.tween_property(text, "position:x", -text.get_minimum_size().x - 16, distance / (190.0 if ui.mobile else 240.0));tween.tween_callback(text.queue_free)
		next_message = 1.1
	popup_seconds -= delta
	if is_instance_valid(popup) and popup_seconds <= 0: popup.queue_free();popup = null
	if not is_instance_valid(popup) and not actions.is_empty():
		var item = actions.pop_front();var body = VBoxContainer.new()
		popup = ui.panel(body, 18);popup.name = "ActionPopup";popup.mouse_filter = MOUSE_FILTER_IGNORE;add_child(popup)
		var width = 490.0 if ui.mobile else 620.0
		var title = ui.label(item.title, 28, ui.GOLD);title.mouse_filter = MOUSE_FILTER_IGNORE;body.add_child(title)
		var text = ui.label(item.message, 25 if ui.mobile else 23);text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size.x = width - 36;text.mouse_filter = MOUSE_FILTER_IGNORE;body.add_child(text)
		popup.size.x = width;popup.position = Vector2(size.x - width - 22, 218 if ui.mobile else 124)
		if ui.mobile: popup.position = Vector2(22, maxf(220, size.y - popup.get_combined_minimum_size().y - 24))
		popup_seconds = 4.0 if actions.size() < 3 else 2.5
