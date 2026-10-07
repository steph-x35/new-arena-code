extends Node2D
## DEV ONLY: draws one avatar per hair style, so the cuts can be eyeballed.
##   xvfb-run -s "-screen 0 1280x400x24" godot --path . res://tools/HairProbe.tscn -- --out /tmp/hair.png
var out_path := "/tmp/hair.png"

func _ready() -> void:
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			out_path = args[i + 1]
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("HAIR: saved ", out_path)
	get_tree().quit()

func _draw() -> void:
	var hair := Color(0.16, 0.11, 0.09)
	var skin := Color(0.78, 0.58, 0.42)
	# 0 normale · 1 rasato · 4 ricci · 5 dreadlocks  (men)   6 coda · 7 lunghi (women)
	var styles := [0, 1, 4, 5, 6, 7]
	var x := 120.0
	for st in styles:
		var cols := {
			"skin": skin, "hair": hair, "jersey": Color(0.85, 0.25, 0.22),
			"shorts": Color(0.55, 0.14, 0.12), "shoes": Color(0.95, 0.95, 0.97),
			"trim": Color(0.95, 0.95, 0.97), "muscle": 0.0, "hst": st, "kit": false,
		}
		var po := Avatar.pose(Avatar.IDLE, 0.0, 0.0, "", false)
		Avatar.draw_body(self, Vector2(x, 260.0), 150.0, 1.0, po, cols, false, false, false)
		draw_string(ThemeDB.fallback_font, Vector2(x - 30.0, 300.0), "hst %d" % st,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1))
		x += 180.0
