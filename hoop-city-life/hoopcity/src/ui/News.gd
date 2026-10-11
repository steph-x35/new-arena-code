extends Object
class_name News

## Finestra NOVITA' (v2.40.2): elenco puntato dei miglioramenti della
## versione, mostrata UNA volta sola per versione. La chiama la prima
## scena dell'app (IntroScene) appena finisce lo splash di Godot, su un
## layer dedicato che sta sopra ogni UI e sopravvive ai cambi di scena.

static func maybe_show(host_tree: SceneTree) -> void:
	if String(Game.profile.get("changelog_seen", "")) == Game.VERSION:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	host_tree.root.add_child(layer)
	var p := GamePanel.new().build(
		"%s  ·  v%s" % [Loc.t("news.title"), Game.VERSION], Vector2(800, 620))
	layer.add_child(p)
	p.add_text(Loc.t("news.b1"), 19)
	p.add_text(Loc.t("news.b2"), 19)
	p.add_text(Loc.t("news.b3"), 19)
	p.add_text(Loc.t("news.b4"), 19)
	# Una volta chiusa (bottone, gesto indietro o tocco fuori) la versione
	# e' vista: non riappare finche' non cambia.
	p.tree_exiting.connect(func():
		Game.profile["changelog_seen"] = Game.VERSION
		SaveSystem.save_game()
		if is_instance_valid(layer):
			layer.queue_free())
	p.add_button(Loc.t("news.ok"), func(): p.close(), true)
