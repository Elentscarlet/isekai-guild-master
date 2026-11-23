class_name GuildArtStore
extends RefCounted

var catalog = {}
var portrait_sources = {}
var textures = {}
var tiles = {}
var tile_angles = {}
var tile_ids = {}
var tile_paths = []
var texture_order = []
var mode: String = "multi"

func card_face(data: Dictionary) -> String:
	"""Face for this game mode; falls back to the base (multiplayer) print."""
	var source = str(data.get("source", ""))
	if mode == "solo":
		var variants = data.get("face_variants", {})
		if variants is Dictionary:
			var solo = str(variants.get("solo", ""))
			if not solo.is_empty(): return solo
	return source

func remember(source: String, value: Texture2D) -> Texture2D:
	textures[source] = value;texture_order.append(source)
	while texture_order.size() > 64: textures.erase(texture_order.pop_front())
	return value

func _init():
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	portrait_sources = JSON.parse_string(FileAccess.get_file_as_string("res://data/portraits.json")).sources
	_scan_tiles()

# 所有迷宫板块统一放在 art/images/piece_png/<编号>.png；不再读 card_layouts.json。
func _scan_tiles():
	tile_ids.clear();tile_paths.clear()
	var root = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var access = DirAccess.open(root.path_join("art/images/piece_png"))
	if access == null: return
	for file in access.get_files():
		if file.get_extension().to_lower() != "png": continue
		var number = file.get_basename()
		if not number.is_valid_int(): continue
		tile_ids[number] = true
		tile_paths.append("images/piece_png/" + file)

func texture(source: String) -> Texture2D:
	if source.is_empty(): return null
	if textures.has(source): return textures[source]
	var atlas = catalog.atlas.get(source)
	if atlas is Dictionary:
		var base = texture(atlas.path)
		if base == null: return null
		var result = AtlasTexture.new();result.atlas = base
		var box = atlas.box;result.region = Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3]))
		return remember(source, result)


	var root = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var path = root.path_join("art").path_join(source)
	if not FileAccess.file_exists(path) and source.begins_with("images/"):
		path = root.path_join("art").path_join(source.trim_prefix("images/"))
	if not FileAccess.file_exists(path): return null
	var bitmap = Image.load_from_file(path)
	if bitmap == null or bitmap.is_empty(): return null
	var result = ImageTexture.create_from_image(bitmap)
	return remember(source, result)

func is_tile(source: String) -> bool:
	if not (source.begins_with("images/piece_png/") or source.begins_with("images/tts/")): return false
	return tile_ids.has(source.get_file().get_basename())

func tile_path(source: String) -> String:
	return "images/piece_png/" + source.get_file().get_basename() + ".png"

func natural_size(source: String) -> Vector2:
	if is_tile(source): return Vector2(750, 750)
	var tex = texture(source)
	return tex.get_size() if tex else Vector2(720, 1024)

func card(number) -> Dictionary: return catalog.cards.get(str(int(number)), {})

func portrait_source(hero_key: String) -> String:
	return str(portrait_sources.get(hero_key, ""))

func portrait(hero_key: String, _affection: int = 0) -> Texture2D:
	# Every print resolves to its character illustration under art/characters.
	return texture(portrait_source(hero_key))

func portrait_bust(hero_key: String, affection: int = 0) -> Texture2D:
	var dedicated = portrait(hero_key, affection)
	if dedicated == null: return null
	var key = "bust:" + hero_key
	if textures.has(key): return textures[key]
	var size = dedicated.get_size()
	var result = AtlasTexture.new();result.atlas = dedicated
	result.region = Rect2(size.x * 0.30, size.y * 0.05, size.x * 0.30, size.y * 0.40)
	return remember(key, result)

func adventurer_token(player_id: int, is_base: bool = false) -> Texture2D:
	var key = ("base:" if is_base else "adventurer:") + str(posmod(player_id, 5))
	if textures.has(key): return textures[key]
	var source = "images/ui/base_atlas.png" if is_base else "images/ui/" + ["red", "yellow", "blue", "green", "white"][posmod(player_id, 5)] + ".png"
	var base = texture(source)
	if base == null: return null
	var bitmap = base.get_image()
	if is_base: bitmap = bitmap.get_region(Rect2i([16, 445, 875, 1304, 1733][posmod(player_id, 5)], 144, 420, 420))
	bitmap.convert(Image.FORMAT_RGBA8);bitmap.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	for y in range(96):
		for x in range(96):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(48, 48)) > 47: bitmap.set_pixel(x, y, Color.TRANSPARENT)
	return remember(key, ImageTexture.create_from_image(bitmap))

