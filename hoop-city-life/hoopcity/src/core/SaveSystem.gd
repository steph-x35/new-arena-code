extends Node
## Robust JSON save/load with slot support, atomic write and schema migration.

const DIR := "user://saves"
const AUTOSAVE := "autosave"
const SCHEMA := 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

func _path(slot: String) -> String:
	return "%s/%s.json" % [DIR, slot]

func has_save(slot := AUTOSAVE) -> bool:
	return FileAccess.file_exists(_path(slot))

func save_game(slot := AUTOSAVE) -> bool:
	Game.profile["version"] = SCHEMA
	var tmp := _path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot open %s" % tmp)
		return false
	f.store_string(JSON.stringify(Game.profile, "\t"))
	f.close()
	# atomic-ish swap so a crash mid-write never corrupts the real save
	var d := DirAccess.open(DIR)
	if d.file_exists(_path(slot).get_file()):
		d.remove(_path(slot).get_file())
	d.rename(tmp.get_file(), _path(slot).get_file())
	return true

func load_game(slot := AUTOSAVE) -> bool:
	if not has_save(slot): return false
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null: return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: corrupt save, ignoring")
		return false
	Game.profile = _migrate(_merge_defaults(parsed))
	return true

func delete_save(slot := AUTOSAVE) -> void:
	if has_save(slot):
		DirAccess.open(DIR).remove(_path(slot).get_file())

func _merge_defaults(d: Dictionary) -> Dictionary:
	## Any key added in a newer build gets filled in from defaults -> old saves keep working.
	var base := Game.default_profile()
	for k in base:
		# Un valore esplicitamente NULL nel file vale come chiave assente:
		# i campi corrotti tornano ai default invece di avvelenare la UI.
		if not d.has(k) or d[k] == null:
			d[k] = base[k]
		elif typeof(base[k]) == TYPE_DICTIONARY and typeof(d[k]) == TYPE_DICTIONARY:
			for k2 in base[k]:
				if not d[k].has(k2): d[k][k2] = base[k][k2]
	return d

func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	# if v < 2: ...future migrations here...
	d["version"] = SCHEMA
	return d
