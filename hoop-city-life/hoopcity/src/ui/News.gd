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
		Loc.t("news.title"), Vector2(880, 760))
	layer.add_child(p)
	# La finestra delle novita', dalla v2.39.1 a oggi: prima la regina
	# (il campo condiviso), poi i due mondi in sezioni — cosi' chi legge
	# capisce in dieci secondi cosa si e' perso.
	p.add_text("%s  ·  v%s" % [Loc.t("news.range"), Game.VERSION], 16,
		Color(1, 1, 1, 0.5))
	p.add_text("")
	p.add_text(Loc.t("news.hero"), 26, Color(1.0, 0.82, 0.35))
	p.add_text(Loc.t("news.hero.body"), 19, Color(1, 1, 1, 0.92))
	p.add_text("")
	p.add_text(Loc.t("news.s1"), 16, Color(0.55, 0.85, 1.0))
	p.add_text(Loc.t("news.b1"), 18)
	p.add_text(Loc.t("news.b2"), 18)
	p.add_text(Loc.t("news.b3"), 18)
	p.add_text(Loc.t("news.b4"), 18)
	p.add_text("")
	p.add_text(Loc.t("news.s2"), 16, Color(0.55, 0.85, 1.0))
	p.add_text(Loc.t("news.b5"), 18)
	p.add_text(Loc.t("news.b6"), 18)
	p.add_text(Loc.t("news.b7"), 18)
	p.add_text("")
	p.add_text(Loc.t("news.outro"), 17, Color(1, 1, 1, 0.55))
	p.tree_exiting.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())
	p.add_button(Loc.t("news.ok"), func(): p.close(), true)
