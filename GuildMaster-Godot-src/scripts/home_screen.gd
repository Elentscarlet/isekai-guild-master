class_name GuildHomeScreen
extends GuildScreen

# 主页：节点位置和尺寸在 home_screen.tscn 里用编辑器摆，
# 这里只负责填文字、换立绘、接回调。

var _portrait: GuildPortrait

func on_ready() -> void:
	_portrait = get_node_or_null("PortraitCard/Portrait") as GuildPortrait

func bind(owner) -> void:
	ui = owner
	apply_language()
	_bind_buttons()
	_bind_portrait()

func apply_language() -> void:
	super.apply_language()
	var version = str(ProjectSettings.get_setting("application/config/version")).trim_suffix("-godot")
	var footer = get_node_or_null("FooterLeft") as Label
	if footer != null:
		footer.text = GuildLang.t("异世界公会长  /  " + version)

func _bind_buttons() -> void:
	_wire("MenuConnect", func(): ui.dialogs.connect_setup(), true, true)
	_wire("MenuOffline", func(): ui.session.start_local(ui.prefs.name))
	_wire("MenuConnectSettings", func(): ui.dialogs.settings())
	_wire("MenuRules", func(): ui.dialogs.help())
	_wire("MenuGallery", func(): ui.dialogs.gallery())
	_wire("MenuGuide", func(): ui.dialogs.help())
	_wire("MenuPreferences", func(): ui.dialogs.settings())
	_wire("MenuAbout", func(): ui.dialogs.about())
	_wire("MenuQuit", func(): ui.dialogs.confirm_quit())

# 场景里的按钮直接套用和 action() 一样的字号/纸张样式。
func _wire(name: String, callback: Callable, enabled: bool = true, primary: bool = false) -> void:
	var node = wire_button(name, callback, enabled, primary)
	if node == null:
		return
	# 与原 home() 一致：窄按钮改用 plaque 纸牌样式。
	if node.size.x < 150.0:
		for state in ["normal", "hover", "pressed", "disabled"]:
			node.add_theme_stylebox_override(state, GuildPaperSkin.plaque(state, 6))

func _bind_portrait() -> void:
	var keys = []
	for key in ui.store.catalog.heroes:
		if ui.store.catalog.heroes[key].get("available", false) and not ui.store.portrait_source(key).is_empty():
			keys.append(key)
	if keys.is_empty():
		keys = ["hainie_red"]
	if ui.home_portrait == "" or not keys.has(ui.home_portrait):
		ui.home_portrait = keys[randi() % keys.size()]
	var card = get_node_or_null("PortraitCard") as Panel
	if card != null:
		card.add_theme_stylebox_override("panel", GuildPaperSkin.paper("paper", 0))
	if _portrait != null:
		_portrait.texture = ui.store.portrait(ui.home_portrait)
		_portrait.on_click = func(): ui.dialogs.hero_detail({"hero": ui.home_portrait})
	var arrows = keys.size() > 1
	for pair in [["PortraitCard/Prev", -1], ["PortraitCard/Next", 1]]:
		var arrow = get_node_or_null(pair[0]) as Button
		if arrow == null:
			continue
		arrow.visible = arrows
		if not arrows:
			continue
		arrow.pressed.connect(func():
			ui.home_portrait = keys[posmod(keys.find(ui.home_portrait) + pair[1], keys.size())]
			ui.rerender())
