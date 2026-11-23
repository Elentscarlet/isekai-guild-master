class_name GuildScreens
extends RefCounted

const HOME_SCENE = preload("res://ui/home_screen.tscn")
const TABLE_SCENE = preload("res://ui/table_screen.tscn")

static func home(ui, parent: Control):
	var screen = HOME_SCENE.instantiate()
	parent.add_child(screen)
	screen.bind(ui)

static func table(ui, parent: Control) -> GuildTableScreen:
	var screen = TABLE_SCENE.instantiate() as GuildTableScreen
	parent.add_child(screen)
	screen.bind(ui)
	return screen

static func room(ui, parent: Control):
	var screen = load("res://ui/room_screen.tscn").instantiate()
	parent.add_child(screen)
	screen.bind(ui)

static func rule_labels(ui, room) -> Array:
	var options = room.get("options", {})
	var labels = []
	for key in ui.store.catalog.option_labels:
		if options.get(key, false): labels.append(ui.store.catalog.option_labels[key])
	if options.get("solo", false): labels.append("单人挑战")
	var map_names = {"normal": "一般迷宫", "deep": "大深度迷宫", "training": "训练迷宫"}
	var map_type = options.get("map_type", "normal")
	labels.append(("大地图 · " if options.get("force_large", false) and map_type != "training" else "") + map_names.get(map_type, map_type))
	if options.get("solo", false):
		labels.append("单人难度 · " + {"beginner": "初级", "advanced": "上级", "expert": "特级", "super": "超级"}.get(options.get("solo_difficulty", "beginner"), "初级"))
	labels.append("候选 " + str(int(options.get("hero_draw", 2))) + " 名")
	var start = options.get("start_player", "auto")
	labels.append("随机先手" if start == "auto" else "席位 %s 先手" % (int(start) + 1))
	if options.get("initial_civ") != null: labels.append("初始文明 %s" % int(options["initial_civ"]))
	if options.get("initial_miasma") != null: labels.append("初始瘴气 %s" % int(options["initial_miasma"]))
	if options.get("action_timer", false):
		labels.append("倒计时 每回合 %ss / 备用 %ss" % [int(options.get("base_seconds", 30)), int(options.get("reserve_seconds", 120))])
	return labels
