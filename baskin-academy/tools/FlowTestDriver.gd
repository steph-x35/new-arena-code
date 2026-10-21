extends Node
## DEV ONLY. Drives the REAL navigation: menu PLAY -> KitPicker (8:00) ->
## RolePicker (tap role 2) -> MatchScene, verifying the role applies, the
## in-match picker is skipped and both rules panels work.

var fails := 0

func check(nm: String, cond: bool) -> void:
	if cond:
		print("  ok: ", nm)
	else:
		fails += 1
		print("  FAIL: ", nm)

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	print("FLOW TEST: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()

func _wait_scene(nm: String) -> Node:
	for i in 90:
		var c: Node = get_tree().current_scene
		if c != null and c.name == nm:
			return c
		await get_tree().process_frame
	return null

func _find_button(n: Node, texts: Array) -> Button:
	if n is Button:
		for t in texts:
			if String((n as Button).text).begins_with(String(t)):
				return n
	for c in n.get_children():
		var b := _find_button(c, texts)
		if b != null:
			return b
	return null

func _find_label(n: Node, txt: String) -> Label:
	if n is Label and String((n as Label).text) == txt:
		return n
	for c in n.get_children():
		var l := _find_label(c, txt)
		if l != null:
			return l
	return null

func _run() -> void:
	# 1. menu
	var menu: Node = await _wait_scene("MainMenu")
	check("menu loads", menu != null)
	if menu == null:
		return
	check("big title", _find_label(menu, "BASKIN ACADEMY") != null)
	var play := _find_button(menu, ["PLAY", "GIOCA"])
	check("play button", play != null)
	play.pressed.emit()
	# 2. kit picker: longest duration, then onward
	var kit: Node = await _wait_scene("KitPicker")
	check("kitpicker loads", kit != null)
	if kit == null:
		return
	var d8 := _find_button(kit, ["8:00"])
	check("8:00 option", d8 != null)
	d8.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check("8min stored", float(Game.profile.get("quarter_seconds", 0.0)) == 480.0)
	var tip := _find_button(kit, [Loc.t("setup.tipoff")])
	check("tipoff button", tip != null)
	tip.pressed.emit()
	# 3. role picker: tap the role-2 card, then go
	var rp: Node = await _wait_scene("RolePicker")
	check("rolepicker loads", rp != null)
	if rp == null:
		return
	check("role title", _find_label(rp, Loc.t("rolepick.title")) != null)
	var cards := []
	_collect_cards(rp, cards)
	check("5 role cards", cards.size() == 5)
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	(cards[1] as PanelContainer).emit_signal("gui_input", ev)
	await get_tree().process_frame
	check("role 2 selected", int(rp.get("selected")) == 2)
	check("role 2 stored", int(Game.profile.get("baskin_role", 0)) == 2)
	var go := _find_button(rp, [Loc.t("rolepick.go")])
	check("role go button", go != null)
	go.pressed.emit()
	# 4. match: role applied, picker skipped, panels work
	var ms: Node = await _wait_scene("MatchScene")
	check("match loads", ms != null)
	if ms == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var court: Node = ms.get_node("Court")
	check("user is role 2", court.user.role == 2)
	check("user is 2T", String(court.user.variant) == "2T")
	check("picker skipped", bool(ms.get("_role_pending")) == false)
	check("rules button", ms.get("rules_btn") != null)
	ms._toggle_rules()
	check("rules panel opens", (ms.get("rules_panel") as Control).visible)
	ms._toggle_rules()
	check("rules panel closes", not (ms.get("rules_panel") as Control).visible)
	ms._on_rule("v_illegal")
	check("rule card shows", (ms.get("rule_panel") as Control).visible)
	check("rule card title", String((ms.get("rule_title") as Label).text) == Loc.t("rule.v_illegal"))
	check("8min clock", float(court.get("quarter_len")) == 480.0 and float(court.get("game_clock")) == 480.0)
	check("24s shot clock", float(court.get("shot_clock")) == 24.0)

func _collect_cards(n: Node, out: Array) -> void:
	if n is PanelContainer and (n as PanelContainer).custom_minimum_size == Vector2(224, 396):
		out.append(n)
	for c in n.get_children():
		_collect_cards(c, out)
