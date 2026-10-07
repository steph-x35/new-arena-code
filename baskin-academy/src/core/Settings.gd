extends Node
## Player options, stored separately from the career save.

const PATH := "user://settings.json"
var data := {
	"joystick_sensitivity": 1.0,
	"target_fps": 60,
	"sfx": 1.0,
	"music": 0.7,
	"voice": 1.0,
	"crowd": 1.0,
	"left_handed_ui": false,
	"show_shot_meter": true,
	# Italian is the default language of the app; English stays available.
	"lang": "it",
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
