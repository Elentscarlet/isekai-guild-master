class_name GuildLobbyScreen
extends GuildScreen

# 大厅：固定结构在 lobby_screen.tscn 里，这里只填房间列表和接按钮。

func bind(owner) -> void:
	ui = owner
	(get_node("Margin/Root/Header/Row/Brand") as Label).add_theme_font_override("font", GuildPaperSkin.title_font())
	(get_node("Margin/Root/Sheet/SheetBox/Bar/Heading") as Label).add_theme_font_override("font", GuildPaperSkin.title_font())
	var header = get_node("Margin/Root/Header") as PanelContainer
	header.add_theme_stylebox_override("panel", GuildPaperSkin.paper("paper", 10))
	var sheet = get_node("Margin/Root/Sheet") as PanelContainer
	sheet.add_theme_stylebox_override("panel", GuildPaperSkin.paper("paper", 22))
	wire_button("Margin/Root/Header/Row/Gallery", func(): ui.dialogs.gallery())
	wire_button("Margin/Root/Header/Row/Settings", func(): ui.dialogs.settings())
	wire_button("Margin/Root/Header/Row/Leave", func(): ui.dialogs.leave())
	wire_button("Margin/Root/Sheet/SheetBox/Bar/Refresh", func(): ui.session.send({"type": "list_rooms"}))
	wire_button("Margin/Root/Sheet/SheetBox/Bar/Create", func(): ui.dialogs.create_room(), true)
	_fill_rooms()

func _fill_rooms() -> void:
	var rooms = get_node("Margin/Root/Sheet/SheetBox/RoomsScroll/Rooms") as VBoxContainer
	for child in rooms.get_children():
		rooms.remove_child(child)
		child.queue_free()
	if ui.session.rooms.is_empty():
		rooms.add_child(ui.label("暂时没有房间。创建一间公会，邀请伙伴加入。", 22, ui.MUTED))
	for room in ui.session.rooms:
		var row = HBoxContainer.new()
		rooms.add_child(ui.panel(row))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(ui.label(room.get("name", "公会"), 26, ui.GOLD))
		info.add_child(ui.label("房间 %s · %s / %s 人%s" % [room.get("id", ""), str(room.get("player_count", room.get("players", 0))), str(room.get("max_players", 4)), " · 已开始" if room.get("started", false) else " · 等待冒险"], 17, ui.MUTED))
		row.add_child(ui.button("加入", func(): ui.dialogs.enter_room(room, "player")))
		row.add_child(ui.button("观战", func(): ui.dialogs.enter_room(room, "spectator"), room.get("allow_spectators", true)))
