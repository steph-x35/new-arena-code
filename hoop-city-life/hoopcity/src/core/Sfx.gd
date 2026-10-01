extends Node
## Central audio: one-shot SFX pool, reactive crowd bed and looping music.
## Autoloaded as `Sfx`. Every sound in the game is procedural (assets/sfx),
## so there are no licensing dependencies. Volumes follow the Settings sliders.

const SFX_DIR := "res://assets/sfx/"
const POOL_SIZE := 18

## Every one-shot in the game. Kept as an explicit list so the export packer
## always includes them (see _ready).
const SFX_NAMES := [
	"backboard", "beep", "block", "body", "bounce1", "bounce2", "bounce3",
	"buzzer", "crossover", "crowd_amb",
	"defeat", "dunk", "go", "music_loop", "rim",
	"shot_release", "squeak1", "squeak2", "squeak3", "steal", "swish", "traffic_loop", "ui_tap",
	"victory", "whistle", "whistle_short", "music_jazz", "music_lounge", "music_jazz2", "court_amb", "music_rhythm",
	"rain_loop", "crowd_whistle", "crowd_cheer", "crowd_cheer2", "crowd_ooh",
	"voice_defense", "voice_ball", "voice_shoot", "voice_pass",
	"voice_rebound", "voice_nice",
]

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _bounce_i := 0

var crowd: AudioStreamPlayer
var music: AudioStreamPlayer
var amb: AudioStreamPlayer
var ambient: AudioStreamPlayer        # traffic bed (city), dedicated loop
var rain: AudioStreamPlayer           # gentle rain bed (city, when wet)
var _hype := 0.0
var _crowd_vol := -1.0
var match_live := false               # true during a real game: crowd chaos
var _chaos_t := 0.0
var _squeak_cd := 0.0
var _duck_t := 0.0             # crowd dips under player voices
var life_want := false           # jazz bed wanted: watchdog restarts it
var _crowd_base_db := 0.0        # crowd bus level from settings (duck offsets it)
var _vpool := []                 # dedicated voice players on the Voice bus

func _ready() -> void:
	# Bus 0 is Master; add dedicated buses so SFX/music fade independently.
	for b in ["SFX", "Music", "Crowd", "Voice"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	crowd = AudioStreamPlayer.new()
	crowd.bus = "Crowd"
	add_child(crowd)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	ambient = AudioStreamPlayer.new()
	ambient.bus = "SFX"
	add_child(ambient)
	rain = AudioStreamPlayer.new()
	rain.bus = "SFX"
	add_child(rain)
	for i in 4:
		var vp := AudioStreamPlayer.new()
		vp.bus = "Voice"
		add_child(vp)
		_vpool.append(vp)
	# Load everything up front (the set is ~1.3 MB).
	# EXPLICIT list, not a DirAccess sweep: inside an exported .pck the
	# original .wav sources are not listed as files (only their imported
	# .sample remaps are), so the directory scan found nothing on Android and
	# every Sfx.play() became a silent no-op -- the "no audio at all" bug.
	for n in SFX_NAMES:
		var s = load(SFX_DIR + n + ".wav") as AudioStreamWAV
		if s:
			_streams[n] = s
		else:
			push_warning("Sfx: missing stream " + n)
	# Garanzia di LOOP a runtime, qualunque sia lo stato dell'import: questi
	# suoni devono girare all'infinito (pioggia, lounge, jazz, folla).
	for n in ["traffic_loop", "rain_loop", "music_lounge", "music_jazz", "music_jazz2", "crowd_amb", "court_amb", "music_rhythm"]:
		var s: AudioStreamWAV = _streams.get(n)
		if s != null and s.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			# PCM 16-bit: 2 byte/frame; ADPCM: 4 bit/campione -> 2 frame/byte
			s.loop_end = s.data.size() * 2 if s.format == AudioStreamWAV.FORMAT_IMA_ADPCM \
				else s.data.size() / 2
	apply_settings()

func apply_settings() -> void:
	var sfx_v: float = float(Settings.get_v("sfx", 1.0))
	var mus_v: float = float(Settings.get_v("music", 0.7))
	var voice_v: float = float(Settings.get_v("voice", 1.0))
	var crowd_v: float = float(Settings.get_v("crowd", 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_v, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(mus_v, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(voice_v, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), sfx_v <= 0.001)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), mus_v <= 0.001)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Voice"), voice_v <= 0.001)
	_crowd_base_db = linear_to_db(maxf(crowd_v, 0.0001))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Crowd"), _crowd_base_db)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Crowd"), crowd_v <= 0.001)

## Micro-vibrazione aptica per mobile (safe e silenziosa su desktop/web)
func haptic(ms: int = 25) -> void:
	if Settings != null and Settings.has_method("is_vibration_enabled"):
		if not Settings.is_vibration_enabled():
			return
	Input.vibrate_handheld(ms)

