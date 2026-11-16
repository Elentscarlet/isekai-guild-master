extends Node

# 界面回归截图：按屏渲染并保存 PNG，供改动前后对比。
# 用法：Godot --path <项目> res://tools/regression/capture.tscn -- --screen=home --tag=before
# screen: home | room | table | dialog | lobby

func _ready() -> void:
	var screen := "home"
	var tag := "current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")

	var app = load("res://main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	match screen:
		"home":
			app.home_portrait = "hainie_red"
		"room":
			app.session.room = _room_fixture()
			app.session.local_mode = false
			app.session.player_id = 0
		"lobby":
			app.session.directory = true
			app.session.directory_received = true
			app.session.rooms = _room_list()
			app.session.player_id = 0
		"table", "dialog":
			var state = GuildSession.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://data/qa-2.json")))
			app.session.set_process(false)
			app.session.game = state.game
			app.session.room = state.room
			app.session.player_id = 0
			app.session.role = "player"
			app.session.active = true
			app.session.synchronized = true
			app.session.room_connected = true
	app.rerender()
	await get_tree().create_timer(0.8).timeout
	if screen == "dialog":
		app.dialogs.card_detail(1)
		await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://tools/regression/out/")
	DirAccess.make_dir_recursive_absolute(folder)
	var target := folder + screen + "_" + tag + ".png"
	get_viewport().get_texture().get_image().save_png(target)
	print("SAVED ", target)
	get_tree().quit(0)

func _room_fixture() -> Dictionary:
	return {
		"name": "回归房间", "host_id": 0, "max_players": 4, "drafting": false,
		"players": [
			{"id": 0, "name": "Alice", "ready": true, "connected": true, "hero_chosen": false},
			{"id": 1, "name": "Bob", "ready": false, "connected": true, "hero_chosen": false},
			{"id": 2, "name": "Carol", "ready": true, "connected": false, "hero_chosen": false},
		],
		"options": {"map_type": "normal", "hero_draw": 2, "start_player": "auto"},
		"hero_offers": [],
	}

func _room_list() -> Array:
	return [
		{"id": "AAAA1111", "name": "周末公会", "player_count": 2, "max_players": 4, "started": false, "allow_spectators": true},
		{"id": "BBBB2222", "name": "命运的房间", "player_count": 4, "max_players": 4, "started": true, "allow_spectators": false},
	]
