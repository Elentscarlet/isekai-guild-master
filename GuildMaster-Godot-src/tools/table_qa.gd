extends SceneTree

# 桌面各阶段截图自检：行动、选面、轮抽、情报收集、结算。
# 用法（需要窗口，不能用 --headless）：
#   godot --path GuildMaster-Godot-src -s res://tools/table_qa.gd -- --qa-output=<绝对路径>

var ui
var output = ""
var failures = []

func _initialize(): call_deferred("run")

func frames(count = 4):
	for i in range(count): await process_frame

func check(value, message):
	print(("PASS " if value else "FAIL ") + message)
	if not value: failures.append(message)

func visible(name: String) -> bool:
	var node = ui.content.find_child(name, true, false)
	return node != null and node.is_visible_in_tree()

func capture(name):
	if output.is_empty():
		await frames(2)
		return
	await frames(6);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func use_fixture(seats: int):
	var fixture = GuildSession.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://data/qa-%s.json" % seats)))
	ui.session.set_process(false)
	ui.session.game = fixture.game.duplicate(true)
	ui.session.room = fixture.room.duplicate(true)
	ui.session.player_id = 0
	ui.session.role = "player"
	ui.session.active = true
	ui.session.local_mode = false
	ui.session.synchronized = true
	ui.session.room_connected = true
	ui.selected_tile = ""
	return ui.session.game

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	ui = load("res://main.tscn").instantiate();root.add_child(ui);await frames()
	ui.prefs.layout = "classic"
	var game = use_fixture(2)

	game.phase = "face"
	for player in game.players:
		player.face_chosen = false
	game.players[0].hero_character = "shion"
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("FacePhase"), "face phase screen")
	await capture("face")

	game.phase = "research"
	game.players[0].researched = false
	game.players[0].hero_character = "shion"
	game.players[0].offered = [5, 14, 77, 12, 30, 44]
	game.round = 1
	ui.selected_research = [];ui.research_packet = ""
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("SelectionPhase"), "research phase screen")
	await capture("research")

	game.phase = "draft"
	game.draft_step = 1
	game.players[0].draft_cards = [5, 14, 77, 12]
	game.players[0].draft_kept = []
	game.players[0].draft_ready = false
	ui.selected_research = [];ui.research_packet = ""
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("SelectionPhase"), "draft phase screen")
	await capture("draft")

	game.phase = "finished"
	game.round = 6
	game.season = 3
	game.scores = [
		{"rank": 1, "name": "测试公会1", "score": 42, "breakdown": {"hero": 5, "grid": 9, "loot": 3, "cards": 2, "achievements": 12, "reputation": 5, "treasures": 6, "retreat": 0}},
		{"rank": 2, "name": "测试公会2", "score": 31, "breakdown": {"hero": 4, "grid": 7, "loot": 2, "cards": 1, "achievements": 10, "reputation": 3, "treasures": 4, "retreat": 0}},
	]
	game.winners = [0]
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("Results"), "results screen")
	await capture("finished")

	# 选面后（已选择）与观战视角。
	game.phase = "face"
	game.players[0].face_chosen = true
	game.players[0].hero = "shion_white"
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("Chosen"), "chosen face panel")
	ui.session.role = "spectator";ui.session.player_id = -1
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("Spectator"), "spectator face panel")
	game.phase = "action"
	ui.prefs.layout = "classic"
	ui.close_dialog(false);ui._render();await frames(6)
	check(ui.content.find_child("TableScreen", true, false) != null and visible("MapPanel"), "spectator action layout")

	# 本机单人模式多出存档与昵称入口。
	ui.session.role = "player";ui.session.player_id = 0;ui.session.local_mode = true
	game.players[0].hand = [5, 14]
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("ExtraSave"), "local mode save button")
	ui.session.local_mode = false
	var shell = ui.content.find_child("TableScreen", true, false)
	var map = ui.content.find_child("TableMap", true, false)
	var hand = ui.content.find_child("HandCard0", true, false)
	game.players[0].gold += 1
	ui._render()
	await frames()
	check(is_instance_valid(shell) and shell == ui.content.find_child("TableScreen", true, false), "table shell survives a snapshot")
	check(is_instance_valid(map) and map == ui.content.find_child("TableMap", true, false), "map survives an unrelated change")
	check(is_instance_valid(hand) and hand == ui.content.find_child("HandCard0", true, false), "hand cards survive a gold change")
	check(map.cell_clicked.get_connections().size() == 1, "map click signal wired once")
	var undo = shell.get_node("Header/BtnUndo") as Button
	check(undo.pressed.get_connections().size() == 1, "header button wired once")
	game.players[0].hand.append(77)
	ui._render()
	await frames()
	check(visible("HandCard2"), "a changed hand shows the new card")

	# 总览布局复用同一套阶段场景。
	ui.session.role = "player";ui.session.player_id = 0
	game.phase = "face"
	for player in game.players:
		player.face_chosen = false
	ui.prefs.layout = "dashboard"
	ui.close_dialog(false);ui._render();await frames(6)
	check(ui.content.find_child("TableScreen", true, false) != null and ui.content.find_child("DashboardMap", true, false) == null and visible("FacePhase"), "dashboard uses phase scene")

	# 最终行动状态条。
	game.phase = "final"
	game.final_remaining = [2, 2]
	game.turn = 0
	ui.prefs.layout = "classic"
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("FinalStatus"), "final status row")

	ui.stop_audio();ui.session.close()
	print("TABLE_QA " + ("PASSED" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)
