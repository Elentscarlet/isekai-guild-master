class_name GuildTableFace
extends GuildScreen

# 情报收集之后：为已选人物选择白面或黑面。
# 标题、说明、计数、白/黑两张候选卡位与按钮都在 ui/table_face.tscn 里；
# 这里按「观战 / 已选 / 待选」三种状态显隐并填入人物与卡图。

func bind(owner, screen = null) -> void:
	ui = owner
	var game = ui.session.game
	var me = ui.session.me()
	apply_language()
	GuildTableWidgets.reset_scene_fonts(self)
	var chosen = not me.is_empty() and bool(me.get("face_chosen", false))
	(get_node("Caption") as Label).text = GuildLang.t("已选择，等待其他公会长。" if chosen else "情报收集完成；点击卡面查看三级能力，或选择本局人物的黑面/白面。")
	var picked = 0
	for player in game.get("players", []):
		if player.get("face_chosen"):
			picked += 1
	var counter = get_node("Counter") as Label
	counter.text = GuildLang.t("已选择 %s / %s" % [picked, game.get("players", []).size()])
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var spectator = me.is_empty()
	(get_node("Spectator") as Control).visible = spectator
	(get_node("Chosen") as Control).visible = chosen and not spectator
	(get_node("WhiteOption") as Control).visible = false
	(get_node("BlackOption") as Control).visible = false
	if spectator:
		return

	var character = str(me.get("hero_character", ""))
	if character.is_empty():
		character = str(ui.store.catalog.heroes.get(me.get("hero", ""), {}).get("character", ""))
	var identity = ui.store.catalog.characters.get(character, {})
	if chosen:
		var picked_hero = ui.store.catalog.heroes.get(me.get("hero", ""), {})
		(get_node("Chosen/ChosenTitle") as Label).text = GuildLang.t("你的看板娘：%s  ·  %s" % [picked_hero.get("name", character), "黑面" if picked_hero.get("variant") == "black" else "白面"])
		var picked_sources = picked_hero.get("source", [])
		if not picked_sources.is_empty():
			var picked_card = ui.card(picked_sources[0], Vector2(560, 720), func(): ui.dialogs.hero_detail({"hero": str(me.get("hero", ""))}, 2))
			picked_card.tooltip_text = "点击查看三级能力"
			GuildTableWidgets.at(get_node("Chosen/ChosenSlot"), picked_card, Rect2(0, 0, 560, 720))
		return

	var variants = identity.get("variants", {})
	for i in range(2):
		var variant = "white" if i == 0 else "black"
		var option = get_node("WhiteOption" if i == 0 else "BlackOption") as Control
		var key = variants.get(variant, "")
		var hero = ui.store.catalog.heroes.get(key, {})
		if hero.is_empty():
			continue
		option.visible = true
		(option.get_node("Name") as Label).text = GuildLang.t(hero.get("name", character) + (" · 白面" if i == 0 else " · 黑面"))
		var sources = hero.get("source", [])
		if sources.is_empty():
			option.visible = false
			continue
		var card = ui.card(sources[0], Vector2(560, 400), func(): ui.dialogs.hero_detail({"hero": key}, 2))
		card.tooltip_text = "点击查看三级能力"
		GuildTableWidgets.at(option.get_node("CardSlot"), card, Rect2(0, 0, 560, 400))
		(option.get_node("Resources") as Label).text = GuildLang.t("金币 %s / 力量 %s / 秘药 %s" % [int(hero.get("gold", 0)), int(hero.get("strength", 0)), int(hero.get("pot", 0))])
		GuildTableWidgets.scene_button(ui, option.get_node("Choose") as Button, func(): ui.session.action("choose_face", {"variant": variant}), true, true)
