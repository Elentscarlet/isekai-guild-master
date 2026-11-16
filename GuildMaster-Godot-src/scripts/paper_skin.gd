class_name GuildPaperSkin
extends RefCounted

# ---- 立体按钮：厚度阴影 + 按下下沉（内部类，不需要新文件）----
class BevelBox extends StyleBox:
	var body: StyleBox
	var shadow: StyleBox
	var depth := 4.0   # 底部厚度（像素）
	var sink := 0.0    # 主体下沉量，0 = 完全凸起，depth = 完全按平

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var h := rect.size.y - depth
		shadow.draw(to_canvas_item, Rect2(rect.position + Vector2(0, depth), Vector2(rect.size.x, h)))
		body.draw(to_canvas_item, Rect2(rect.position + Vector2(0, sink), Vector2(rect.size.x, h)))

static func _banner_tint(state: String) -> Color:
	match state:
		"hover": return Color(1.12, 1.07, 1.0)
		"pressed": return Color(0.88, 0.86, 0.84)
		"disabled": return Color(0.82, 0.80, 0.78, 0.85)
		"primary": return Color(0.74, 0.40, 0.47)
		"primary_hover": return Color(0.86, 0.48, 0.55)
		"primary_pressed": return Color(0.62, 0.32, 0.39)  # 比 primary 更深
	return Color.WHITE

static func _bevel(source: Texture2D, state: String, margin: float, cap_left := -1.0, cap_right := -1.0) -> StyleBox:
	var tint := _banner_tint(state)
	var body: GuildBannerBox = GuildBannerBox.create(source, tint, margin, 2.0)
	var shadow: GuildBannerBox = GuildBannerBox.create(source, Color(tint.r * 0.4, tint.g * 0.35, tint.b * 0.35, tint.a), margin, 2.0)
	for b in [body, shadow]:
		if cap_left >= 0.0:
			b.cap_left = cap_left
		if cap_right >= 0.0:
			b.cap_right = cap_right

	var pressed := state in ["pressed", "primary_pressed"]
	var box := BevelBox.new()
	box.body = body
	box.shadow = shadow
	box.depth = 1.0 if state == "disabled" else 4.0
	box.sink = (box.depth - 1.0) if pressed else 0.0
	# 总高度恒定，按下时文字跟着主体下沉，布局不会跳动
	box.content_margin_top = box.sink
	box.content_margin_bottom = box.depth - box.sink
	return box

# ---- 以下保持原样 ----
static func paper(state: String = "paper", padding: int = 16) -> StyleBoxTexture:
	var result = StyleBoxTexture.new();result.texture = load("res://ui/comic/" + state + ".svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(side, 12);result.set_content_margin(side, padding)
	return result

static func main_frame(padding: int = 0) -> StyleBoxTexture:
	var result = StyleBoxTexture.new();result.texture = load("res://ui/comic/main_frame.svg")
	result.set_texture_margin(SIDE_LEFT, 26);result.set_texture_margin(SIDE_TOP, 24)
	result.set_texture_margin(SIDE_RIGHT, 26);result.set_texture_margin(SIDE_BOTTOM, 24)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_content_margin(side, padding)
	return result

static func player_frame(padding: int = 0) -> StyleBoxTexture:
	var result = StyleBoxTexture.new();result.texture = load("res://ui/comic/player_frame.svg")
	result.set_texture_margin(SIDE_LEFT, 35);result.set_texture_margin(SIDE_TOP, 30)
	result.set_texture_margin(SIDE_RIGHT, 35);result.set_texture_margin(SIDE_BOTTOM, 30)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_content_margin(side, padding)
	return result

static func banner(state: String = "normal", padding: int = 10) -> StyleBox:
	var pressed = state in ["pressed", "primary_pressed"]
	var source = load("res://ui/buttons/banner_pressed.png" if pressed else "res://ui/buttons/banner_normal.png")
	return _bevel(source, state, maxf(6.0, padding * 0.8))

static func primary_state(state: String) -> String:
	return {"normal": "primary", "hover": "primary_hover", "pressed": "primary_pressed", "disabled": "disabled"}.get(state, state)

static func plaque(state: String = "normal", padding: int = 6) -> StyleBox:
	var pressed = state in ["pressed", "primary_pressed"]
	var source = load("res://ui/buttons/plaque_pressed.png" if pressed else "res://ui/buttons/plaque_normal.png")
	return _bevel(source, state, maxf(6.0, padding), 184.0, 172.0)

static func title_font() -> Font:
	return GuildLang.title_font()
