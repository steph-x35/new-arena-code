extends RefCounted
class_name BookText
## The actual text of every book on sale. Each chapter is two short pages of
## original writing about the game -- no licensed names, no real players.
## Reading is a real activity, so there has to be something real to read.

const PAGES := {
"footwork": [
	["Chapter one — The floor is the first skill",
	 "Before the ball, before the shot, before anything anyone will ever put on a highlight reel, there is the floor. You are standing on it. Most players never think about that again.\n\nWatch a good guard come off a screen. The upper body looks calm, almost lazy. Everything urgent is happening below the knees: a short chop step, a heel that never quite lands, weight already leaning where he intends to go before he has decided to go there.\n\nThat is not talent. That is ten thousand repetitions of a boring drill.",
	 "The drill is this. Stand still. Bend your knees until your thighs complain, then hold it while you count to thirty. Your instinct will be to rise. Do not rise.\n\nA low base is not a posture, it is a loaded spring. From low you can go in any direction without a preparatory movement, and it is the preparatory movement that a defender reads. When people say a player is quick, they usually mean he skipped a step everyone else takes."],
	["Chapter two — Landing",
	 "Everybody practises jumping. Almost nobody practises landing, which is strange, because you will do exactly as many of one as the other, and only one of them ends careers.\n\nLand on the balls of your feet, knees soft, hips back. Absorb the impact through the whole chain instead of letting your kneecap take it. If you can hear yourself land from across the gym, you are doing it wrong.",
	 "There is a second reason to land well, and it is not about injury. A soft landing is a fast second jump.\n\nRebounding is rarely won in the air. It is won by the player who gets back off the floor first, because the ball is very often still up there. Stiff landing, two-tenths lost, ball gone. Soft landing, and you are already rising while the other four are still admiring the flight."],
	["Chapter three — The pivot nobody uses",
	 "The reverse pivot is the least fashionable move in basketball and one of the most useful. You catch with your back to the rim, the defender leans in, and instead of fighting that pressure you spin away from it and let him fall into the space you just left.\n\nIt works because defenders are trained to push. Give them nothing to push against.",
	 "Practise it against a wall. Catch, pivot, face up, all in one motion, a hundred times a side. It will feel pointless for about a week.\n\nThen one evening a defender will lean on you and you will find yourself facing the basket with no idea how you got there, and you will understand what the hundred repetitions were for. That is how footwork arrives: not as a decision, but as a thing you have already done."]],

"quiet_mind": [
	["Chapter one — The line is very quiet",
	 "The free-throw line is the loneliest fifteen feet in sport. Nothing is moving. Nobody is guarding you. You have done this shot more times than you can count, and yet the arena has never felt louder.\n\nHere is the uncomfortable truth: the noise is not the problem. The problem is that with nothing to react to, you are left alone with your own attention, and untrained attention is a poor companion.",
	 "So give it a job. A routine is not superstition; it is a series of small, boring tasks that occupy the part of your mind that would otherwise be composing a speech about what happens if you miss.\n\nThree dribbles. Spin the ball. Find the nail on the floor. Breathe out. The routine is identical whether it is a Tuesday practice or the last shot of the season. That sameness is the entire point."],
	["Chapter two — Pressure is only attention",
	 "Pressure is not a force. Nothing is pressing on you. Pressure is the sensation of many people paying attention at once, and attention only becomes heavy when you try to carry it.\n\nThe players who look calm are not feeling less. They have simply stopped trying to hold all of it.",
	 "One method that works: narrow your world to something small and physical. The seam of the ball under your index finger. The exact texture of the line under your shoe.\n\nYou cannot think about twenty thousand people and a ball seam at the same time. The mind is single-threaded when you force it to be. Choose the smaller thread."],
	["Chapter three — Missing well",
	 "You will miss. This is not pessimism, it is arithmetic: nobody shoots a hundred percent, and the better your shot selection the more often you take hard ones.\n\nWhat separates players is not whether they miss but what the next ninety seconds look like.",
	 "The rule is simple and almost impossible: the miss ends when the ball hits the floor. Not when you have finished being annoyed about it.\n\nGive yourself one breath. Then the possession is over and a new one has started, and the new one does not know anything about the old one. Only you are carrying that."],
	["Chapter four — The last shot",
	 "Late in a close game something strange happens to time. The play you have run a thousand times feels unfamiliar. Your own hands feel borrowed.\n\nThis is normal, and knowing it is normal is most of the cure.",
	 "The shot you take at the end should be a shot you have taken ten thousand times before. Not a better one. Not a braver one.\n\nGreat closers are not more heroic than everyone else. They are more repetitive. When the moment arrives they do not reach for something extra; they do the ordinary thing, extremely well, while everybody else is reaching."]],

"read_defence": [
	["Chapter one — The trap forms before it arrives",
	 "By the time you can see a double team, it is too late to pass out of it cleanly. The read has to happen a beat earlier, when it is still only an intention in somebody else's feet.\n\nWatch the man guarding the passer one step away from you. If his head turns toward the ball while his feet stay home, nothing is coming. If his feet start to drift, you have about half a second.",
	 "The most useful habit in basketball is looking at the defence rather than the ball.\n\nThis feels wrong at first — the ball is where the action obviously is. But everybody watches the ball. The information is somewhere else entirely: in the hips of the weak-side defender, in whether the big man's heels have left the paint."],
	["Chapter two — The pass that breaks it",
	 "When the trap does arrive, the instinct is to go over it with a high looping pass. That pass has been intercepted more times than any other in the history of the game.\n\nGo underneath. A hard bounce pass through the gap between two converging defenders is almost impossible to steal, because their hands are up and their momentum is forward.",
	 "Better still, do not be there. A trap needs a corner, a sideline, or a stationary target.\n\nOne step toward the middle of the floor before the catch, and the whole thing collapses before it starts. The best answer to a trap is geometry, applied slightly early."],
	["Chapter three — Two on one",
	 "A two-on-one is a free basket that players routinely waste, usually by passing too soon.\n\nThe defender is not guarding you. He is guarding the pass. Every stride you take without giving him the answer, he has to make a decision he does not want to make.",
	 "Attack the front foot. Go hard at the shoulder he is least able to turn, and hold the ball where he can see it.\n\nWhen he finally commits, the read makes itself. Pass if he steps to you, finish if he sags. The mistake is deciding in advance — then you are not reading anything, you are guessing early and calling it decisiveness."],
	["Chapter four — Talking",
	 "Defence is the only part of the game that is genuinely impossible in silence.\n\nA switch that is not called is not a switch, it is two players guarding the same man while a third stands alone in the corner, entirely unmarked, watching it happen.",
	 "Use short words. Ball. Screen left. Help. Back.\n\nA team that talks badly still beats a team that does not talk, and a team that talks well can defend perfectly adequately with five limited athletes. This is the cheapest improvement available to any player, and almost nobody does it."]],

"iron_hours": [
	["Chapter one — Six in the morning",
	 "Nobody is watching at six in the morning. That is the point, and it is also the difficulty.\n\nThe weight room at that hour is unglamorous: fluorescent light, a radio nobody chose, the particular smell of rubber matting. There is no crowd, no scoreboard, and no possibility of anyone being impressed.",
	 "What you build in those hours does not show up for months. That delay is the reason most people stop.\n\nYou lift in November and you feel it in March, holding your position against a stronger player in the fourth quarter of a game you would previously have faded out of. The connection is real but invisible, which means you have to take it on trust for a very long time."],
	["Chapter two — Strong is not big",
	 "Young players lift to look like something. Older players lift to survive a season.\n\nThese produce different programmes. Mass you do not use is mass you carry up and down the floor two hundred times a night, and it will cost you more than it gives.",
	 "Train the movements the game asks for: hinge, squat, push, pull, carry, and above all deceleration.\n\nMost basketball injuries happen while stopping, not while going. The muscle that matters is the one that catches you at the end of a hard cut. Nobody has ever posted a photograph of that muscle."],
	["Chapter three — The season is the programme",
	 "In the off-season you build. In season you maintain, and maintaining is a skill of its own.\n\nThe temptation after a bad game is to punish yourself in the gym. This is almost always the wrong response. You are tired, your mechanics are already degraded, and adding load to a degraded pattern only teaches you the degraded pattern.",
	 "The honest programme is boring and it is written down in advance, so that a bad night cannot rewrite it.\n\nTwo hard sessions a week, kept short, kept precise. Sleep treated as a training input rather than a reward. Food eaten on time whether or not you feel like it. Everything unglamorous, and all of it decisive by February."]],

"handles": [
	["Chapter one — Stop looking",
	 "If you have to look at the ball, it is not yours yet.\n\nThe hand knows where the ball is by feel, or it does not know at all. Every glance downward is a moment you are not seeing the help defender arriving from your blind side.",
	 "The drill is unglamorous. Dribble in a corridor, at waist height, hard, while reading something on the wall.\n\nWhen you can do it without a single glance, lower the ball to your knee. Then do it with your weak hand until you hate it. Then do it for another week."],
	["Chapter two — Change of pace beats change of direction",
	 "Everybody practises crossovers. Fewer practise simply slowing down.\n\nA defender matches your speed. If you are always at maximum, he can settle there too. The moment you decelerate he must decide whether to stay with you or hold his ground, and either choice creates something.",
	 "The most effective sequence in the game is slow, slow, gone.\n\nIt requires patience, which is why it is rare — it looks like nothing is happening, right up until the moment it very much is."],
	["Chapter three — Protecting it",
	 "The ball should be on the far side of your body from the defender. Always. This sounds obvious and is violated constantly.\n\nYour off arm is not for pushing. It is a fence: forearm up, elbow bent, occupying the space he wants to reach through.",
	 "Combine that with a low dribble and you become genuinely difficult to strip, which changes how teams defend you.\n\nOnce they stop sending help at the first dribble, everything downstream gets easier — the pass, the shot, the entire offence. Handle is not a highlight skill. It is the thing that makes the other skills usable."]],

"the_long_game": [
	["Chapter one — Everyone peaks",
	 "Every player has a best season, and almost none of them know it while it is happening.\n\nThis is not a tragedy. It is simply the shape of a career: a long climb, a plateau that feels permanent while you are on it, and a descent that arrives sooner than the climb suggested it would.",
	 "The players who last are rarely the ones who peak highest. They are the ones who noticed the plateau early and started adding things.\n\nA jump shot at twenty-eight. Passing at thirty. Talking on defence at thirty-two. Each addition buys a season, sometimes two."],
	["Chapter two — The bench",
	 "Sooner or later you will sit. Everyone does, and almost everyone handles the first time badly.\n\nThe temptation is to treat it as a verdict on your worth. It is more usefully treated as information about a rotation — which is a thing made by a tired man with a whiteboard, not a judgement handed down by the sport itself.",
	 "There is a version of sitting that helps you and a version that eats you.\n\nThe useful version watches the game from a seat with a better view than you have ever had on the floor, and notices things. The other version rehearses grievances. Both feel equally justified at the time, and only one of them ends with you playing again."],
	["Chapter three — Money",
	 "The money arrives suddenly, if it arrives, and it is almost never explained to anyone beforehand.\n\nA career is short and the years afterwards are long. The arithmetic is unforgiving and completely public, yet it surprises people every single year.",
	 "The advice is dull because the truth is dull. Spend less than you earn. Assume the current contract is the last one.\n\nNobody has ever regretted being boring with money. A striking number of people have regretted the opposite, usually in interviews given a long time after the last game."],
	["Chapter four — What it was for",
	 "At some point you will play your final competitive game, and you will probably not know at the time that it is the final one.\n\nThere is rarely a ceremony. More often there is a Tuesday, a minor injury, and a phone that stops ringing.",
	 "What survives is not the statistics. Ask anyone who has finished.\n\nWhat survives is a specific bus journey, a teammate who made everyone laugh in a losing dressing room, the particular sound of an empty gym at seven in the morning when the lights are still warming up. Play for those. They are the part you get to keep."]],
}

## Chapter `n` (0-based) of a book, as [title, page1, page2].
static func chapter(book_id: String, n: int) -> Array:
	var list: Array = PAGES.get(book_id, [])
	if n < 0 or n >= list.size():
		return ["", "", ""]
	return list[n]

## How many chapters actually have text written for them.
static func chapter_count(book_id: String) -> int:
	return PAGES.get(book_id, []).size()