# ---------------------------------------------------------------- one-shots
# Per-asset mix trims (dB), measured off each WAV's RMS so the whole set sits
# at one perceived loudness: shouts over the parquet, refs over the shouts.
const MIX := {
	# Chiamate di campo regenerate (v2.1.1, sintesi formantica) e Mixate basse.
	"voice_defense": -2.0, "voice_nice": -2.0, "voice_ball": -2.0,
	"voice_shoot": -2.0, "voice_pass": -2.0, "voice_rebound": -2.0,
	"squeak1": -1.0, "squeak2": -1.0, "squeak3": -1.0, "bounce1": 0.5, "bounce2": 0.5, "bounce3": 0.5,
	"whistle": -2.0, "whistle_short": -2.0, "buzzer": -3.0, "beep": -1.0,
}

func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	_play_impl(_pool, name, volume_db, pitch)

func _play_impl(pool: Array, name: String, volume_db: float, pitch: float) -> void:
	var s: AudioStreamWAV = _streams.get(name)
	if s == null:
		return
	var p: AudioStreamPlayer = pool[0]
	pool.pop_front()
	pool.append(p)
	p.stream = s
	p.volume_db = volume_db + MIX.get(name, 0.0)
	p.pitch_scale = clampf(pitch, 0.25, 3.0)
	p.play()

## Dribble thud; cycles three near-identical takes so repeated bounces do not
## phase into a machine-gun effect. Pitch nudges with ball speed/height.
## Il palleggio suona SEMPRE identico: stesso campione, stessa altezza.
## (La rotazione bounce1/2/3 resta per i rimbalzi liberi a terra.)
func dribble_thud() -> void:
	# Da solo resta DELICATO a -13.5. Sopra il pubblico (scrimmage/partite)
	# il file utente guadagna 2 dB: prima il letto della folla lo copriva
	# del tutto (-6..-8 dB del letto vs -13 dB del palleggio).
	# In partita il thud sale sopra il letto di folla (stesso suono
	# delicato dei court solo, qui +4.5 dB per restare udibile).
	play("bounce1", -9.0 if crowd.playing else -13.5, 1.0)

func bounce(pitch := 1.0) -> void:
	var n: String = "bounce%d" % (1 + (_bounce_i % 3))
	_bounce_i += 1
	play(n, 0.0, clampf(pitch, 0.95, 1.07))

# ------------------------------------------------------------------- crowd
func start_crowd() -> void:
	if crowd.stream == null:
		# Gli spalti aspettano la registrazione utente giusta (caos di folla,
		# condivisibile via chat o Drive): finche' non arriva suona il corto
		# loop Mixkit. court_amb (60s) e' SOLO ambiente del court outdoor,
		# NON gli spalti — correzione 2.8.2.
		if FileAccess.file_exists(SFX_DIR + "crowd_user.wav"):
			var mine: AudioStreamWAV = load(SFX_DIR + "crowd_user.wav") as AudioStreamWAV
			if mine != null:
				var st: AudioStreamWAV = mine.duplicate()
				st.loop_mode = AudioStreamWAV.LOOP_FORWARD
				st.loop_begin = 0
				st.loop_end = int(st.get_length() * float(st.mix_rate))
				crowd.stream = st
		if crowd.stream == null:
			crowd.stream = _streams.get("crowd_amb")
		_crowd_vol = -14.0
		crowd.volume_db = -14.0
		crowd.play()
		set_hype(0.0)

func stop_crowd() -> void:
	if crowd.playing:
		crowd.stop()
	_hype = 0.0

## Ambiente del court ESTERNO (registrazione dell'utente): player dedicato,
## non puo' essere rubato dal pool dei one-shot.
func start_amb() -> void:
	if amb == null:
		amb = AudioStreamPlayer.new()
		amb.bus = "SFX"
		add_child(amb)
	if amb.stream == null or not amb.playing:
		amb.stream = _streams.get("court_amb")
		amb.volume_db = -9.0
		amb.play()

func stop_amb() -> void:
	if amb != null and amb.playing:
		amb.stop()

## 0..1 excitement. The bed swells; big moments call cheer() on top.
func set_hype(v: float) -> void:
	_hype = clampf(v, 0.0, 1.0)

func add_hype(v: float) -> void:
	set_hype(_hype + v)

## CAOS ARENA (richiesta 2.16): il letto di folla (registrazione utente)
## e' la base, e sui momenti caldi tornano i CAMPIONI di tifo sopra:
## canestro = cheer, occorrimento/fallo = ooh, subito udibili sul letto.
func cheer(big := false) -> void:
	set_hype(1.0 if big else 0.75)
	if match_live:
		if big:
			play("crowd_cheer2", -3.0, randf_range(0.96, 1.05))
			if randf() < 0.35:
				play("crowd_whistle", -8.0, randf_range(0.9, 1.1))
		else:
			play("crowd_cheer", -6.0, randf_range(0.96, 1.05))

func ooh() -> void:
	set_hype(maxf(_hype, 0.6))
	if match_live:
		play("crowd_ooh", -7.0, randf_range(0.95, 1.06))

