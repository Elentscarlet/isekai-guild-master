class_name GuildTableResults
extends GuildScreen

# 终局结算：纸面外框、标题、说明与底部按钮在 ui/table_results.tscn 里；
# 这里填入胜负提示、名次行（动态列表）与按钮状态。

func bind(owner, screen = null) -> void:
	ui = owner
	var game = ui.session.game
	var solo = game.get("solo_result") != null and not str(game.get("solo_result", "")).is_empty()
	apply_language()
	GuildTableWidgets.reset_scene_fonts(self)
	var title = "单人挑战成功" if game.get("solo_result") == "win" else "单人挑战结束 / 未达成" if solo else "这一段冒险，值得铭记。"
	(get_node("ResultsTitle") as Label).text = GuildLang.t(title)
	var details = get_node("SoloResultDetails") as Label
	details.visible = solo
	if solo:
		details.text = GuildLang.t("%s · 文明 %s / 瘴气 %s" % [game.get("solo_rank", ""), int(game.civ), int(game.miasma)])
	var season = get_node("SeasonLine") as Label
	season.text = GuildLang.t("第 %s 季  /  %s 位公会长的最终成绩" % [int(game.round), game.players.size()])
	season.position.y = 166 if solo else 108
	var scroller = get_node("ScoresScroll") as ScrollContainer
	scroller.position.y = 226 if solo else 166
	scroller.size.y = 510 if solo else 570
	var list = get_node("ScoresScroll/ScoresList") as VBoxContainer
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for score in game.get("scores", []):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 28)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		var card = ui.panel(row, 20)
		card.custom_minimum_size = Vector2(1462, 128)
		list.add_child(card)
		var rank = ui.label("%02d" % int(score.rank), 45, ui.GOLD)
		rank.custom_minimum_size.x = 60
		row.add_child(rank)
		var identity = VBoxContainer.new()
		identity.custom_minimum_size.x = 220
		row.add_child(identity)
		var name = ui.label(str(score.get("name", "")).left(12), 30)
		name.clip_text = true
		identity.add_child(name)
		identity.add_child(ui.label(game.get("solo_rank", "") if solo else "本次优胜" if int(score.rank) == 1 else "冒险伙伴", 18, ui.MUTED))
		for category in [["hero", "看板娘"], ["grid", "疆域"], ["loot", "板块"], ["cards", "事件"], ["achievements", "成就"], ["reputation", "额外"], ["treasures", "宝物"], ["retreat", "撤退"]]:
			var column = VBoxContainer.new()
			column.custom_minimum_size.x = 78
			row.add_child(column)
			column.add_child(ui.label(category[1], 17, ui.MUTED))
			column.add_child(ui.label(str(int(score.get("breakdown", {}).get(category[0], 0))), 28))
		var total = VBoxContainer.new()
		row.add_child(total)
		total.add_child(ui.label(str(int(score.get("score", score.get("total", 0)))), 47, ui.GOLD))
		total.add_child(ui.label("总声望", 16, ui.MUTED))
	var note = "第六轮结束时文明与瘴气相邻即挑战成功；全程可离线游玩。" if solo else "扩展资源声望已计入总分。点击公会可查看持有的宝石、庆典与贡献。"
	(get_node("ResultsNote") as Label).text = GuildLang.t(note)
	var log_button = get_node("Buttons/BtnLog") as Button
	ui.wire_button(log_button, func(): ui.dialogs.game_log())
	var room_button = get_node("Buttons/BtnRoom") as Button
	room_button.visible = not ui.session.local_mode and int(ui.session.room.get("host_id", -1)) == ui.session.player_id
	if room_button.visible:
		var back_to_room = func():
			ui.session.send({"type": "return_lobby"})
			ui.close_dialog()
		ui.wire_button(room_button, back_to_room)
	var menu_button = get_node("Buttons/BtnMenu") as Button
	var back_to_menu = func():
		ui.session.close()
		ui.close_dialog()
	ui.wire_button(menu_button, back_to_menu, true, true)
