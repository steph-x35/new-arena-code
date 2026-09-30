extends Node
## Phone contact book + conversation threads. Autoloaded as `Contacts`.
##
## Messages are per-contact threads (like a real chat app) rather than one flat
## inbox. Each thread is an Array of {"who": "them"|"me", "text", "day", "time"}.
##
## Contacts react to how the career is going: the coach's tone depends on your
## last game grade, mum asks if you are eating, your agent only calls when your
## reputation is high enough. Replies are chosen from the contact's reply table
## so a conversation always feels answered, never a dead end.

const COACH := "coach_ellis"
const MUM := "mum"
const DAD := "dad"
const SIS := "sister"
const BEST := "marcus"
const TEAMMATE := "dee"
const AGENT := "agent"

## `unlock_rep`: hidden until reputation reaches it.
const PEOPLE := {
	COACH: {
		"name": "Coach Ellis", "role": "Head Coach - Riverside",
		"col": Color(0.42, 0.66, 0.98), "avatar": "CE", "unlock_rep": 0,
	},
	MUM: {
		"name": "Mum", "role": "Family",
		"col": Color(0.96, 0.55, 0.68), "avatar": "M", "unlock_rep": 0,
	},
	DAD: {
		"name": "Dad", "role": "Family",
		"col": Color(0.55, 0.72, 0.52), "avatar": "D", "unlock_rep": 0,
	},
	SIS: {
		"name": "Nia (sister)", "role": "Family",
		"col": Color(0.85, 0.58, 0.95), "avatar": "N", "unlock_rep": 0,
	},
	BEST: {
		"name": "Marcus", "role": "Best friend since 3rd grade",
		"col": Color(0.98, 0.72, 0.35), "avatar": "MJ", "unlock_rep": 0,
	},
	TEAMMATE: {
		"name": "Dee Whitlock", "role": "Teammate - PG",
		"col": Color(0.45, 0.88, 0.78), "avatar": "DW", "unlock_rep": 0,
	},
	AGENT: {
		"name": "Rosa Vance", "role": "Agent",
		"col": Color(0.90, 0.85, 0.40), "avatar": "RV", "unlock_rep": 35,
	},
}

## Player reply options per contact: {label, reply}. `reply` is what they answer.
const REPLIES := {
	COACH: [
		{"label": "I'll be there early.", "reply": "Good. Bring the same energy you had in the gym."},
		{"label": "What should I work on?", "reply": "Your %s. Get to the gym and drill it."},
		{"label": "Rough night, sorry.", "reply": "Every pro has them. Shake it and get back to work."},
	],
	MUM: [
		{"label": "I'm eating properly, promise.", "reply": "Mhm. Send me a photo of the fridge then."},
		{"label": "Miss you.", "reply": "Miss you more. Your room is exactly how you left it."},
		{"label": "Watched the game?", "reply": "Every second. I shouted so loud the neighbour knocked."},
	],
	DAD: [
		{"label": "Saw my shot chart?", "reply": "I did. Feet were sloppy on the second one. Fix the base."},
		{"label": "Coming to the next one?", "reply": "Front row. I'll be the loud one in the old jacket."},
		{"label": "Thanks for the drills, dad.", "reply": "Driveway hours. They always show up eventually."},
	],
	SIS: [
		{"label": "How's school?", "reply": "Boring. Everyone asks about you though, it's weird."},
		{"label": "Want tickets?", "reply": "YES. Bring two, I'm bringing Amira."},
		{"label": "Stop posting about me 😅", "reply": "Never. You're my whole personality now."},
	],
	BEST: [
		{"label": "Run it back tomorrow?", "reply": "Court at 9. Loser buys food, same as always."},
		{"label": "Can't, training.", "reply": "Look at you being professional. Respect. Go get it."},
		{"label": "You watching?", "reply": "Bro I've got the stream on two devices."},
	],
	TEAMMATE: [
		{"label": "Good look on that pass.", "reply": "Keep cutting like that and I'll find you every time."},
		{"label": "Extra shots after practice?", "reply": "Say less. I'll rebound for you, you rebound for me."},
		{"label": "We'll get them next game.", "reply": "Facts. Watch the film tonight, they hedge hard."},
	],
	AGENT: [
		{"label": "What's on the table?", "reply": "Two shoe brands are curious. Keep the grades up."},
		{"label": "I want more minutes.", "reply": "Then give me a highlight I can send. Simple as that."},
		{"label": "Thanks Rosa.", "reply": "Just do your job and I'll do mine."},
	],
}

func _ready() -> void:
	Events.day_advanced.connect(_on_day)

# ------------------------------------------------------------------ storage
func threads() -> Dictionary:
	if not Game.profile.has("threads"):
		Game.profile["threads"] = {}
	return Game.profile["threads"]

