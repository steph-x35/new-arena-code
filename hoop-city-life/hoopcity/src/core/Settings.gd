extends Node
## Player options, stored separately from the career save.

const PATH := "user://settings.json"
var data := {
	"joystick_sensitivity": 1.0,
	"target_fps": 60,
	"lowgfx": false,   # dispositivi datati: meno dettagli, fisica 30Hz
	"sfx": 1.0,
	"music": 0.7,
	"voice": 1.0,
	"crowd": 1.0,
	"left_handed_ui": false,
	"show_shot_meter": true,
}

func _ready() -> void:
	load_settings()
	apply()

func get_v(k: String, def = null):
	return data.get(k, def)

func set_v(k: String, v) -> void:
	data[k] = v
	save_settings()
	apply()

func apply() -> void:
	Engine.max_fps = int(data.get("target_fps", 60))
	# Su dispositivi lenti la FISICA scende a 30Hz insieme al rendering:
	# dimezza il costo CPU di AI,Players,Ball senza cambiare il gameplay.
	var low: bool = bool(data.get("lowgfx", false))
	Engine.physics_ticks_per_second = 30 if (low or int(data.get("target_fps", 60)) == 30) else 60
	var vp: Object = Engine.get_main_loop()
	if vp != null and vp is Viewport:
		(vp as Viewport).msaa_2d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	var sfxnode = get_node_or_null("/root/Sfx")
	if sfxnode:
		sfxnode.apply_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(PATH): return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var p = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(p) == TYPE_DICTIONARY:
		for k in p: data[k] = p[k]

func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