func tile_texture(source: String, resolution: int = 160) -> Texture2D:
	var key = source + "@" + str(resolution)
	if tiles.has(key): return tiles[key]
	var path = tile_path(source)
	var image = _custom_tile_image(path)
	if image == null: return null
	var pointy = bool(tile_pointy.get(path, false))
	tile_angles[source] = 0.0 if pointy else - PI / 6
	image = image.duplicate()
	image.resize(resolution, resolution, Image.INTERPOLATE_LANCZOS)
	# 六角遮罩貼齊原圖描邊外緣：左右尖端 ±0.5、上下平邊 ±0.446、斜邊 |x|+0.565|y| = 0.5，
	# 與板塊圖自身的六角形一致（避免左上/右下露白邊、右上/左下被切）；邊緣 2px 羽化。
	# 自定义原图若本身是尖顶六角，使用旋转 90° 的遮罩，并由绘制方以 0° 绘制。
	var feather = 2.0 / float(resolution)
	for y in range(resolution):
		for x in range(resolution):
			var px = abs(float(x) / float(resolution - 1) - 0.5); var py = abs(float(y) / float(resolution - 1) - 0.5)
			var over
			if pointy:
				over = maxf(px - 0.446, py + 0.565 * px - 0.5)
			else:
				over = maxf(py - 0.446, px + 0.565 * py - 0.5)
			if over > 0.0:
				image.set_pixel(x, y, Color.TRANSPARENT)
			elif over > -feather:
				var pixel = image.get_pixel(x, y);pixel.a *= clampf(-over / feather, 0.0, 1.0);image.set_pixel(x, y, pixel)
	var result = ImageTexture.create_from_image(image);tiles[key] = result
	while tiles.size() > 64: tiles.erase(tiles.keys()[0])
	return result

func tile_angle(source: String) -> float:
	return float(tile_angles.get(source, - PI / 6))

var tile_pointy = {}
var custom_tile_cache = {}

# 统一板块素材：art/images/piece_png/<编号>.png。
# 自动去透明边、居中、识别尖顶/平顶；绘制角度由 tile_angle() 返回。
func _custom_tile_image(path: String) -> Image:
	if custom_tile_cache.has(path): return custom_tile_cache[path]
	var tex = texture(path)
	if tex == null: return null
	var image = tex.get_image()
	if image == null: return null
	image = image.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	# 地图与板块卡最多用 1254px；用户放 2K/4K 原图时先降采样，避免逐像素去边过慢。
	if image.get_width() > 1254 or image.get_height() > 1254:
		var factor = 1254.0 / float(maxi(image.get_width(), image.get_height()))
		image.resize(maxi(1, int(round(image.get_width() * factor))), maxi(1, int(round(image.get_height() * factor))), Image.INTERPOLATE_LANCZOS)
	image = _trim_alpha(image)
	if image.get_width() < 2 or image.get_height() < 2: return null
	tile_pointy[path] = _pointy_hex(image)
	var side = maxi(image.get_width(), image.get_height())
	var canvas = Image.create(side, side, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((side - image.get_width()) / 2, (side - image.get_height()) / 2))
	custom_tile_cache[path] = canvas
	return canvas

# 原图边缘常有 alpha=1 的压缩噪点，get_used_rect 会把整张画布算进去；
# 用 alpha 阈值找真正的六角外框。
func _trim_alpha(image: Image) -> Image:
	var width = image.get_width(); var height = image.get_height()
	var data = image.get_data()
	var minx = width; var maxx = -1; var miny = height; var maxy = -1
	for y in range(height):
		var row = y * width * 4
		for x in range(width):
			if data[row + x * 4 + 3] > 20:
				if x < minx: minx = x
				if x > maxx: maxx = x
				if y < miny: miny = y
				if y > maxy: maxy = y
	if maxx < minx or maxy < miny: return image
	return image.get_region(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))

func _alpha_span(image: Image, y: int) -> int:
	var count = 0
	for x in range(image.get_width()):
		if image.get_pixel(x, y).a > 0.1: count += 1
	return count

func _pointy_hex(image: Image) -> bool:
	var height = image.get_height()
	if height < 8: return false
	var top = _alpha_span(image, maxi(0, int(height * 0.03)))
	var middle = _alpha_span(image, height / 2)
	return middle > 0 and top < middle * 0.3
