class_name GuildPreview
extends PanelContainer

# 按住 Alt 时的卡片放大预览。
# 鼠标悬停只记录来源；是否显示由 Alt 状态决定，避免普通悬停挡住界面。

var ui
var art: GuildCardArt
var source := ""
var last_source := ""
var dimensions := Vector2(100, 140)
var magnification := 2.5
var zoomed := false

func setup(owner) -> void:
	ui = owner
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	art = GuildCardArt.new()
	add_child(art)

func hover(image: String, size: Vector2, scale: float) -> void:
	dimensions = size
	magnification = scale
	source = image
	last_source = image
	refresh()

func leave(image: String) -> void:
	if source == image:
		source = ""
	if not zoomed:
		hide()

func set_zoomed(value: bool) -> void:
	if zoomed == value:
		return
	zoomed = value
	refresh()

func clear() -> void:
	source = ""
	last_source = ""
	hide()

func refresh() -> void:
	if not zoomed:
		hide()
		return
	var image = source
	if image.is_empty() and visible:
		image = last_source
	if image.is_empty():
		hide()
		return
	var is_tile = ui.store.layouts.get(image, {}).get("kind") == "tile"
	if (art is GuildTileArt) != is_tile:
		remove_child(art)
		art.queue_free()
		art = GuildTileArt.new() if is_tile else GuildCardArt.new()
		add_child(art)
	# 保持原卡比例，高度尽量占满窗口；多张并排时也按同一高度缩放。
	var natural = ui.store.natural_size(image)
	var height = min(1000.0, ui.size.y - 80)
	var width = height * natural.x / natural.y
	if zoomed:
		width = 760
	if width > ui.size.x - 80:
		width = ui.size.x - 80
		height = width * natural.y / natural.x
	art.configure(ui.store, image, Vector2(width, height))
	reset_size()
	show()
	place()

func place() -> void:
	if not visible:
		return
	position = (ui.size - size) / 2