func _process(delta: float) -> void:
	_squeak_cd = maxf(0.0, _squeak_cd - delta)
	if _duck_t > 0.0:
		_duck_t -= delta
		if _duck_t <= 0.0:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Crowd"), _crowd_base_db)
	if life_want and music.stream != null and not music.playing:
		music.play()   # watchdog: the jazz bed never dies mid-stroll
	if crowd.playing:
		# Hype relaxes on its own; the bed volume tracks it smoothly.
		_hype = maxf(0.0, _hype - delta * 0.22)
		# A real arena never shuts up: the bed sits louder and the chaos
		# swells keep coming for the WHOLE game, not only after big plays.
		# CAOS ARENA (richiesta 2.16): il letto del match torna ALTO come
		# una volta: gli spalti devono sentirsi in 1v1 e scrimmage. Il
		# palleggio resta udibile perche' e' un transiente sopra il letto.
		var target: float = lerpf(-11.0, -4.0, _hype) if match_live else lerpf(-12.0, -6.0, _hype)
		_crowd_vol = lerpf(_crowd_vol, target, clampf(delta * 6.0, 0.0, 1.0))
		crowd.volume_db = _crowd_vol
		# Respiro organico: micro-variazioni lente di tono e volume cosi' il
		# loop non suona mai identico a se stesso.
		var now_s: float = Time.get_ticks_msec() / 1000.0
		var wave: float = sin(now_s * 0.13) * 0.018 + sin(now_s * 0.047) * 0.012
		crowd.pitch_scale = lerpf(0.985, 1.045, _hype) + wave
		crowd.volume_db = _crowd_vol + sin(now_s * 0.09) * 1.6
		if match_live:
			# Living crowd: unscripted swells of chatter/cheers so the arena
			# never feels like a static loop during a game.
			_chaos_t -= delta
			if _chaos_t <= 0.0:
				_chaos_t = randf_range(1.1, 2.9) * lerpf(1.0, 0.60, _hype)
				# respiro della folla: solo volume del letto, zero campioni extra
				_hype = minf(_hype + randf_range(0.06, 0.20), 1.0)

# ----------------------------------------------------------------- ambient
## City street bed: RIMOSSO dal mix su richiesta — la citta' suona solo
## jazz (+ pioggia quando piove). La funzione resta come no-op per non
## toccare tutti i call site.
func start_traffic() -> void:
	pass

## Pioggia leggera: solo quando il meteo e' "rain", molto sotto ogni musica.
func start_rain() -> void:
	if rain.playing:
		return
	rain.stream = _streams.get("rain_loop")
	rain.volume_db = -26.0        # delicata: un velo, non un temporale
	rain.play()

func stop_rain() -> void:
	if rain.playing:
		rain.stop()

func stop_traffic() -> void:
	if ambient.playing:
		ambient.stop()

# ------------------------------------------------------------------- music
func play_music(name := "music_loop") -> void:
	var s: AudioStreamWAV = _streams.get(name)
	if s == null or (music.stream == s and music.playing):
		return
	music.stream = s
	# Il lounge vuole sentirsi: bar vivo, non sottofondo da ascensore.
	music.volume_db = -6.5 if name == "music_lounge" else -11.0
	music.play()

func stop_music() -> void:
	life_want = false
	if music.playing:
		music.stop()

## Fixture arenas get the jazz trio as a low bed UNDER the crowd; 1v1 and
## scrimmage stay music-free, as do the solo courts.
func court_jazz(on: bool) -> void:
	if not on:
		stop_music()
		return
	life_want = true
	var s: AudioStreamWAV = _streams.get("music_jazz")
	if s == null:
		return
	if music.stream != s:
		music.stream = s
	if not music.playing:
		music.volume_db = -16.0
		music.play()
	else:
		music.volume_db = -16.0

## The lounge loop: a slow 70 bpm chill jazz bar (walking bass, Rhodes,
## brushes, vibes). Every life-sim screen -- city streets and every building
## -- never on the courts, where parquet sounds rule.
var _life_pick := 0
func play_life() -> void:
	life_want = true
	# Alterna i due lounge a ogni ingresso in scena: niente monotonia.
	_life_pick = (_life_pick + 1) % 2
	play_music("music_lounge" if _life_pick == 0 else "music_jazz2")

## Sneaker stop on parquet, rate limited so stops never machine-gun.
var _sq_i := 0
func squeak() -> void:
	# I TRE STRIDORI REALI dell'utente (shoes squeak.mp3): rotazione con
	# pitch leggermente variabile, resta raro e discreto come da regola.
	if _squeak_cd > 0.0:
		return
	_squeak_cd = 0.32
	_sq_i += 1
	play("squeak%d" % (1 + (_sq_i % 3)), -2.0, randf_range(0.95, 1.12))

## On-court shout from a team-mate ("defense", "ball", ...). Loaded only when
## the voice clips exist; a silent no-op otherwise (solo courts never call it).
func voice(id: String, volume_db := 0.0) -> void:
	_play_impl(_vpool, "voice_" + id, volume_db, randf_range(0.90, 1.04))
	# dip the crowd bed so the shout reads clearly over the arena
	_duck_t = 0.7
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Crowd"), _crowd_base_db - 6.0)

func set_match_live(v: bool) -> void:
	match_live = v
	if not v:
		_chaos_t = 0.0
