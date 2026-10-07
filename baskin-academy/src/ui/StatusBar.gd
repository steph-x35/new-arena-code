extends Control
## Persistent top strip: day/clock/weather plus vitals as icon chips.
## v1.8: charcoal band with an orange hairline, vector icons instead of emoji
## (emoji render differently on every Android skin), values as tight chips.

var lbl_info: Label
var toast: Label
var chips := {}          # stat id -> Label holding the number

const CHIPS := [
	["energy", "bolt", "energy"],
	["hunger", "food", "hunger"],
	["health", "heart", "health"],
	["money", "coin", "money"],
	["rep", "star", "rep"],
	["level", "whistle", "level"],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.047, 0.063, 0.78)
	bg.custom_minimum_size = Vector2(0, 54)
	bg.size = Vector2(2000, 54)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var line := ColorRect.new()
	line.color = Color(0.949, 0.420, 0.114, 0.85)
	line.position = Vector2(0, 54)
	line.size = Vector2(2000, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	var row := HBoxContainer.new()
	row.position = Vector2(20, 10)
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	lbl_info = Label.new()
	lbl_info.add_theme_font_size_override("font_size", 21)
	lbl_info.add_theme_color_override("font_color", Color(0.965, 0.949, 0.906, 0.92))
	lbl_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl_info)

	for c in CHIPS:
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(22, 22)
		ic.size = Vector2(22, 22)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kind: String = c[1]
		var col: Color = Art.GREEN if c[0] == "energy" else (
			Art.ORANGE_HOT if c[0] == "hunger" else (
			Art.RED if c[0] == "health" else (
			Art.GOLD if c[0] == "money" else (
			Art.BLUE if c[0] == "rep" else Art.CREAM))))
		ic.draw.connect(func(): Art.draw_icon(ic, kind, Rect2(Vector2.ZERO, ic.size), col))
		row.add_child(ic)
		var v := Label.new()
		v.add_theme_font_size_override("font_size", 21)
		v.add_theme_color_override("font_color", Color(0.965, 0.949, 0.906, 0.92))
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		chips[c[0]] = v
	# level chip shows as "Lv 3"
	chips["level"].text = ""

	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 26)
	toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast.position = Vector2(0, 70)
	toast.custom_minimum_size = Vector2(600, 0)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", Art.GOLD)
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)

	Events.toast.connect(_on_toast)
	Events.phone_notification.connect(func(app, t, b): _on_toast("[%s] %s" % [app, Loc.tx(t)]))
	set_process(true)

var _last := ""

func _process(_d: float) -> void:
	# Only touch labels when something actually changed: rebuilding this row
	# every frame allocates on the main thread and shows up as hitches.
	var p: Dictionary = Game.profile
	var info := "%s %d  ·  %s  ·  %s" % [Loc.t("status.day"), p["day"],
		Game.clock_string(), Game.weather_label()]
	var vals := {
		"energy": str(int(p["energy"])),
		"hunger": str(int(p["hunger"])),
		"health": str(int(p["health"])),
		"money": "%d$" % p["money"],
		"rep": str(p["rep"]),
		"level": "Lv %d" % p["level"],
	}
	var sig := info + "|" + str(vals.hash())
	if sig != _last:
		_last = sig
		lbl_info.text = info
		for k in vals:
			chips[k].text = vals[k]

func _on_toast(t: String) -> void:
	toast.text = Loc.tx(t)
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.6)
