extends Object
class_name News

## Finestra NOVITA' (v2.40.3): elenco puntato dei miglioramenti della
## versione, mostrata UNA volta sola per versione quando l'INTRO si asseda
## (subito dopo lo splash di Godot, coi bottoni del menu gia' visibili).
## Il flag viene scritto SUBITO alla creazione: anche chiudendo l'app senza
## toccare la finestra, quella versione non la mostra piu'.

static func maybe_show(host_tree: SceneTree) -> void:
	if String(Game.profile.get("changelog_seen", "")) == Game.VERSION:
		return
	Game.profile["changelog_seen"] = Game.VERSION
	SaveSystem.save_game()
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
	p.tree_exiting.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())
	p.add_button(Loc.t("news.ok"), func(): p.close(), true)
