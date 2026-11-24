class_name GuildPreview
extends PanelContainer

# 对局中在卡牌旁显示预览，按住 Alt 时切换为居中的大图。

const HOVER_LIMIT := Vector2(340, 480)
const ZOOM_LIMIT := Vector2(760, 1000)
const EDGE := 16.0
const GAP := 14.0

var ui
var art: GuildCardArt
var anchor: GuildCardArt
var pointer_inside := false
var zoomed := false

func setup(owner) -> void:
	ui = owner
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame = StyleBoxFlat.new()
	frame.bg_color = Color("241e1b")
	frame.border_color = Color("c9a262")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(8)
	frame.shadow_size = 10
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_content_margin(side, 6.0)
	add_theme_stylebox_override("panel", frame)
	hide()
	art = GuildCardArt.new()
	add_child(art)

func hover(card: GuildCardArt) -> void:
	anchor = card
	pointer_inside = true
	refresh()

func leave(card: GuildCardArt) -> void:
	if anchor != card:
		return
	pointer_inside = false
	if not zoomed:
		clear()

func forget(card: GuildCardArt) -> void:
	if anchor == card:
		clear()

func set_zoomed(value: bool) -> void:
	if zoomed == value:
		return
	zoomed = value
	if not zoomed and not pointer_inside:
		clear()
		return
	refresh()

func clear() -> void:
	anchor = null
	pointer_inside = false
	hide()

func refresh() -> void:
	if not is_instance_valid(anchor) or not anchor.is_visible_in_tree() or anchor.source.is_empty():
		clear()
		return
	var image = anchor.source
	var is_tile = ui.store.is_tile(image)
	var in_match = not ui.session.game.is_empty()
	var full_image_open = ui.modal_key in ["art", "card"]
	if not zoomed and (not in_match or is_tile or full_image_open):
		hide()
		return
	if (art is GuildTileArt) != is_tile:
		remove_child(art)
		art.queue_free()
		art = GuildTileArt.new() if is_tile else GuildCardArt.new()
		add_child(art)
	var natural = ui.store.natural_size(image)
	var frame_size = get_theme_stylebox("panel").get_minimum_size()
	var available: Vector2 = (ui.size - frame_size - Vector2.ONE * EDGE * 2).max(Vector2.ONE)
	var limit = (ZOOM_LIMIT if zoomed else HOVER_LIMIT).min(available)
	var scale_factor = minf(limit.x / natural.x, limit.y / natural.y)
	art.configure(ui.store, image, natural * scale_factor)
	reset_size()
	show()
	place()

func place() -> void:
	if not visible:
		return
	if not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
		clear()
		return
	if zoomed:
		position = (ui.size - size) / 2
		return
	var inverse: Transform2D = ui.get_global_transform().affine_inverse()
	var origin = anchor.get_global_rect()
	var card_bounds := Rect2(inverse * origin.position, inverse.basis_xform(origin.size))
	var at = Vector2(card_bounds.end.x + GAP, card_bounds.get_center().y - size.y / 2)
	if at.x + size.x + EDGE > ui.size.x:
		at.x = card_bounds.position.x - size.x - GAP
	if at.x < EDGE:
		at.x = card_bounds.get_center().x - size.x / 2
		at.y = card_bounds.position.y - size.y - GAP
		if at.y < EDGE:
			at.y = card_bounds.end.y + GAP
	var inset := Vector2.ONE * EDGE
	position = at.clamp(inset, (ui.size - size - inset).max(inset))
