extends Panel

const BOARD_ART = preload("res://ui/counter.png")
const ART_REGION := Rect2(156, 15, 414, 2140)
const TRACK_CENTER_X := 238.0
const TRACK_LEFT_X := 203.0
const TRACK_GLASS := Rect2(219, 144, 38, 1586)
# Artwork coordinates of the major ticks, with 0, 30, 40, 50 and 60 at the colored jewels.
const TICK_Y := [1694.0, 1515.0, 1336.0, 1156.0, 982.0, 813.0, 642.0, 443.5, 245.0]
const TOKEN_SIZE := 24.0
const CROWDED_TOKEN_SIZE := 20.0
const CROWDED_TOKEN_SPACING := 22.0

var markers: Array[Dictionary] = []
var track_fill := GradientTexture2D.new()

func _ready() -> void:
	track_fill.gradient = Gradient.new()
	track_fill.gradient.offsets = PackedFloat32Array([0.0, 0.31, 0.49, 0.64, 0.83, 1.0])
	track_fill.gradient.colors = PackedColorArray([Color("30155c"), Color("742cc7"), Color("4c52d4"), Color("139bab"), Color("77b94e"), Color("d6a32b")])
	track_fill.width = 8
	track_fill.height = 512
	track_fill.fill_to = Vector2.DOWN
	resized.connect(queue_redraw)

func set_players(players: Array, store: GuildArtStore) -> void:
	markers.clear()
	for player in players:
		var player_id = int(player.id)
		markers.append({"id": player_id, "score": int(player.get("score", 0)), "icon": store.adventurer_token(player_id)})
	queue_redraw()

func _draw() -> void:
	var art_scale := minf(size.y / ART_REGION.size.y, (size.x - 16.0) / ART_REGION.size.x)
	if art_scale <= 0.0:
		return
	var track_x := size.x / 4.0 + 3.0
	var art_size := ART_REGION.size * art_scale
	var art_origin := Vector2(track_x - (TRACK_CENTER_X - ART_REGION.position.x) * art_scale, (size.y - art_size.y) / 2.0)
	var art_rect := Rect2(art_origin, art_size)
	draw_texture_rect_region(BOARD_ART, art_rect, ART_REGION)
	_draw_track_glass(art_origin, art_scale)
	var tick_right := art_origin.x + (TRACK_LEFT_X - ART_REGION.position.x) * art_scale
	_draw_ticks(tick_right, art_origin.y, art_scale)
	var positioned: Array[Dictionary] = []
	for marker in markers:
		positioned.append({"marker": marker, "y": _score_y(marker.score, art_origin.y, art_scale)})
	positioned.sort_custom(func(a, b): return a.marker.id < b.marker.id if a.y == b.y else a.y < b.y)
	var first := 0
	while first < positioned.size():
		var end := first + 1
		while end < positioned.size() and positioned[end].y - positioned[end - 1].y < TOKEN_SIZE + 18.0:
			end += 1
		var count := end - first
		var diameter := TOKEN_SIZE if count == 1 else CROWDED_TOKEN_SIZE
		# Keep each marker on its score line. Spread close scores sideways to keep the icons readable.
		var start_x := maxf(track_x - (count - 1) * CROWDED_TOKEN_SPACING / 2.0, track_x - 19.0)
		for index in range(first, end):
			var item := positioned[index]
			var point := Vector2(start_x + (index - first) * CROWDED_TOKEN_SPACING, item.y)
			_draw_marker(item.marker, point, diameter)
		first = end

func _draw_track_glass(art_origin: Vector2, art_scale: float) -> void:
	var glass_position := art_origin + (TRACK_GLASS.position - ART_REGION.position) * art_scale
	var glass := Rect2(glass_position, TRACK_GLASS.size * art_scale)
	draw_texture_rect(track_fill, glass, false)
	var shine := glass.grow(-2.0)
	shine.size.x = 1.0
	draw_rect(shine, Color(1.0, 0.9, 0.75, 0.25))
	# Keep the original jewels on top of the straight glass fill.
	for tick in [0, 3, 4, 5, 6]:
		var jewel := Rect2(TRACK_GLASS.position.x, TICK_Y[tick] - 31.0, TRACK_GLASS.size.x, 62.0)
		var destination := Rect2(art_origin + (jewel.position - ART_REGION.position) * art_scale, jewel.size * art_scale)
		draw_texture_rect_region(BOARD_ART, destination, jewel)

func _score_y(score: int, origin_y: float, art_scale: float) -> float:
	var scaled_score := clampi(score, 0, 80) / 10.0
	var tick := mini(floori(scaled_score), TICK_Y.size() - 2)
	var image_y := lerpf(TICK_Y[tick], TICK_Y[tick + 1], scaled_score - tick)
	return origin_y + (image_y - ART_REGION.position.y) * art_scale

func _draw_ticks(right: float, origin_y: float, art_scale: float) -> void:
	var font := get_theme_default_font()
	var ink := Color("60432b")
	for score in range(0, 81, 2):
		var y := _score_y(score, origin_y, art_scale)
		var major := score % 10 == 0
		var left := right - (9.0 if major else 5.0)
		draw_line(Vector2(left, y), Vector2(right, y), ink, 2.0 if major else 1.0, true)
		if major:
			var label := str(score)
			var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(left - width - 2.0, y + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)

func _draw_marker(marker: Dictionary, point: Vector2, diameter: float) -> void:
	draw_circle(point, diameter / 2.0 + 1.0, Color("422d24"), true, -1.0, true)
	var icon := marker.icon as Texture2D
	if icon:
		var dimensions := Vector2.ONE * diameter
		draw_texture_rect(icon, Rect2(point - dimensions / 2.0, dimensions), false)
	else:
		_draw_caption("P%d" % (marker.id + 1), point + Vector2(0, 4))
	_draw_caption(str(marker.score), point + Vector2(0, diameter / 2.0 + 13.0))

func _draw_caption(text: String, baseline: Vector2) -> void:
	var font := get_theme_default_font()
	var font_size := 16
	baseline.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("382b26"))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff5db"))
