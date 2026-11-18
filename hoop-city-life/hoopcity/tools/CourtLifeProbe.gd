extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	var post := {"author": "@test", "text": "Game", "likes": 12, "comments": []}
	Game.toggle_social_like(post)
	var ok: bool = post["likes"] == 13 and post["liked_by_player"]
	Game.toggle_social_like(post)
	ok = ok and post["likes"] == 12 and not post["liked_by_player"]
	Game.comment_social_post(post, "Thanks!")
	ok = ok and post["comments"].size() == 1 and post["comments"][0]["text"] == "Thanks!"
	ok = ok and Season.arena_of("Riverside Ravens") == "Hoop City Arena"
	Career._social_reaction(25, true, "A", 0.8)
	var authors: Array = []
	for p in Game.profile["social"]: authors.append(p["author"])
	ok = ok and "@DeeWhitlock" in authors and "@MayaCourtSide" in authors and "@LegendMalikStone" in authors
	var player := BallPlayer.new()
	player.ratings = {"athleticism": 60, "block": 60}
	ok = ok and BallPlayer.JUMP_V < 900.0
	player.free()
	print("COURT_LIFE_OK=", ok)
	get_tree().quit(0 if ok else 1)
