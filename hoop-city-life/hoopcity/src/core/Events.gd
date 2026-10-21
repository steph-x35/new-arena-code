extends Node
## Global event bus. Any system emits, any UI listens. Keeps scenes decoupled.

# --- Time / world ---
signal time_changed(day: int, minutes: int)      # minutes = 0..1439
signal day_advanced(day: int)
signal daypart_changed(part: String)             # morning/afternoon/evening/night

# --- Player vitals ---
signal energy_changed(value: float)
signal hunger_changed(value: float)
signal health_changed(value: float)
signal money_changed(value: int)
signal rep_changed(value: int)

# --- Progression ---
signal xp_gained(amount: int, source: String)
signal attribute_up(attr: String, value: int)
signal badge_unlocked(badge_id: String)

# --- Match ---
signal score_changed(home: int, away: int)
signal possession_changed(team: int)
signal shot_taken(quality: String, made: bool, points: int)
signal match_finished(box_score: Dictionary)
signal toast(text: String)
signal quarter_ended(q: int)                     # between-quarters intermission
signal run_update(info: Dictionary)               # scoring run: {live, team, pts, q}
# Game-feel: camera shake (0..1 strength) and world-space floating text.
signal shake(amount: float)
signal popup(text: String, world_pos: Vector2, color: Color, big: bool)

# --- Phone / social ---
signal phone_notification(app: String, title: String, body: String)
signal social_post_added(post: Dictionary)
signal phone_thread_changed(contact_id: String)
signal followers_changed(value: int)
signal phone_app_opened(app: String)