func thread(cid: String) -> Array:
	var t: Dictionary = threads()
	if not t.has(cid):
		t[cid] = []
	return t[cid]

func unlocked(cid: String) -> bool:
	return int(Game.profile.get("rep", 0)) >= int(PEOPLE[cid]["unlock_rep"])

func contact_ids() -> Array:
	var out := []
	for cid in PEOPLE:
		if unlocked(cid):
			out.append(cid)
	# Most recently active conversation first, like a real messages app.
	out.sort_custom(func(a, b): return _last_stamp(a) > _last_stamp(b))
	return out

func _last_stamp(cid: String) -> int:
	var t: Array = thread(cid)
	if t.is_empty():
		return -1
	var m: Dictionary = t[t.size() - 1]
	return int(m.get("day", 0)) * 1440 + _mins(String(m.get("time", "00:00")))

func _mins(hhmm: String) -> int:
	var parts := hhmm.split(":")
	if parts.size() != 2:
		return 0
	return int(parts[0]) * 60 + int(parts[1])

func unread(cid: String) -> int:
	var n := 0
	for m in thread(cid):
		if String(m.get("who", "them")) == "them" and not bool(m.get("read", false)):
			n += 1
	return n

func total_unread() -> int:
	var n := 0
	for cid in contact_ids():
		n += unread(cid)
	return n

func mark_read(cid: String) -> void:
	for m in thread(cid):
		m["read"] = true

# ------------------------------------------------------------------ sending
func receive(cid: String, text: String) -> void:
	if not PEOPLE.has(cid):
		return
	thread(cid).append({
		"who": "them", "text": text,
		"day": Game.profile["day"], "time": Game.clock_string(), "read": false,
	})
	Game.push_notification("Messages", String(PEOPLE[cid]["name"]), text)
	Events.phone_thread_changed.emit(cid)

func send(cid: String, text: String) -> void:
	thread(cid).append({
		"who": "me", "text": text,
		"day": Game.profile["day"], "time": Game.clock_string(), "read": true,
	})
	Events.phone_thread_changed.emit(cid)

func reply_options(cid: String) -> Array:
	var out := []
	for r in REPLIES.get(cid, []):
		var reply: String = String(r["reply"])
		if reply.contains("%s"):
			reply = reply % _weakest_attr()
		out.append({"label": String(r["label"]), "reply": reply})
	return out

func _weakest_attr() -> String:
	var worst := ""
	var worst_v := 999
	for a in Game.ATTRS:
		if Game.attr(a) < worst_v:
			worst_v = Game.attr(a)
			worst = a
	return worst.capitalize().to_lower()

# ------------------------------------------------------------------ reactive
func on_game_played(pts: int, grade: String, won: bool) -> void:
	## Called by Career after a match. Different people react differently.
	var top := grade.begins_with("A")
	if top:
		receive(COACH, "That's the standard now. %d points and you controlled the tempo." % pts)
		receive(MUM, "I don't understand the rules but I understand %d points. So proud." % pts)
		receive(BEST, "%d?! I was screaming at my screen bro 😭🔥" % pts)
		if int(Game.profile.get("rep", 0)) >= 35:
			receive(AGENT, "Two brands messaged me during the 4th quarter. Keep this up.")
	elif grade == "F" or grade == "D":
		receive(COACH, "Not our night. Gym tomorrow, we fix the rhythm early.")
		receive(DAD, "Head up. Your release was rushing. Slow feet, quick hands.")
	else:
		receive(TEAMMATE, "Decent work out there. Film session tonight?")
	if won:
		receive(SIS, "WE WON!! Everyone at school is going to hear about this 😤")

func on_drill(kind: String, grade: String) -> void:
	if grade.begins_with("A"):
		receive(COACH, "Saw your %s numbers. That's the work nobody claps for." % kind)

func _on_day(_d: int) -> void:
	## A little life so the inbox is never static.
	var day: int = int(Game.profile.get("day", 1))
	if day % 4 == 0:
		receive(MUM, "Are you sleeping enough? Be honest with me.")
	elif day % 4 == 2:
		receive(BEST, "Court later? Bring the good ball, yours is bald.")
	elif day % 5 == 3:
		receive(TEAMMATE, "Coach added a new set. Come early and I'll walk you through it.")

func seed_intro() -> void:
	## First messages a new career starts with.
	receive(COACH, "Welcome to Riverside. Practice at the Team Court, game nights at the Arena.")
	receive(MUM, "Your first day! I put a little money in your account. Eat something warm.")
	receive(BEST, "Yooo you actually did it. Proud of you man. Don't forget the day ones 🏀")
