extends Control
class_name GamePanel
## Sliding modal panel used by the fridge, wardrobe, shop shelves, etc.
## Dark translucent backdrop + a card that slides up. Closes on backdrop tap.

var card: PanelContainer
var body: VBoxContainer
var title_label: Label
var _wanted_size := Vector2(880, 720)
var _open_tween: Tween = null
## Guards against the opening touch closing the panel again. The backdrop
## ignores everything until the open animation has settled.
var _armed := false
var _press_on_dim := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func build(title: String, card_size := Vector2(880, 720)) -> GamePanel:
	# The card must NEVER be bigger than the screen. A fixed 900x760 card on a
	# 1280x720 tablet pushed its own content off both edges: that is exactly how
	# the wardrobe ended up unreadable. Clamp against the live viewport instead.
	_wanted_size = card_size
	var vp: Vector2 = _screen()
	card_size = _fit(vp)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	# The backdrop must NOT close on a press. The very touch that opens a panel
	# is still being dispatched when the backdrop appears underneath the
	# finger, so a press-to-close made the dialog flash open and vanish -- the
	# bed "did nothing" for exactly this reason. Close on RELEASE only, and
	# only for a release belonging to a press that landed on the backdrop
	# after it had settled.
	dim.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed):
			if _armed:
				_press_on_dim = true
			return
		if (e is InputEventScreenTouch and not e.pressed) \
		or (e is InputEventMouseButton and not e.pressed):
			if _armed and _press_on_dim:
				close()
			_press_on_dim = false)
	add_child(dim)
	create_tween().tween_property(dim, "color", Color(0, 0, 0, 0.66), 0.18)

	card = PanelContainer.new()
	card.custom_minimum_size = card_size
	# Pin the size as well as the minimum: a PanelContainer grows to fit its
	# content, and a grown card no longer matches the centring offset -- that
	# is what shifted the wardrobe sideways off the screen.
	card.size = card_size
	card.clip_contents = true
	# Centre with EXPLICIT top-left coordinates. PRESET_CENTER resolves against
	# a parent that has no size yet at build() time, which yielded negative
	# global positions and pushed the card off the left edge.
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.pivot_offset = card_size * 0.5
	var home: Vector2 = ((vp - card_size) * 0.5).round()
	card.position = home + Vector2(0, 60)
	card.modulate.a = 0.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.18)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", sb)
	add_child(card)
	_open_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var tw := _open_tween
	tw.tween_property(card, "position", home, 0.26)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.20)
	# Only safe once we are actually inside the tree; a detached panel has no
	# tree to listen to and connecting there spams "data.tree is null".
	if is_inside_tree():
		var vpo: Viewport = get_viewport()
		if vpo != null and not vpo.size_changed.is_connected(_relayout):
			vpo.size_changed.connect(_relayout)
	# Re-measure once the layout has settled: at build() time the window may
	# still report the pre-rotation size, which oversizes the card.
	call_deferred("_relayout")
	# Arm the backdrop only after the opening touch is long gone. build() can
	# run before the panel is in the tree, where there is no SceneTree to ask
	# for a timer, so defer the arming until _ready().
	call_deferred("_arm_later")

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	card.add_child(outer)

	var head := HBoxContainer.new()
	# Explicit BACK button. Tapping the backdrop also closes, but that is an
	# invisible affordance -- players got stuck and force-quit the app.
	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2(132, 64)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(close)
	head.add_child(back)

	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var x := Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(64, 64)
	x.add_theme_font_size_override("font_size", 26)
	x.pressed.connect(close)
	head.add_child(x)
	outer.add_child(head)
	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	return self

func _screen() -> Vector2:
	## Lo SPAZIO LOGICO dello stretch (canvas_items+expand): il viewport
	## visible_rect e' dove la UI vive davvero (telefono 20:9 = ~1520x720,
	## window.size sarebbero PIXEL GREZZI del device -> card meta' fuori
	## sul telefono). Dopo una rotazione puo' essere in ritardo: il clamp
	## di _relayout copre comunque lo screen reale.
	if get_viewport() != null:
		var r: Rect2 = get_viewport().get_visible_rect()
		if r.size.x > 0 and r.size.y > 0:
			return r.size
	return Vector2(1280, 720)

func _fit(vp: Vector2) -> Vector2:
	return Vector2(minf(_wanted_size.x, vp.x - 72.0), minf(_wanted_size.y, vp.y - 72.0))

func _relayout() -> void:
	## Keep the card centred and inside the screen after a rotation/resize.
	if card == null or not is_instance_valid(card):
		return
	# Kill the slide-in first: an in-flight tween would otherwise animate the
	# card back to the position computed for the OLD screen size.
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
		card.modulate.a = 1.0
	var vp: Vector2 = _screen()
	var cs: Vector2 = _fit(vp)
	card.custom_minimum_size = cs
	card.size = cs
	card.pivot_offset = cs * 0.5
	card.position = ((vp - cs) * 0.5).round()
	# Ultima barriera: MAI fuori schermo, anche con dimensioni faziose.
	card.position.x = clampf(card.position.x, 8.0, maxf(8.0, vp.x - cs.x - 8.0))
	card.position.y = clampf(card.position.y, 8.0, maxf(8.0, vp.y - cs.y - 8.0))

func _unhandled_input(event: InputEvent) -> void:
	## Android's hardware/gesture Back closes the panel instead of the app.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

## Delayed arming of the tap-outside-to-close backdrop.
func _arm_later() -> void:
	if not is_inside_tree():
		# Not in the tree yet: try again once we are.
		if not tree_entered.is_connected(_arm_later):
			tree_entered.connect(_arm_later, CONNECT_ONE_SHOT)
		return
	await get_tree().create_timer(0.35).timeout
	_armed = true

func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)

func clear_body() -> void:
	for c in body.get_children():
		c.queue_free()

func add_text(t: String, size := 20, col := Color(1, 1, 1, 0.85)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = col
	body.add_child(l)
	return l

func content_width() -> float:
	## Usable width inside the card, derived from the SCREEN rather than from
	## card.size, which may still hold a stale pre-resize value while the
	## layout settles. Grids sized off the stale value forced the card wider
	## than the display and pushed the close button off the edge.
	return maxf(_fit(_screen()).x - 64.0, 200.0)

func columns_for(cell_w: float) -> int:
	# (cell_w + separazione) per colonna, con un margine di sicurezza:
	# l'ultima colonna non deve MAI uscire dal pannello.
	var per: float = cell_w + 12.0
	return maxi(int((content_width() - 24.0) / per), 2)

func add_grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	body.add_child(g)
	return g

func add_button(text: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 78)
	b.add_theme_font_size_override("font_size", 24)
	if accent:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.52, 0.36)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(cb)
	body.add_child(b)
	return b
