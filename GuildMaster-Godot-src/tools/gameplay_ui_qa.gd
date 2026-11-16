extends SceneTree
var ui
var failures = []
var output = ""

func _initialize(): call_deferred("run")
func frames(count = 4):
	for i in range(count): await process_frame
func check(value, message):
	print(("PASS " if value else "FAIL ") + message)
	if not value: failures.append(message)
func has_text(node, value: String) -> bool:
	if node is Label and value in node.text: return true
	for child in node.get_children():
		if has_text(child, value): return true
	return false
func capture(name):
	await frames();await RenderingServer.frame_post_draw
	if not output.is_empty(): root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	ui = load("res://main.tscn").instantiate();root.add_child(ui);await frames()
	var fixture = GuildSession.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://data/qa-5.json")))
	ui.session.set_process(false);ui.session.game = fixture.game;ui.session.room = fixture.room;ui.session.room_id = "qa"
	ui.session.player_id = 0;ui.session.role = "player";ui.session.active = true;ui.session.synchronized = true;ui.session.room_connected = true
	var me = ui.session.game.players[0];me.hero = "skadi_white";me.strength_as_gold = true;me.gold = 40;me.strength = 5
	ui.session.game.clock = {"0": {"base": 30, "reserve": 120, "active": true}, "1": {"base": 0, "reserve": 75, "active": false}}
	ui.session.clock_received_msec = Time.get_ticks_msec() - 2200
	ui._render();await frames()
	check(is_instance_valid(ui.game_clock) or ui.mobile, "main layout creates a live action countdown")
	ui.session.clock_received_msec = Time.get_ticks_msec() - 2200
	check("28s" in ui.clock_text(0), "active clock interpolates time between snapshots")
	check("75s" in ui.clock_text(1), "inactive reserve does not drain")
	await capture("mobile-table" if ui.mobile else "desktop-table")
	if not ui.mobile:
		ui.prefs.layout = "dashboard";ui._render();await frames();check(ui.player_clocks.size() == 2, "dashboard includes player countdowns")
		ui.prefs.layout = "classic";ui._render()
	ui.session._receive({"type": "chat", "name": "测试公会长", "message": "你好"});await frames()
	var danmaku = ui.announcements.find_child("ChatDanmaku", true, false)
	check(danmaku != null and danmaku.text == "测试公会长：你好", "chat scrolls as name: message")
	check(ui.modal_key != "chat", "chat does not open a modal")
	ui.session.game.log.append({"id": ui.last_log_id + 1, "message": "测试公会长：发展公会。", "player": 0});me.hero_level = 2
	ui._render();await frames()
	check(ui.announcements.find_child("ActionPopup", true, false) != null, "multiplayer actions show a popup")
	check(ui.announcements.actions.any(func(item): return item.title == "人物等级提升"), "level-up notification is queued")
	ui.dialogs.hero_detail(me);check(has_text(ui.dialog, "当前等级 2"), "hero dialog shows current level")
	var ordinary = -1
	for key in ui.store.catalog.cards:
		var card = ui.store.catalog.cards[key]
		if card.get("available", false) and not card.get("can_trans", false) and int(card.get("price", 0)) > 0: ordinary = int(key);break
	me.hand = [ordinary];ui.dialogs.card_detail(ordinary, true)
	check(has_text(ui.dialog, "战力折抵"), "Skadi can select strength for ordinary cards")
	await capture("mobile-skadi" if ui.mobile else "desktop-skadi")
	ui.close_dialog(false);ui.session.action("develop", {"slots": ["gold"], "count": 1})
	check(ui.modal_key == "gold_payment", "Skadi can choose coins or strength for development")
	ui.close_dialog(false)
	if ui.mobile:
		ui.session.game.phase = "research";me.researched = false;me.offered = [ordinary, ordinary];ui._render();await capture("mobile-research")
		var request = {"id": 99, "player": 0, "title": "选择事件卡", "mode": "select", "min": 1, "max": 1, "options": [{"card": ordinary, "image": ui.store.card_face(ui.store.card(ordinary)), "value": ordinary}], "optional": true}
		ui.session.game.pending = request;ui.dialogs.pending(request);await capture("mobile-choice")
	ui.stop_audio();ui.session.close();print("GAMEPLAY_UI " + ("PASSED" if failures.is_empty() else "FAILED"));quit(0 if failures.is_empty() else 1)
