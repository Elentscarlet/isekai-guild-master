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

func move_mouse(point: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame

func click(point: Vector2) -> void:
	await move_mouse(point)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

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

func check_character_selection() -> void:
	use_fixture(2)
	ui.session.game = {}
	var room: Dictionary = ui.session.room
	room["drafting"] = true
	room["hero_offers"] = ["bai", "alicia", "horn_revised", "shion", "sif"]
	room.players[0]["hero_chosen"] = false
	room.players[0]["hero_character"] = ""
	ui._render()
	await frames()
	var all_visible = true
	for i in range(5):
		var portrait = ui.content.find_child("CandidatePortrait%d" % i, true, false) as GuildPortrait
		all_visible = all_visible and portrait != null and portrait.is_visible_in_tree() and portrait.texture != null
	check(all_visible and not visible("CandidateConfirm") and not visible("CandidateDetails"), "all five portraits are visible before a selection")
	await capture("character-offers")
	var portrait = ui.content.find_child("CandidatePortrait1", true, false) as GuildPortrait
	if portrait == null:
		return
	var first = ui.content.find_child("CandidatePortrait0", true, false) as GuildPortrait
	await click(first.get_global_rect().get_center())
	portrait = ui.content.find_child("CandidatePortrait1", true, false) as GuildPortrait
	await click(portrait.get_global_rect().get_center())
	await frames()
	check(ui.session.selected_character == "alicia" and ui.session.outgoing.is_empty(), "portraits can be changed before sending a confirmation")
	check(visible("CandidateConfirm") and visible("CandidateDetails"), "selecting a portrait reveals both actions")
	await capture("character-selected")
	var details = ui.content.find_child("CandidateDetails", true, false) as Button
	if details == null:
		return
	await click(details.get_global_rect().get_center())
	check_details("alicia_white", "details show the three white-side cards")
	var switch = ui.dialog.find_child("CandidateFaceSwitch", true, false) as Button
	await click(switch.get_global_rect().get_center())
	check_details("alicia_red", "the side button replaces all three cards")
	check(ui.session.selected_character == "alicia" and ui.session.outgoing.is_empty(), "previewing either side keeps the selection unconfirmed")
	await capture("character-details")
	var close = ui.dialog.find_child("Close", true, false) as Button
	await click(close.get_global_rect().get_center())
	await frames()
	var confirm = ui.content.find_child("CandidateConfirm", true, false) as Button
	await click(confirm.get_global_rect().get_center())
	check(ui.session.pending_character == "alicia" and not ui.session.outgoing.is_empty(), "confirm sends the selected character")
	var queued: PackedByteArray = ui.session.outgoing.duplicate()
	room.players[0]["hero_chosen"] = true
	room.players[0]["hero_character"] = "alicia"
	ui.session._receive({"type": "snapshot", "room": room, "game": {}})
	await frames()
	var frame = ui.content.find_child("CandidateFrame1", true, false)
	var border = frame.get_theme_stylebox("panel") as StyleBoxFlat
	check(ui.session.pending_character.is_empty() and border.border_width_left == 5, "a confirmed selection keeps its gold lock border")
	await capture("character-locked")
	var other = ui.content.find_child("CandidatePortrait0", true, false)
	await click(other.get_global_rect().get_center())
	check(ui.session.outgoing == queued, "other cards cannot replace the locked choice")
	ui.session.outgoing.clear()

	ui.session.local_mode = true
	room["selecting_seat"] = 1
	room["hero_offers"] = ["horn_five"]
	room.players[1]["hero_chosen"] = false
	ui.session._receive({"type": "snapshot", "room": room, "game": {}})
	await frames()
	check(ui.session.can_select_character() and ui.session.selected_character.is_empty() and visible("CandidatePortrait0"), "a local guest receives a new unselected portrait")
	var guest_portrait = ui.content.find_child("CandidatePortrait0", true, false) as GuildPortrait
	await click(guest_portrait.get_global_rect().get_center())
	details = ui.content.find_child("CandidateDetails", true, false) as Button
	await click(details.get_global_rect().get_center())
	check_details("horn_five_white", "a one-sided character still shows all three cards")
	switch = ui.dialog.find_child("CandidateFaceSwitch", true, false) as Button
	check(switch.disabled, "the side switch is disabled for a one-sided character")
	ui.close_dialog(false)

func check_details(hero: String, description: String) -> void:
	var matches = ui.modal_key == "candidate_details" and ui.dialog != null
	if matches:
		var sources: Array = ui.store.catalog.heroes[hero].source
		for rank in range(3):
			var card = ui.dialog.find_child("CandidateRank%d" % (rank + 1), true, false) as GuildCardArt
			matches = matches and card != null and card.is_visible_in_tree() and card.source == sources[rank]
	check(matches, description)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	ui = load("res://main.tscn").instantiate();root.add_child(ui);await frames()
	await check_character_selection()
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

	var first_card = ui.content.find_child("HandCard0", true, false) as GuildCardArt
	var second_card = ui.content.find_child("HandCard1", true, false) as GuildCardArt
	if first_card != null and second_card != null:
		await move_mouse(first_card.get_global_rect().get_center())
		check(ui.preview.visible and ui.preview.art.source == first_card.source, "hover opens the matching card preview")
		var bounds = ui.preview.get_global_rect()
		check(ui.get_global_rect().encloses(bounds) and not bounds.intersects(first_card.get_global_rect()), "hover preview fits beside the card")
		await capture("card-hover")
		var hover_size = ui.preview.art.custom_minimum_size
		ui.preview.set_zoomed(true)
		check(ui.preview.visible and ui.preview.art.custom_minimum_size.y > hover_size.y, "Alt enlarges the hover preview")
		ui.preview.set_zoomed(false)
		check(ui.preview.visible and ui.preview.art.custom_minimum_size == hover_size, "releasing Alt restores the hover preview")
		var point = second_card.get_global_rect().get_center()
		await move_mouse(point)
		check(ui.preview.visible and ui.preview.art.source == second_card.source, "moving between cards updates the preview")
		await move_mouse(Vector2(20, 20))
		check(not ui.preview.visible, "leaving a card hides the preview")
		await click(point)
		check(ui.modal_key == "card" and not ui.preview.visible, "a hovered card still opens its detail dialog on click")
		ui.close_dialog(false)
	else:
		check(false, "hand cards are available for the hover test")

	# 最终行动状态条。
	game.phase = "final"
	game.final_remaining = [2, 2]
	game.turn = 0
	ui.close_dialog(false);ui._render();await frames(6)
	check(visible("FinalStatus"), "final status row")

	ui.stop_audio();ui.session.close()
	print("TABLE_QA " + ("PASSED" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)
