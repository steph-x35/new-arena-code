extends Object
class_name News

## Finestra NOVITA': elenco puntato dei miglioramenti della versione, mostrata
## UNA volta sola per versione quando l'INTRO si assesta (subito dopo lo
## splash di Godot, coi bottoni del menu gia' visibili).
## Il flag viene scritto SUBITO alla creazione: anche chiudendo l'app senza
## toccare la finestra, quella versione non la mostra piu'.
##
## v2.49.3: la finestra non e' piu' "tutto quello che e' cambiato dalla
## 2.39.1" (un muro di testo che nessuno legge): e' quello che si VEDE nei
## primi dieci secondi di gioco, in ordine di quanto salta all'occhio.
## Il testo vive in Loc, le righe qui sotto dicono solo quali chiavi e che
## colore — cosi' aggiungere una voce e' una riga, non un blocco.

## Titolo grosso (colore caldo) e corpo, uno dopo l'altro.
const ITEMS := [
	["news.v1", "news.v1.b"],
	["news.hallow", "news.hallow.b"],
	["news.n1", "news.n1.b"],
	["news.n2", "news.n2.b"],
	["news.n3", "news.n3.b"],
	["news.n4", "news.n4.b"],
	["news.n5", "news.n5.b"],
	["news.n6", "news.n6.b"],
	["news.n7", "news.n7.b"],
]

const TITLE_COL := Color(1.0, 0.80, 0.34)
const BODY_COL := Color(1, 1, 1, 0.92)


static func maybe_show(host_tree: SceneTree) -> void:
	if String(Game.profile.get("changelog_seen", "")) == Game.VERSION:
		return
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
