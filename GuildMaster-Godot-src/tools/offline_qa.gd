extends SceneTree

# 真实离线开局回归：开始冒险 → 选人 → 情报收集 → 选黑白面 → 公会行动，
# 确认每个阶段都挂上了对应场景并且可见（防止场景节点被误设为隐藏）。
# 用法：
#   godot --headless --path GuildMaster-Godot-src -s res://tools/offline_qa.gd
#   godot --path GuildMaster-Godot-src -s res://tools/offline_qa.gd -- --qa-output=<绝对路径>

var ui
var output = ""
var failures = []

func _initialize(): call_deferred("run")

func frames(count = 4):
	for i in range(count): await process_frame

func wait_for(predicate: Callable, seconds = 20.0) -> bool:
	var deadline = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false

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

# 用真实鼠标事件点按钮，验证阶段切换后输入没有被透明全屏控件挡住。
func click(node: Control) -> void:
	var point = node.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame
	await frames(4)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	ui = load("res://main.tscn").instantiate();root.add_child(ui);await frames()
	ui.session.start_local("OfflineQA")
	check(await wait_for(func(): return not ui.session.room.is_empty()), "offline room connects")
	if ui.session.room.is_empty():
		quit(1);return
	ui.session.send({"type": "start"})
	check(await wait_for(func(): return ui.session.room.get("drafting", false)), "offline room offers characters")
	if not ui.session.room.get("drafting", false):
		quit(1);return
	var offers = ui.session.room.get("hero_offers", [])
	if offers.is_empty():
		check(false, "character offers are present")
		quit(1);return
	await frames(8)
	var candidate = ui.content.find_child("CandidatePortrait0", true, false) as GuildPortrait
	check(candidate != null and candidate.texture != null, "character selection displays the portrait")
	if candidate == null:
		quit(1);return
	await click(candidate)
	check(ui.session.game.is_empty() and ui.session.selected_character == offers[0], "clicking a portrait selects it before confirming")
	var confirm_character = ui.content.find_child("CandidateConfirm", true, false) as Button
	check(confirm_character != null and not confirm_character.disabled, "a selected portrait can be confirmed")
	if confirm_character == null:
		quit(1);return
	await click(confirm_character)
	check(await wait_for(func(): return not ui.session.game.is_empty()), "offline game starts")
	if ui.session.game.is_empty():
		quit(1);return
	check(ui.session.me().get("hero_character") == offers[0], "confirm locks the selected portrait")
	await frames(8)
	var phase = str(ui.session.game.get("phase", ""))
	check(phase in ["draft", "research"], "game starts in draft or research (%s)" % phase)
	check(ui.content.find_child("TableScreen", true, false) != null, "table shell renders")
	check(visible("SelectionPhase"), "opening card selection is visible")
	await capture("research")

	var confirm = ui.content.find_child("BtnConfirmResearch", true, false)
	check(confirm != null and confirm.is_visible_in_tree(), "confirm research button is clickable")
	await click(confirm)
	check(await wait_for(func(): return ui.session.game.get("phase") == "face"), "research enters face choice")
	await frames(8)
	check(visible("FacePhase"), "face choice is visible")
	await capture("face")

	var choose = ui.content.find_child("Choose", true, false)
	check(choose != null and choose.is_visible_in_tree(), "face choice button is clickable")
	await click(choose)
	check(await wait_for(func(): return ui.session.game.get("phase") == "action"), "face choice enters action phase")
	await frames(8)
	check(visible("MapPanel"), "action layout is visible")
	var quotes = ui.session.me().get("action_previews", {})
	check(quotes.has("achievements") and quotes.has("development"), "offline bridge publishes private action previews")
	ui.dialogs.develop()
	await frames(2)
	check(ui.dialog.find_child("Develop_gold", true, false) != null, "development dialog renders Python quotes")
	ui.close_dialog(false)
	var seat = ui.content.find_child("Seat0", true, false)
	var seat_portrait = seat.get_node_or_null("Card/Portrait") if seat else null
	check(seat_portrait != null and seat_portrait.texture is AtlasTexture, "in-game seat shows the cropped bust")
	var special = ui.content.find_child("BtnSpecial", true, false)
	check(special != null and special.is_visible_in_tree(), "action command button is visible")
	await click(special)
	check(ui.dialog != null, "action command button receives mouse click")
	ui.close_dialog(false)
	await capture("action")

	ui.stop_audio();ui.session.close()
	print("OFFLINE_QA " + ("PASSED" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)
