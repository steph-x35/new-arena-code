extends Node2D
## Page & Print -- posters for the flat, and short books worth reading.

@onready var root: Control = $UI/Root

var tab := "posters"

func _ready() -> void:
	Game.profile["last_building"] = "books"
	_build()

func _build() -> void:
	for c in root.get_children():
		c.queue_free()
	UIKit.header(root, Loc.tx("PAGE & PRINT"), Loc.tx("Posters for the wall, books for the head."))
	root.add_child(preload("res://src/ui/StatusBar.gd").new())

	# --- tab strip
	var bar := HBoxContainer.new()
	bar.position = Vector2(60, 150)
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	for t in [["posters", "🖼  Posters"], ["books", "📚  Books"],
			["shelf", "🏠  My shelf"]]:
		var b := Button.new()
		b.text = String(t[1])
		b.custom_minimum_size = Vector2(210, 66)
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = (tab == String(t[0]))
		var id: String = String(t[0])
		b.pressed.connect(func():
			tab = id
			_build())
		bar.add_child(b)

	var v := UIKit.column(root, Vector2(60, 232))
	match tab:
		"posters":
			_posters(v)
		"books":
			_books(v)
		_:
			_shelf(v)

	UIKit.big_button(v, Loc.tx("Leave"),
		func(): SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	UIKit.back_and_phone(root)

func _posters(v: Control) -> void:
	for id in Library.POSTERS:
		var p: Dictionary = Library.POSTERS[id]
		var owned: bool = Library.owns_poster(id)
		var on_wall: bool = Library.hung() == id
		var title: String = String(p["name"])
		var sub: String = String(p["desc"])
		if on_wall:
			title = "✓ " + title
			sub += "  ·  ON YOUR WALL"
		elif owned:
			sub += "  ·  owned — tap to hang"
		else:
			sub += "  ·  %d$  ·  +%.1f energy each morning" % [
				int(p["price"]), float(p.get("mood", 0.0))]
		var pid: String = id
		_poster_row(v, pid, title, sub)

## A poster row you can actually judge: the artwork is drawn next to the name,
## and tapping it opens a big preview before you spend anything.
func _poster_row(v: Control, pid: String, title: String, sub: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)

	var thumb := PosterThumb.new()
	thumb.poster_id = pid
	thumb.custom_minimum_size = Vector2(96, 128)
	row.add_child(thumb)

	var b := Button.new()
	b.text = Loc.tx("%s\n%s") % [title, sub]
	b.custom_minimum_size = Vector2(470, 128)
	b.add_theme_font_size_override("font_size", 20)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	b.pressed.connect(func(): _preview_poster(pid))
	row.add_child(b)

## Full-size look at a poster, with the price, before you commit.
func _preview_poster(pid: String) -> void:
	var p: Dictionary = Library.POSTERS[pid]
	var panel: GamePanel = GamePanel.new().build(String(p["name"]), Vector2(860, 620))
	$UI.add_child(panel)

	var art := PosterThumb.new()
	art.poster_id = pid
	art.custom_minimum_size = Vector2(300, 400)
	panel.body.add_child(art)

	panel.add_text(String(p["desc"]), 21, Color(1, 1, 1, 0.75))
	var owned: bool = Library.owns_poster(pid)
	if owned:
		if Library.hung() == pid:
			panel.add_text("Hanging on your wall right now.", 20, Color(0.6, 1.0, 0.7))
			panel.add_button(Loc.tx("Take it down"), func():
				Library.hang("")
				panel.close()
				_build())
		else:
			panel.add_button(Loc.tx("Hang this one"), func():
				Library.hang(pid)
				panel.close()
				_build(), true)
	else:
		panel.add_text("%d$  ·  +%.1f energy every morning it is up"
			% [int(p["price"]), float(p.get("mood", 0.0))], 21, Color(1, 0.9, 0.5))
		panel.add_button(Loc.tx("Buy it"), func():
			if Library.buy_poster(pid):
				panel.close()
				_build(), true)
	panel.add_button(Loc.tx("Not now"), func(): panel.close())

func _books(v: Control) -> void:
	for id in Library.BOOKS:
		var b: Dictionary = Library.BOOKS[id]
		var owned: bool = Library.owns_book(id)
		var sub: String = String(b["desc"])
		if owned:
			sub += "  ·  owned (%d/%d read)" % [Library.progress(id), int(b["chapters"])]
		else:
			sub += "  ·  %d$  ·  %d chapters" % [int(b["price"]), int(b["chapters"])]
		var bid: String = id
		UIKit.big_button(v, String(b["name"]), func(): _preview_book(bid), sub)

## Look inside a book before buying: the blurb, the chapter list, and the
## opening lines of chapter one so you know what you are paying for.
func _preview_book(bid: String) -> void:
	var b: Dictionary = Library.BOOKS[bid]
	var panel: GamePanel = GamePanel.new().build(String(b["name"]), Vector2(900, 640))
	$UI.add_child(panel)
	panel.add_text("\"%s\"" % String(b["blurb"]), 22, Color(1, 0.92, 0.6))
	panel.add_text(String(b["desc"]), 20, Color(1, 1, 1, 0.72))
	panel.add_text("%d chapters · about %d minutes each" % [
		int(b["chapters"]), int(b["minutes"])], 19, Color(1, 1, 1, 0.55))
	panel.add_text("")
	# a genuine extract, not a placeholder
	var ch: Array = BookText.chapter(bid, 0)
	if String(ch[0]) != "":
		panel.add_text(String(ch[0]), 21, Color(0.7, 0.86, 1.0))
		var extract: String = String(ch[1])
		if extract.length() > 260:
			extract = extract.substr(0, 260) + "..."
		panel.add_text(extract, 18, Color(1, 1, 1, 0.68))
	panel.add_text("")
	if Library.owns_book(bid):
		panel.add_button(Loc.tx("Read it (on your shelf)"), func():
			panel.close()
			tab = "shelf"
			_build(), true)
	else:
		panel.add_button(Loc.tx("Buy for %d$") % int(b["price"]), func():
			if Library.buy_book(bid):
				panel.close()
				_build(), true)
	panel.add_button(Loc.tx("Put it back"), func(): panel.close())

func _shelf(v: Control) -> void:
	var books: Dictionary = Library.books_owned()
	if books.is_empty():
		UIKit.big_button(v, Loc.tx("Your shelf is empty"), Callable(),
			"Buy a book and read it a chapter at a time.")
		for c in v.get_children():
			if c is Button:
				c.disabled = true
		return
	for id in books:
		var b: Dictionary = Library.BOOKS.get(id, {})
		if b.is_empty():
			continue
		var done: bool = Library.is_finished(id)
		var sub: String
		if done:
			sub = "Finished  ·  \"%s\"" % String(b["blurb"])
		else:
			sub = "%d/%d chapters  ·  %d min each  ·  6 energy" % [
				Library.progress(id), int(b["chapters"]), int(b["minutes"])]
		var bid: String = id
		UIKit.big_button(v, (Loc.tx("✓ ") if done else Loc.tx("📖  ")) + String(b["name"]),
			func(): _read(bid), sub)


## The reader. Two pages of the current chapter, turned one at a time; the
## chapter only counts as read -- and only costs time and energy -- once you
## reach the end of it.
func _read(bid: String) -> void:
	var b: Dictionary = Library.BOOKS[bid]
	var idx: int = Library.progress(bid)
	if Library.is_finished(bid):
		idx = 0          # re-reading a finished book is free
	var ch: Array = BookText.chapter(bid, idx)
	if String(ch[0]) == "":
		Events.toast.emit(Loc.tx("Nothing left to read in %s.") % String(b["name"]))
		return
	_show_page(bid, idx, 1, ch)

func _show_page(bid: String, chapter_idx: int, page: int, ch: Array) -> void:
	var b: Dictionary = Library.BOOKS[bid]
	var panel: GamePanel = GamePanel.new().build(
		"%s — %d/%d" % [String(b["name"]), chapter_idx + 1, int(b["chapters"])],
		Vector2(980, 640))
	$UI.add_child(panel)
	panel.add_text(String(ch[0]), 24, Color(1, 0.92, 0.6))
	panel.add_text("")
	panel.add_text(String(ch[page]), 19, Color(0.96, 0.96, 0.98))
	panel.add_text("")
	panel.add_text("page %d of 2" % page, 17, Color(1, 1, 1, 0.45))

	if page < 2:
		panel.add_button(Loc.tx("Turn the page  ▶"), func():
			panel.close()
			_show_page(bid, chapter_idx, page + 1, ch), true)
		panel.add_button(Loc.tx("Put it down"), func(): panel.close())
	else:
		var already: bool = Library.is_finished(bid) \
			or Library.progress(bid) > chapter_idx
		if already:
			panel.add_button(Loc.tx("Close"), func(): panel.close(), true)
		else:
			panel.add_button(Loc.tx("Finish the chapter  (%d min)") % int(b["minutes"]),
				func():
					var msg: String = Library.read_chapter(bid)
					Events.toast.emit(msg)
					panel.close()
					_build(), true)
			panel.add_button(Loc.tx("Stop here (no progress)"), func(): panel.close())
