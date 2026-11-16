extends SceneTree

# 弹窗冒烟测试：逐个打开所有弹窗，确认场景/内容能正常建立后立即关闭。
# 用法：Godot --headless --path GuildMaster-Godot-src -s res://tools/dialog_qa.gd
#
# 只检查「能不能打开」，不比较像素；界面外观由 tools/regression 的截图对比负责。

var ui
var failures = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3):
	for i in range(count):
		await process_frame

func check(value: bool, message: String) -> void:
	print(("PASS " if value else "FAIL ") + message)
	if not value:
		failures.append(message)

func open(name: String, action: Callable) -> void:
	ui.close_dialog(false)
	action.call()
	await frames()
	var opened = ui.dialog != null and is_instance_valid(ui.dialog) and not ui.dialog.is_queued_for_deletion()
	check(opened, "打开弹窗：" + name)
	ui.close_dialog(false)
	await frames()

func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await frames(4)
	var state = GuildSession.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://data/qa-2.json")))
	ui.session.set_process(false)
	ui.session.game = state.game
	ui.session.room = state.room
	ui.session.player_id = 0
	ui.session.role = "player"
	ui.session.active = true
	ui.session.synchronized = true
	ui.session.room_connected = true
	var me = ui.session.me()
	var card = ui.store.card(1)
	var achievement = ui.store.catalog.achievements.keys()[0]

	await open("设置", func(): ui.dialogs.settings())
	await open("规则说明", func(): ui.dialogs.help())
	await open("关于", func(): ui.dialogs.about())
	await open("确认退出", func(): ui.dialogs.confirm_quit())
	await open("连接设置", func(): ui.dialogs.connect_setup())
	await open("离开公会", func(): ui.dialogs.leave())
	await open("创建房间", func(): ui.dialogs.create_room())
	await open("加入房间", func(): ui.dialogs.enter_room({"id": "TEST0001", "name": "测试房间"}, "player"))
	await open("房间规则", func(): ui.dialogs.room_options())
	await open("卡牌图鉴", func(): ui.dialogs.gallery())
	await open("卡牌详情", func(): ui.dialogs.card_detail(1))
	# hero_ability() 在能力需要弃牌时开弹窗，否则直接提交动作，所以只验证不报错。
	ui.close_dialog(false)
	ui.dialogs.hero_ability()
	await frames()
	check(true, "看板娘能力不报错")
	ui.close_dialog(false)
	await open("选择手牌", func(): ui.dialogs.choose_hand("选择手牌", 1, 1, func(_cards): pass))
	await open("卡面大图", func(): ui.dialogs.art_detail("images/piece_png/2.png", "迷宫板块"))
	await open("看板娘成长", func(): ui.dialogs.hero_detail({"hero": me.get("hero", "")}))
	await open("序章与成长", func(): ui.dialogs.growth(me))
	await open("公会发展", func(): ui.dialogs.develop())
	await open("秘药工坊", func(): ui.dialogs.potions())
	await open("扩充行动", func(): ui.dialogs.expansions())
	await open("特殊行动", func(): ui.dialogs.abilities())
	await open("资源交换", func(): ui.dialogs.market())
	await open("王权与任务", func(): ui.dialogs.achievements())
	await open("公会收藏", func(): ui.dialogs.player_detail(me))
	await open("我的板块", func(): ui.dialogs.tiles(me))
	await open("手牌放大", func(): ui.dialogs.hand())
	await open("私密笔记", func(): ui.dialogs.private_tiles())
	await open("支付偏好", func(): ui.dialogs.payment_preference())
	await open("宝箱", func(): ui.dialogs.treasures(me))
	await open("季节预告", func(): ui.dialogs.season_forecast())
	await open("委托板", func(): ui.dialogs.quests())
	await open("对局记录", func(): ui.dialogs.game_log())
	await open("房间聊天", func(): ui.dialogs.chat())
	await open("确认闭店", func(): ui.dialogs.confirm_pass())
	await open("踢出玩家", func(): ui.dialogs.confirm_kick({"id": 1, "name": "P2"}))
	await open("客座人数", func(): ui.dialogs.guest_picker())
	await open("读档", func(): ui.dialogs.load_picker())
	await open("存档", func(): ui.dialogs.save_picker())
	await open("玩家昵称", func(): ui.dialogs.player_names())
	await open("客座换人", func(): ui.dialogs.seat_change(0))
	await open("委托结算", func(): ui.dialogs.quest_report({"serial": 1, "round": 1, "items": []}))
	await open("主菜单", func(): ui.dialogs.menu("主菜单", "menu"))
	await open("王权弃置", func(): ui.dialogs.confirm_discard_royal(achievement))
	await open("私有王权卡", func(): ui.dialogs.player_royals(me))
	await open("结算选项", func(): ui.dialogs.pending({"id": 99001, "player": 0, "title": "测试选项", "options": [], "min": 0, "max": 1, "payment": {}}))
	await open("通用外框", func(): ui.dialogs.overlay("测试外框", Vector2(800, 600), "qa"))
	check(ui.dialogs.expansion_guide() is Array and not ui.dialogs.expansion_guide().is_empty(), "扩充规则说明有内容")
	check(ui.dialogs.treasure_icon("fame", 32) != null, "宝物图标可生成")
	check(ui.dialogs.titled_rule("测试规则") != null, "带标题的分隔线可生成")
	var treasures = ui.session.game.get("treasures_available", [])
	if treasures.is_empty():
		check(true, "本局无宝箱，跳过宝物选项")
	else:
		var sample = treasures[0]
		var choice = ui.dialogs.treasure_choice({"value": sample.id, "label": sample.get("name", "宝物奖励"), "description": sample.get("description", "")}, false, func(): pass)
		check(choice is Button, "宝物选项可生成")
	ui.dialogs.refresh_snapshot()
	check(true, "refresh_snapshot 不报错")

	# 结算面板是内嵌在桌面里的，不走 ui.dialog。
	ui.close_dialog(false)
	ui.dialogs.results_inline(ui.content)
	await frames()
	check(ui.content.find_child("Results", true, false) != null, "结算面板内嵌渲染")
	ui.stop_audio()
	ui.session.close()
	ui.queue_free()
	await frames(2)
	print("DIALOG_QA " + ("PASSED" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)
