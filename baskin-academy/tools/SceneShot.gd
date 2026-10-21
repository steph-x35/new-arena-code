extends Node2D
## Headless-friendly screenshot catcher (needs a virtual display, e.g. xvfb-run).
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/SceneShot.tscn \
##       -- --scene res://src/scenes/MainMenu.tscn --wait 1.5 --out /tmp/shot.png
## Options:
##   --scene <path>   scene to load (default MainMenu)
##   --wait  <secs>   seconds of live gameplay before the capture (default 1.5)
##   --out   <path>   png destination (default /tmp/shot.png)
##   --drive          attach an AIBrain to the user slot (match scenes) so the
##                    pad/HUD is exercised like a real session
##   --seq  <n>       capture n frames, one per second, suffixed _0.._n-1

var _scene := "res://src/scenes/MainMenu.tscn"
var _wait := 1.5
var _out := "/tmp/shot.png"
var _drive := false
var _seq := 0
var _lang := ""
var _fixture := false
var _bench := -1.0
var _gear := false
var _role := 0

func _ready() -> void:
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--scene": _scene = args[i + 1]
			"--wait": _wait = float(args[i + 1])
			"--out": _out = args[i + 1]
			"--drive": _drive = true
			"--seq": _seq = int(args[i + 1])
			"--lang": _lang = args[i + 1]
			"--fixture": _fixture = true
			"--bench": _bench = float(args[i + 1])
			"--gear": _gear = true
			"--role": _role = int(args[i + 1])
	if _lang != "":
		Loc.set_lang(_lang)
	if _role > 0:
		Game.profile["baskin_role"] = _role
	if _fixture:
		Game.profile["next_match_mode"] = "full"
		Game.profile["match_is_fixture"] = true
	if _gear:
		# proof shots: every rehab-lab piece equipped, loud colours, mixed sides
		Game.profile["gear"] = {
			"knee_sleeve": {"on": true, "side": 1, "col": "#c8434c"},
			"ankle_brace": {"on": true, "side": -1, "col": "#2f63c0"},
			"wrist_tape": {"on": true, "side": 1, "col": "#e5a125"},
			"compression": {"on": true, "side": 1, "col": "#3f9e57"}}
	var ps: PackedScene = load(_scene)
	if ps == null:
		push_error("cannot load " + _scene)
		get_tree().quit(1)
		return
	var inst: Node = ps.instantiate()
	add_child(inst)
	if _drive:
		_drive_user(inst)
	if _bench >= 0.0:
		_bench_user(inst)
	_capture_loop()

func _bench_user(root: Node) -> void:
	var court: Node = _find(root, "Court")
	if court == null:
		return
	get_tree().create_timer(_bench).timeout.connect(func():
		if is_instance_valid(court):
			court.bench_user())

func _drive_user(root: Node) -> void:
	var court: Node = _find(root, "Court")
	if court == null:
		return
	var user: Node = court.get("user")
	if user == null:
		return
	user.is_user = false
	var BrainScript: Script = load("res://src/match/AIBrain.gd")
	var brain: Node = BrainScript.new()
	user.add_child(brain)
	brain.setup(user, court)

func _find(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var r := _find(c, name)
		if r != null:
			return r
	return null

func _capture_loop() -> void:
	var frames := maxi(_seq, 1)
	for f in frames:
		var t := 0.0
		var step := 1.0 / 30.0
		var target := _wait if f == 0 else 1.0
		while t < target:
			await get_tree().process_frame
			t += step
		# let one rendered frame land after the last process frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path := _out if frames == 1 else _out.replace(".png", "_%d.png" % f)
		img.save_png(path)
		print("SHOT ", path, " ", img.get_size())
	get_tree().quit(0)
