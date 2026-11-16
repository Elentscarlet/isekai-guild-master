extends RefCounted
var ui
var failures = []

func check(value, message):
	print(("MOBILE_PASS " if value else "MOBILE_FAIL ") + message)
	if not value: failures.append(message)

func wait_for(predicate: Callable, seconds: float = 40):
	var deadline = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await ui.get_tree().create_timer(0.05).timeout
	return predicate.call()

func run(client):
	ui = client
	if OS.has_feature("android"): check(Engine.has_singleton("GuildOffline"), "Android offline plugin registered")
	check(ui.store.portrait("hainie_red") != null, "bundled portrait loads")
	check(ui.store.texture(ui.store.card_face(ui.store.card(334))) != null, "Phrase card artwork loads")
	for guests in [0, 2]:
		ui.session.start_local("MobileQA")
		if not await wait_for(func(): return not ui.session.room.is_empty()):
			check(false, "offline lobby starts; " + ui.toast_label.text);break
		check(true, "offline lobby starts without internet")
		ui.session.send({"type": "set_guests", "count": guests})
		check(await wait_for(func(): return int(ui.session.room.get("max_players", 0)) == guests + 1), "local guest seats: " + str(guests + 1))
		ui.session.send({"type": "set_options", "options": {"setup_draft": false, "prologue": false, "guild_board": false, "action_timer": true, "hero_draw": 1}})
		await ui.get_tree().create_timer(0.4).timeout
		ui.session.send({"type": "start"})
		check(await wait_for(func(): return ui.session.room.get("drafting", false)), "local character selection starts")
		for seat in range(guests + 1):
			var offers = ui.session.room.get("hero_offers", [])
			if offers.is_empty(): check(false, "character offer for seat " + str(seat));break
			var character = offers[0];var variants = ui.store.catalog.characters.get(character, {}).get("variants", {})
			var version = "white" if variants.has("white") else "black"
			var previous = JSON.stringify([offers, ui.session.room.get("selecting_seat")])
			ui.session.send({"type": "set_hero", "character": character, "variant": version})
			check(await wait_for(func(): return not ui.session.game.is_empty() or JSON.stringify([ui.session.room.get("hero_offers", []), ui.session.room.get("selecting_seat")]) != previous), "seat selects a character: " + str(seat + 1))
		check(await wait_for(func(): return not ui.session.game.is_empty()), "shared rules engine starts the match")
		if ui.session.game.is_empty(): break
		check(ui.session.game.players.size() == guests + 1, "match has the requested player count")
		for step in range(40):
			var game = ui.session.game
			if game.get("phase") == "action" and game.get("pending") == null: break
			var previous = JSON.stringify([game.get("view_player"), game.get("phase"), game.get("pending"), game.players])
			var pending = game.get("pending")
			if pending is Dictionary:
				var chosen = []
				for i in range(int(pending.get("min", 0))): chosen.append(i)
				ui.session.action("choice", {"choice_id": int(pending.id), "selected": chosen, "skip": pending.get("optional", false)})
			elif game.get("phase") == "research": ui.session.action("research", {"cards": []})
			else: break
			if not await wait_for(func(): return JSON.stringify([ui.session.game.get("view_player"), ui.session.game.get("phase"), ui.session.game.get("pending"), ui.session.game.players]) != previous, 8): break
		check(ui.session.game.get("phase") == "action", "offline research reaches the action table")
		check(ui.session.game.get("clock") is Dictionary, "offline action countdown is available")
		ui.close_dialog(false);ui._render()
		await ui.get_tree().process_frame;await RenderingServer.frame_post_draw
		ui.get_viewport().get_texture().get_image().save_png("user://mobile-check-%s.png" % guests)
		ui.session.send({"type": "save_game", "name": "MobileQA"})
		check(await wait_for(func(): return not ui.session.room.get("saves", []).is_empty()), "offline save is written")
		ui.session.close();ui.rerender()
		await ui.get_tree().create_timer(0.3).timeout
	var report = {"passed": failures.is_empty(), "failures": failures, "android": OS.has_feature("android")}
	var file = FileAccess.open("user://mobile-check.json", FileAccess.WRITE);file.store_string(JSON.stringify(report, "  "));file.close()
	print("MOBILE_CHECK " + JSON.stringify(report));ui.get_tree().quit(0 if failures.is_empty() else 1)
