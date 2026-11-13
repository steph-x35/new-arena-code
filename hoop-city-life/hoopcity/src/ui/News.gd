extends Object
class_name News

## Mostrata una sola volta per installazione, anche se si cambia carriera.
## Le installazioni che l'avevano gia' vista conservano la loro scelta.

## Titolo grosso (colore caldo) e corpo, uno dopo l'altro.
const ITEMS := [
	["news.builder", "news.builder.b"],
	["news.season", "news.season.b"],
	["news.gameplay", "news.gameplay.b"],
	["news.courts", "news.courts.b"],
	["news.v1", "news.v1.b"],
]

const TITLE_COL := Color(1.0, 0.80, 0.34)
const BODY_COL := Color(1, 1, 1, 0.92)


static func maybe_show(host_tree: SceneTree) -> void:
	if bool(Settings.get_v("news_install_seen", false)):
		return
	# Migrazione dal flag di carriera usato dalle vecchie anteprime.
	if bool(Game.profile.get("news_builder_seen", false)):
		Settings.set_v("news_install_seen", true)
		return
	Settings.set_v("news_install_seen", true)
	Game.profile["news_builder_seen"] = true
	Game.profile["changelog_seen"] = Game.VERSION
	SaveSystem.save_game()
	var layer := CanvasLayer.new()
	layer.layer = 100
	host_tree.root.add_child(layer)
	var p := GamePanel.new().build(Loc.t("news.title"), Vector2(880, 760))
	layer.add_child(p)
	p.add_text("%s  ·  v%s" % [Loc.t("news.range"), Game.VERSION], 16,
		Color(1, 1, 1, 0.5))
	p.add_text("")
	for it in ITEMS:
		p.add_text(Loc.t(String(it[0])), 24, TITLE_COL)
		p.add_text(Loc.t(String(it[1])), 18, BODY_COL)
		p.add_text("")
	p.add_text(Loc.t("news.outro"), 17, Color(1, 1, 1, 0.55))
	p.tree_exiting.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())
	p.add_button(Loc.t("news.ok"), func(): p.close(), true)
