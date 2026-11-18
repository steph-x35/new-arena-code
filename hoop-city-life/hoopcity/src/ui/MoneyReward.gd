extends CanvasLayer
## One global overlay, above scene changes. Rewards remain in the career save
## until collected, so leaving the app never silently loses the money.

class Coin extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.43
		draw_circle(c, r * 1.17, Color(1.0, 0.72, 0.18, 0.16))
		draw_circle(c + Vector2(0, 6), r, Color(0.62, 0.31, 0.04))
		draw_circle(c, r, Color(1.0, 0.73, 0.20))
		draw_arc(c, r * 0.81, 0, TAU, 48, Color(1.0, 0.9, 0.52), 4.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-r * 0.42, r * 0.48), "$",
			HORIZONTAL_ALIGNMENT_CENTER, r * 0.84, int(r * 1.35), Color(0.48, 0.24, 0.04))

var overlay: Control
var coin: Coin
var amount: Label
var prompt: Label
var owner_profile: Dictionary
var busy := false

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.money_rewards_pending.connect(_request_show)
	_request_show()

func _request_show() -> void:
	call_deferred("_show_next")

func _show_next() -> void:
	if overlay != null and is_instance_valid(overlay):
		# A new career or loaded save must never claim the previous profile's reward.
		if is_same(owner_profile, Game.profile):
			return
		overlay.queue_free()
		overlay = null
		busy = false
	var pending: Array = Game.profile.get("pending_money_rewards", [])
	if pending.is_empty():
		return
	owner_profile = Game.profile
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.10, 0.83)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	var title := Label.new()
	title.text = Loc.t("reward.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58))
	column.add_child(title)
	coin = Coin.new()
	coin.custom_minimum_size = Vector2(190, 190)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(coin)
	amount = Label.new()
	amount.text = "+%d" % int(pending[0])
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size", 58)
	amount.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34))
	column.add_child(amount)
	prompt = Label.new()
	prompt.text = Loc.t("reward.continue")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 22)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	column.add_child(prompt)
	var button := Button.new()
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_collect)
	overlay.add_child(button)
	coin.pivot_offset = Vector2(95, 95)
	coin.scale = Vector2(0.35, 0.35)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(coin, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _collect() -> void:
	if busy:
		return
	if not is_same(owner_profile, Game.profile):
		_show_next()
		return
	busy = true
	var reward := Game.claim_money_reward()
	if reward <= 0:
		_close()
		return
	prompt.visible = false
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(coin, "position:y", coin.position.y - 140.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(coin, "scale", Vector2(0.3, 0.3), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.4).set_delay(0.15)
	tw.chain().tween_callback(_close)

func _close() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	busy = false
	_request_show()
