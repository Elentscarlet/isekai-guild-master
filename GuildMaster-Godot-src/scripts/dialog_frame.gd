class_name GuildDialogFrame
extends Control

# 参考版式弹窗共用的外框：遮罩 + 纸面 + 标题 + 关闭。
# 尺寸由每个弹窗传入；标题和关闭按钮的位置在 ui/dialog_frame.tscn 里调。

func setup(ui, title: String, dimensions: Vector2, key: String, close_button: bool) -> void:
	ui.dialog = self
	var frame = get_node("Frame") as Panel
	frame.size = dimensions
	frame.position = (ui.size - dimensions) / 2
	(frame.get_node("Title") as Label).text = GuildLang.t(title)
	var close = frame.get_node("Close") as Button
	close.visible = key != "pending" and close_button
	if not close.visible:
		return
	var rect = Rect2(close.position, close.size)
	ui.wire_button(close, func(): ui.close_dialog(), true)
	GuildTableWidgets.decorate(ui, close, rect)
