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
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		push_error("SaveSystem: write failed (%s)" % write_error)
		return false
	# Rename over the destination without deleting the previous save first.
	# If replacement fails, the existing save must remain intact.
	var err := DirAccess.rename_absolute(tmp, _path(slot))
	if err != OK:
		push_error("SaveSystem: replace failed (%s)" % err)
		return false
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
	return _merge_dictionary(d, Game.default_profile())

func _merge_dictionary(d: Dictionary, defaults: Dictionary) -> Dictionary:
	# JSON numbers are floats even when defaults are integers. Accept both,
	# but reject incompatible types before they can reach gameplay or UI.
	for key in defaults:
		var fallback = defaults[key]
		var value = d.get(key)
		var numeric: bool = (typeof(fallback) in [TYPE_INT, TYPE_FLOAT]
			and typeof(value) in [TYPE_INT, TYPE_FLOAT])
		if value == null or (typeof(value) != typeof(fallback) and not numeric):
			d[key] = fallback.duplicate(true) if fallback is Dictionary or fallback is Array else fallback
		elif fallback is Dictionary:
			d[key] = _merge_dictionary(value, fallback)
	return d

func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	# if v < 2: ...future migrations here...
	d["version"] = SCHEMA
	return d
