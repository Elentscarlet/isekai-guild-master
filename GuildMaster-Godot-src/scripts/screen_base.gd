class_name GuildScreen
extends Control

# 场景式界面（主页 / 房间 / 大厅）的公共基类：
#
# 1. 记住 .tscn 里的中文原文，切换繁简时统一重套。按节点记录而不是按节点名，
#    因此同一场景里出现重名节点（例如多个「关闭」按钮）也不会互相覆盖。
# 2. 场景里已经摆好的按钮，按原矩形套用和 action() 相同的样式与点击音效。
#
# 子类实现 on_ready() 取节点，实现 bind(owner) 填状态；不要覆盖 _ready()。

var ui
var _localized := []

func _ready() -> void:
	_capture_text()
	on_ready()

func _capture_text() -> void:
	_localized.clear()
	for node in find_children("*", "Label", true, false):
		_localized.append({"node": node, "text": node.text})
	for node in find_children("*", "Button", true, false):
		_localized.append({"node": node, "text": node.text})

func apply_language() -> void:
	for entry in _localized:
		if is_instance_valid(entry.node):
			entry.node.text = GuildLang.t(entry.text)

func wire_button(path: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var node = get_node_or_null(path) as Button
	if node == null:
		return null
	node.visible = true
	var rect = Rect2(node.position, node.size)
	# decorate() 会为代码按钮清空 custom_minimum_size；场景按钮需要保留
	# .tscn 里配置的最小尺寸，否则放在 HBox/VBox 里会被文字宽度重新排版。
	var scene_min_size = node.custom_minimum_size
	ui.wire_button(node, callback, enabled, primary)
	GuildTableWidgets.decorate(ui, node, rect, primary)
	node.custom_minimum_size = scene_min_size
	node.position = rect.position
	node.size = rect.size
	return node

func on_ready() -> void:
	pass
