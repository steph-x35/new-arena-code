extends Node
## IT/EN localisation. Autoloaded as `Loc`, right after Settings.
##
## Two lookup styles:
##   Loc.t("menu.new")          -> key-based, for UI chrome we own
##   Loc.tx("BLOCKED by #4")    -> value-based, for gameplay callouts emitted
##                                 deep inside the sim (Court/AIBrain/Career).
##                                 Unknown strings pass through untouched, so
##                                 untranslated content degrades to English
##                                 instead of breaking.
## The language lives in Settings ("lang"), defaults to the device locale.

signal changed

var lang := "en"

# key -> [english, italian]
const STR := {
	"tagline":        ["Build your player. Walk the city. Live the game.",
	                   "Crea il tuo giocatore. Vivi la città. Vivi il gioco."],
	"menu.continue":  ["CONTINUE CAREER", "CONTINUA LA CARRIERA"],
	"menu.new":       ["NEW CAREER", "NUOVA CARRIERA"],
	"menu.quick":     ["QUICK EXHIBITION", "ESIBIZIONE RAPIDA"],
	"menu.settings":  ["SETTINGS", "IMPOSTAZIONI"],
	"menu.quit":      ["QUIT", "ESCI"],
	"intro.skip":     ["TAP TO SKIP", "TOCCA PER SALTARE"],
	"common.back":    ["BACK", "INDIETRO"],
	"settings.title": ["Settings", "Impostazioni"],
	"settings.display": ["DISPLAY", "SCHERMO"],
	"settings.controls": ["CONTROLS", "COMANDI"],
	"settings.audio": ["AUDIO", "AUDIO"],
	"settings.save":  ["SAVE", "SALVATAGGIO"],
	"settings.fps":   ["Target 60 FPS", "Target 60 FPS"],
	"settings.meter": ["Show shot meter", "Mostra indicatore di tiro"],
	"settings.left":  ["Left-handed buttons", "Pulsanti per mancini"],
	"settings.stick": ["Joystick sensitivity", "Sensibilità joystick"],
	"settings.vibration": ["Vibration feedback", "Feedback vibrazione"],
	"settings.sfx":   ["Sound effects", "Effetti sonori"],
	"settings.music": ["Music", "Musica"],
	"settings.lang":  ["Language", "Lingua"],
	"settings.del":   ["Delete career save", "Elimina il salvataggio"],
	"settings.deleted": ["Save deleted", "Salvataggio eliminato"],
	"status.day":     ["Day", "Giorno"],
	"match.shoot":    ["SHOOT", "TIRA"],
	"match.dunk":     ["DUNK", "SCHIACCIA"],
	"match.trick":    ["TRICK", "FINTA"],
	"match.pass":     ["PASS", "PASSA"],
	"match.pnr":      ["P&R", "BLOCCO"],
	"match.post":     ["POST", "POST"],
	"match.jump":     ["JUMP", "SALTA"],
	"match.steal":    ["STEAL", "RUBA"],
	"match.defend":   ["DEFEND", "DIFENDI"],
	"match.check":    ["CHECK", "CHECK"],
	"match.exit":     ["EXIT", "ESCI"],
	"match.timeout":  ["TIMEOUT", "TIMEOUT"],
	"match.bench.title": ["ON THE BENCH", "IN PANCHINA"],
	"match.bench.sub":   ["Earn your minutes back", "Guadagnati di nuovo i minuti"],
	"match.bench.watch": ["WATCH", "GUARDA"],
	"match.bench.sim":   ["SIM TO RETURN", "SIMULA FINO AL RIENTRO"],
	"callout.coach.tired": ["Coach: you are running on fumes -- rest!",
	                        "Coach: hai finito la benzina -- rifiata!"],
	"callout.coach.bench": ["Coach: to the bench! Make an impact out there",
	                        "Coach: in panchina! Serve più impatto"],
	"callout.coach.back":  ["Coach: you are back in -- make it count!",
	                        "Coach: si rientra -- falla contare!"],
	"match.len.title": ["QUARTER LENGTH", "DURATA QUARTI"],
	"callout.coach.rest": ["Coach: planned rest -- to the bench",
	                       "Coach: riposo programmato -- in panchina"],
	"callout.coach.goin": ["Coach: back in, go get them!",
	                       "Coach: si torna in campo, prendili!"],
	"callout.no.timeouts": ["No timeouts left!", "Timeout esauriti!"],
	"callout.timeouts.left": ["%d left", "ne restano %d"],
	"sweep.0": ["Nothing left to read in %s.", "Niente più da leggere in %s."],
	"sweep.1": ["Take it down", "Staccalo"],
	"sweep.2": ["Hang this one", "Appendi questo"],
	"sweep.3": ["Buy it", "Compralo"],
	"sweep.4": ["Not now", "Non ora"],
	"sweep.5": ["Read it (on your shelf)", "Leggilo (sulla tua mensola)"],
	"sweep.6": ["Buy for %d$", "Compra a %d$"],
	"sweep.7": ["Put it back", "Rimetti a posto"],
	"sweep.8": ["Turn the page  \u25b6", "Gira pagina  ▶"],
	"sweep.9": ["Put it down", "Appoggialo"],
	"sweep.10": ["Close", "Chiudi"],
	"sweep.11": ["Finish the chapter  (%d min)", "Finisci il capitolo  (%d min)"],
	"sweep.12": ["Stop here (no progress)", "Fermati qui (nessun progresso)"],
	"sweep.13": ["%s\\n%s", "%s\\n%s"],
	"sweep.14": ["PAGE & PRINT", "CARTA & STAMPA"],
	"sweep.15": ["Posters for the wall, books for the head.", "Poster per la parete, libri per la testa."],
	"sweep.16": ["\u2713 ", "✓ "],
	"sweep.17": ["\ud83d\udcd6  ", "📖  "],
	"sweep.18": ["Not enough money", "Soldi insufficienti"],
	"sweep.19": ["Already own %s", "Hai già %s"],
	"sweep.20": ["%s bought \u00b7 placed in the second apartment", "%s comprato · piazzato nel secondo appartamento"],
	"sweep.21": ["Second floor: %s", "Secondo piano: %s"],
	"sweep.22": ["%d$", "%d$"],
	"sweep.23": ["HOME & HEARTH", "CASA & FOCOLARE"],
	"sweep.24": ["Furnish the second apartment. Buy a piece and it is placed there, ready to use.", "Arreda il secondo appartamento. Compri un pezzo e viene piazzato lì, pronto all'uso."],
	"sweep.25": ["bought", "comprato"],
	"sweep.26": ["not bought yet", "non ancora comprato"],
	"sweep.27": ["Adopt", "Adotta"],
	"sweep.28": ["< Leave", "< Esci"],
	"sweep.29": ["\ud83d\udc3e  Paws & Claws", "🐾  Zampe & Artigli"],
	"sweep.30": ["$%d", "$%d"],
	"sweep.31": ["$%d   \u00b7   food x%d", "$%d   ·   cibo x%d"],
	"sweep.32": ["No pets yet. An empty flat is a quiet flat.", "Ancora nessun pet. Una casa vuota è una casa silenziosa."],
	"sweep.33": ["Owned", "Posseduto"],
	"sweep.34": ["Buy", "Compra"],
	"sweep.35": ["Too dear", "Troppo caro"],
	"sweep.36": ["Bought  %s", "Comprato  %s"],
	"sweep.37": ["Back", "Indietro"],
	"sweep.38": ["Plunge  \u00b7  $%d", "Tuffo  ·  $%d"],
	"sweep.39": ["GO OUTSIDE", "ESCI FUORI"],
	"sweep.40": ["GEAR SHELF", "MENSOLA ATTREZZI"],
	"sweep.41": ["Home sweet home", "Casa dolce casa"],
	"sweep.42": ["Delivery arrived", "Consegna arrivata"],
	"sweep.43": ["Day %d \u00b7 woke at %s", "Giorno %d · sveglio alle %s"],
	"sweep.44": ["Slept until %s", "Hai dormito fino alle %s"],
	"sweep.45": ["Rested on the extra bed", "Riposo sul letto extra"],
	"sweep.46": ["Showered upstairs", "Doccia al piano di sopra"],
	"sweep.47": ["Sat down", "Ti sei seduto"],
	"sweep.48": ["Watched TV upstairs", "TV guardata al piano di sopra"],
	"sweep.49": ["Quiet workspace", "Postazione tranquilla"],
	"sweep.50": ["Second apartment unlocked", "Secondo appartamento sbloccato"],
	"sweep.51": ["You need 1000$", "Ti servono 1000$"],
	"sweep.52": ["Wearing %s", "Indossi %s"],
	"sweep.53": ["TV off", "TV spenta"],
	"sweep.54": ["Chilled out for an hour", "Un'ora di relax"],
	"sweep.55": ["Correct", "Corretto"],
	"sweep.56": ["Missed it -- that one was fine", "Sbagliato -- quella era giusta"],
	"sweep.57": ["Shower. %s  (+12 energy)", "Doccia. %s  (+12 energia)"],
	"sweep.58": ["Order a delivery (+3 basics, 25$)", "Ordina una consegna (+3 basi, 25$)"],
	"sweep.59": ["EAT IT", "MANGIALO"],
	"sweep.60": ["\ud83d\udca4  Until 07:00 \u00b7 %dh%02dm \u00b7 +%d", "💤  Fino alle 07:00 · %dh%02dm · +%d"],
	"sweep.61": ["Get up", "Alzati"],
	"sweep.62": ["Lie down (+8 energy)", "Sdraiati (+8 energia)"],
	"sweep.63": ["Shower (+12 energy)", "Doccia (+12 energia)"],
	"sweep.64": ["Sit a while (+5 energy)", "Siediti un po' (+5 energia)"],
	"sweep.65": ["Watch (+6 energy)", "Guarda (+6 energia)"],
	"sweep.66": ["Sit at the desk", "Siediti alla scrivania"],
	"sweep.67": ["BUY APARTMENT  \u00b7  1000$", "COMPRA APPARTAMENTO  ·  1000$"],
	"sweep.68": ["Watch for an hour (relax, +8 energy)", "Guarda per un'ora (relax, +8 energia)"],
	"sweep.69": ["Feed %s", "Dai da mangiare a %s"],
	"sweep.70": ["\ud83e\uddf9  Clean up %d mess(es)", "🧹  Pulisci %d pastrocchi"],
	"sweep.71": ["Start the shift  (2h, \u221220 energy)", "Inizia il turno  (2h, −20 energia)"],
	"sweep.72": ["Review attributes & badges", "Rivedi attributi e badge"],
	"sweep.73": ["\ud83d\udeaa  GO OUTSIDE", "🚪  ESCI FUORI"],
	"sweep.74": ["\ud83d\udcf1", "📱"],
	"sweep.75": ["\ud83d\udecf  Bed", "🛏  Letto"],
	"sweep.76": ["  %s", "  %s"],
	"sweep.77": ["\ud83e\ude9c  Second apartment", "🪜  Secondo appartamento"],
	"sweep.78": ["\ud83d\udcfa  Highlights", "📺  Sintesi"],
	"sweep.79": ["\ud83d\udc3e  Pets", "🐾  Pet"],
	"sweep.80": ["\ud83e\ude9f  Window", "🪟  Finestra"],
	"sweep.81": ["\ud83d\udcbb  Desk", "💻  Scrivania"],
	"sweep.82": ["\ud83d\udcbb  Job %d of 6", "💻  Turno %d di 6"],
	"sweep.83": ["\ud83d\udcbb  Shift over", "💻  Turno finito"],
	"sweep.84": ["WIN", "VITTORIA"],
	"sweep.85": ["The street is quiet.", "La strada è tranquilla."],
	"sweep.86": ["  (perfect-shift bonus)", "  (bonus turno perfetto)"],
	"sweep.87": ["DOWN", "GIÙ"],
	"sweep.88": ["LOSS", "SCONFITTA"],
	"sweep.89": ["STAIRS", "SCALE"],
	"sweep.90": ["ENTER", "ENTRA"],
	"sweep.91": ["Welcome to Iron Gym", "Benvenuto alla Iron Gym"],
	"sweep.92": ["Too tired. Eat or sleep first.", "Troppo stanco. Mangia o dormi prima."],
	"sweep.93": ["\ud83d\udcaa  START  (-%d energy)", "💪  VIA  (-%d energia)"],
	"sweep.94": ["weights", "pesi"],
	"sweep.95": ["cardio", "cardio"],
	"sweep.96": ["Too tired.", "Troppo stanco."],
	"sweep.97": ["Shift started!", "Turno iniziato!"],
	"sweep.98": ["Good load! %d/%d", "Bel carico! %d/%d"],
	"sweep.99": ["Dropped it. %d/%d", "Caduto. %d/%d"],
	"sweep.100": ["Shift done. Accuracy %d%% -> +%d$", "Turno finito. Precisione %d%% -> +%d$"],
	"sweep.101": ["LOADING DOCKS", "BANCHINA DI CARICO"],
	"sweep.102": ["Tap when the marker is in the green zone. 12 crates.", "Tocca quando il marker è nella zona verde. 12 casse."],
	"sweep.103": ["HOLD", "TIENI"],
	"sweep.104": ["SHOOT", "TIRA"],
	"sweep.105": ["QUIT", "ESCI"],
	"sweep.106": ["%s   %.1fs   reps %d   missed %d   combo x%d", "%s   %.1fs   rip %d   perse %d   combo x%d"],
	"sweep.107": ["%s   %.1fs   in the zone %d%%", "%s   %.1fs   in zona %d%%"],
	"sweep.108": ["%s   %.1fs   score %.0f/%.0f   combo x%d", "%s   %.1fs   punti %.0f/%.0f   combo x%d"],
	"sweep.109": ["WALK ONTO THE CIRCLE", "CAMMINA SUL CERCHIO"],
	"sweep.110": ["MISS", "ERRORE"],
	"sweep.111": ["CLIPPED THE CONE", "CONO TOCCATO"],
	"sweep.112": ["CLEAN x%d", "PULITO x%d"],
	"sweep.113": ["WRONG HAND", "MANO SBAGLIATA"],
	"sweep.114": ["WRONG SIDE", "LATO SBAGLIATO"],
	"sweep.115": ["CROSSOVER", "CROSSOVER"],
	"sweep.116": ["ON THE HIP", "SUL FIANCO"],
	"sweep.117": ["CONTESTED! x%d", "CONTESTATO! x%d"],
	"sweep.118": ["AIR SWIPE", "PRESA A VUOTO"],
	"sweep.119": ["GRADE %s", "GRADO %s"],
	"sweep.120": ["PUSH HARDER", "SPINGI DI PIÙ"],
	"sweep.121": ["three", "tre"],
	"sweep.122": ["PERFECT!", "PERFETTO!"],
	"sweep.123": ["BEATEN", "BATTUTO"],
	"sweep.124": ["DEEP REP!", "REP PROFONDA!"],
	"sweep.125": ["TOO HIGH - let it come down", "TROPPO ALTO - fallo scendere"],
	"sweep.126": ["LEFT", "SINISTRA"],
	"sweep.127": ["EASE OFF", "MOLLA"],
	"sweep.128": ["mid", "medio"],
	"sweep.129": ["SWISH", "SWISH"],
	"sweep.130": ["GOOD REP", "BUONA REP"],
	"sweep.131": ["FORM BREAK", "FORMA PERSA"],
	"sweep.132": ["RIGHT", "DESTRA"],
	"sweep.133": ["Too tired -- you need %d energy", "Troppo stanco -- ti servono %d energia"],
	"sweep.134": ["COURT WORK", "LAVORO IN CAMPO"],
	"sweep.135": ["TEAM COURT", "CAMPO DI SQUADRA"],
	"sweep.136": ["Practice with the squad or run a scrimmage.", "Allenati con la squadra o fai uno scrimmage."],
	"sweep.137": ["RIVERSIDE ARENA", "ARENA RIVERSIDE"],
	"sweep.138": ["Home of the Ravens.", "Casa dei Ravens."],
	"sweep.139": ["HOME", "CASA"],
	"sweep.140": ["no game scheduled", "nessuna partita in programma"],
	"sweep.141": ["rest", "riposo"],
	"sweep.142": ["AWAY", "TRASFERTA"],
	"sweep.143": ["NEED %d ENERGY (you have %d) \u00b7 rest first", "SERVONO %d ENERGIA (ne hai %d) · riposati prima"],
	"sweep.144": ["s", "s"],
	"sweep.145": ["\u25b6  TIP OFF", "▶  PALLA A DUE"],
	"sweep.146": ["in use", "in uso"],
	"sweep.147": ["YOUR TEAM  \u00b7  %s", "LA TUA SQUADRA  ·  %s"],
	"sweep.148": ["OPPONENT  \u00b7  %s", "AVVERSARI  ·  %s"],
	"sweep.149": ["TEAM KITS", "DIVISE"],
	"sweep.150": ["Choose the colours before you tip off.", "Scegli i colori prima della palla a due."],
	"sweep.151": ["Bought %s -- now on your wall", "Comprato %s -- ora sulla tua parete"],
	"sweep.152": ["Wall updated", "Parete aggiornata"],
	"sweep.153": ["Bought %s", "Comprato %s"],
	"sweep.154": ["You do not own that book.", "Non possiedi quel libro."],
	"sweep.155": ["Stairs", "Scale"],
	"sweep.156": ["Window", "Finestra"],
	"sweep.157": ["Fridge", "Frigo"],
	"sweep.158": ["Bed", "Letto"],
	"sweep.159": ["Wardrobe", "Armadio"],
	"sweep.160": ["TV", "TV"],
	"sweep.161": ["Desk", "Scrivania"],
	"sweep.162": ["Shower", "Doccia"],
	"sweep.163": ["Pets", "Pet"],
	"sweep.164": ["empty frame", "cornice vuota"],
	"sweep.165": ["Leave", "Esci"],
	"sweep.166": ["Your shelf is empty", "La tua mensola è vuota"],
	"sweep.167": ["START SHIFT", "INIZIA TURNO"],
	"sweep.168": ["LOAD CRATE", "CARICA CASSA"],
	"sweep.169": ["SHOOT AROUND (solo)", "TIRO DA SOLO"],
	"sweep.170": ["TEAM PRACTICE (today)", "PRATICA DI SQUADRA (oggi)"],
	"sweep.171": ["\u25b6  TIP OFF vs %s", "\u25b6  PALLA A DUE vs %s"],
	"sweep.172": ["Today's game is finished", "La partita di oggi è finita"],
	"sweep.173": ["\ud83d\udcc5  Season schedule", "\ud83d\udcc5  Calendario stagione"],
	"sweep.174": ["Next game: day %d vs %s  (in %d day%s)", "Prossima partita: giorno %d vs %s  (tra %d giorn%s)"],
	"sweep.175": ["NO GAME TODAY", "NESSUNA PARTITA OGGI"],
	"sweep.176": ["Every fixture, result and rest day", "Ogni partita, risultati e giorni di riposo"],
	"common.phone": ["PHONE", "TELEFONO"],
	"sweep.177": ["Sofa", "Divano"],
	"sweep.178": ["Rug", "Tappeto"],
	"sweep.179": ["Armchair", "Poltrona"],
	"sweep.180": ["Floor lamp", "Piantana"],
	"sweep.181": ["Plant", "Pianta"],
	"sweep.182": ["Bookshelf", "Libreria"],
	"sweep.183": ["Dining table", "Tavolo da pranzo"],
	"sweep.184": ["EQUIPPED", "EQUIAGGIATO"],
	"sweep.185": ["OWNED", "POSSEDUTO"],
	"sweep.186": ["EQUIP", "EQUIAGGIA"],
	"sweep.187": ["REMOVE", "TOGLI"],
	"sweep.188": ["LEG: %s", "GAMBA: %s"],
	"sweep.189": ["ARM: %s", "BRACCIO: %s"],
	"sweep.190": ["DX", "DX"],
	"sweep.191": ["SX", "SX"],
	"sweep.192": ["Knee sleeve", "Ginocchiera"],
	"sweep.193": ["Ankle brace", "Cavigliera"],
	"sweep.194": ["Wrist wrap", "Fascia polso"],
	"sweep.195": ["Compression tights", "Calze compressive"],
	"sweep.196": ["Call it! (pass button)", "Chiamala! (tasto passa)"],
	"settings.voice": ["Voices", "Voci"],
	"settings.crowd": ["Crowd", "Folla"],
	"match.home":     ["HOME", "CASA"],
	"match.away":     ["AWAY", "OSPITI"],
	"match.shotclk":  ["shot %s", "tiri %s"],
	"post.win":       ["WIN", "VITTORIA"],
	"post.loss":      ["LOSS", "SCONFITTA"],
	"post.grade":     ["Grade: %s", "Voto: %s"],
	"post.city":      ["BACK TO THE CITY", "TORNA IN CITTÀ"],
	"post.phone":     ["OPEN PHONE (check the feed)", "APRI IL PHONE (guarda il feed)"],
	# ---- broadcast pass (v2.1.0): intro card, commentary, jumbo, post card
	"bc.tonight":     ["TONIGHT", "STASERA"],
	"bc.vs":          ["vs", "vs"],
	"bc.tap":         ["TAP TO START", "TOCCA PER INIZIARE"],
	"bc.final":       ["FINAL", "FINALE"],
	"bc.record":      ["%dW-%dL", "%dV-%dP"],
	"bc.quarters":    ["BY QUARTER", "PER QUARTO"],
	"bc.top":         ["Top scorers: %s %d pts · %s %d pts", "Migliori: %s %d pt · %s %d pt"],
	"bc.run":         ["%d straight points by %s (Q%d)", "%d punti di fila di %s (Q%d)"],
	"bc.scrimmage":   ["SCRIMMAGE", "ALLENAMENTO"],
	"bc.challenger":  ["STREET 1v1", "SFIDA 1v1"],
	"bc.style.run":   ["Run & Gun", "Run & Gun"],
	"bc.style.lock":  ["Lockdown D", "Difesa di ferro"],
	"bc.style.inside":["Inside-Out", "Dentro-Fuori"],
	"bc.style.grit":  ["Grit & Glass", "Grinta e rimbalzi"],
	"bc.style.none":  ["", ""],
	"comm.run":       ["%s are on a %d-point run!", "%s corre: %d punti di fila!"],
	"comm.dunk.0":    ["Oh! What a slam!", "Oh! Che schiacciata!"],
	"comm.dunk.1":    ["The rim is still shaking!", "Il ferro trema ancora!"],
	"comm.dunk.2":    ["Put that one on the wall!", "Quella va appesa al muro!"],
	"comm.three.0":   ["From downtown — bang!", "Dal centro — bang!"],
	"comm.three.1":   ["Nothing but net from deep!", "Solo reticello dal fondo!"],
	"comm.three.2":   ["He cannot miss tonight!", "Stasera non sbaglia una!"],
	"comm.cold.0":    ["The rim is closed tonight...", "Stasera il ferro è chiuso..."],
	"comm.cold.1":    ["Ice cold stretch — somebody heat the ball up!", "Ghiaccio puro — qualcuno scaldi la palla!"],
	"comm.lead.0":    ["The lead changes hands!", "Cambia il vantaggio!"],
	"comm.lead.1":    ["Swing! Nobody gives an inch here!", "Ribalta! Qui non si regala un centimetro!"],
	"comm.qend.0":    ["End of the quarter.", "Fine del quarto."],
	"comm.qend.1":    ["Ten to regroup, then back at it.", "Dieci per riprendersi, poi si riparte."],
	"comm.clutch":    ["Under thirty seconds — this is anyone's game!", "Meno di trenta secondi — la partita è in bilico!"],
	"jumbo.welcome":  ["WELCOME TO %s", "BENVENUTI AL %s"],
	"jumbo.slam":     ["SLAM!", "SCHIACCIA!"],
	"jumbo.three":    ["FROM DEEP!", "DAL FONDO!"],
	"jumbo.noise":    ["MAKE SOME NOISE!", "FATE DEL RUMORE!"],
	"jumbo.dance":    ["DANCE CAM!", "DANCE CAM!"],
	"jumbo.defense":  ["DE-FENSE!", "DIFE-NSA!"],
	"creator.title":  ["CREATE YOUR PLAYER", "CREA IL TUO GIOCATORE"],
	"creator.sub":    ["Height and weight really change acceleration and contact.",
	                   "Altezza e peso cambiano davvero accelerazione e contatti."],
	"creator.pos":    ["Position: %s", "Ruolo: %s"],
	"creator.height": ["Height  %d cm", "Altezza  %d cm"],
	"creator.weight": ["Weight  %d kg", "Peso  %d kg"],
	"creator.team":   ["Team: %s", "Squadra: %s"],
	"creator.jersey": ["Jersey  #%d", "Maglia  #%d"],
	"creator.skin":   ["Skin", "Carnagione"],
	"creator.hair":   ["Hair", "Capelli"],
	"creator.hand":   ["Hand", "Mano"],
	"phone.messages": ["Messages", "Messaggi"],
	"phone.social":   ["HoopFeed", "HoopFeed"],
	"phone.calendar": ["Calendar", "Calendario"],
	"phone.shop":     ["Store", "Negozio"],
	"phone.profile":  ["My Card", "La mia scheda"],
	"phone.stats":    ["Stats", "Statistiche"],
	"phone.wallpaper": ["Wallpaper", "Sfondo"],
	"w.clear":        ["Sunny", "Sereno"],
	"w.cloudy":       ["Cloudy", "Nuvoloso"],
	"w.rain":         ["Rain", "Pioggia"],
	"w.snow":         ["Snow", "Neve"],
	"s.winter":       ["Winter", "Inverno"],
	"s.spring":       ["Spring", "Primavera"],
	"s.summer":       ["Summer", "Estate"],
	"s.autumn":       ["Autumn", "Autunno"],
}

# English callout -> Italian, for strings emitted by the sim. Placeholders
# (%d / %s) are matched as wildcards so "BLOCKED by #34" still translates.
const CALLOUTS := {
	"PERFECT": "PERFETTO", "GOOD": "BELLO", "EARLY": "PRESTO", "LATE": "TARDI",
	"BLOCKED!": "STOPPATO!", "BLOCKED AT THE RIM!": "STOPPATA AL FERRO!",
	"BLOCKED by #%d": "STOPPATO da #%d", "STEAL!": "RUBATA!",
	"ANKLES!": "CAVIGLIE!", "DUNK!": "SLAM!", "BALL!": "PALLA!",
	"CHECK THE BALL": "CHECK", "CHECK THE BALL  %d - %d": "CHECK  %d - %d",
	"GO!": "VIA!", "Q1 - Tip-off": "Q1 - Palla a due",
	"Loose ball!": "Palla vagante!", "Loose ball recovered": "Palla vagante recuperata",
	"Covered — no lane": "Coperto — nessun varco", "No lane!": "Nessun varco!",
	"SCREEN": "BLOCCO", "ROLL": "ROLL", "Cleared - go!": "Libero - vai!",
	"Shot clock violation": "Violazione di 24\"", "Inbound": "Rimessa",
	"Intercepted!": "Intercettato!", "Turnover": "Palla persa",
	"Foul on #%d": "Fallo di #%d", "Free throws ×%d": "Tiri liberi ×%d",
	"Free throw made": "Libero a segno", "Free throw miss": "Libero sbagliato",
	"Rebound #%d": "Rimbalzo #%d", "Defender bit the fake!": "Il difensore ha abboccato!",
	"ON FIRE!": "IN FIAMME!", "UNSTOPPABLE!": "IMMARCABILE!",
	"Streak over": "Serie finita",
	"END Q%d": "FINE Q%d",
	"No shot from behind the hoop": "Non si tira da dietro il canestro",
	"PUMP FAKE": "FINTA DI TIRO",
	"DEFENSE ON — stay in front of your man": "DIFESA — resta davanti al tuo uomo",
	"Hold SHOOT to score - tap SHOOT to PUMP FAKE - TRICK shakes your man":
		"Tieni TIRA per segnare - tocca TIRA per la finta - FINTA sbilancia il difensore",
	"You walked out on the game": "Hai abbandonato la partita",
	"WINDMILL": "WINDMILL", "360": "360", "TOMAHAWK": "TOMAHAWK",
	"CRADLE": "CRADLE", "REVERSE": "REVERSE", "TWO-HAND": "DUE MANI",
	"SLAM": "SLAM",
	"MISS": "SBAGLIATO", "BANK": "TABELLONE", "VERY": "TROPPO",
}

var _rev := {}          # exact EN -> IT
var _patterns := []     # [Regex, IT template] for placeholder strings

func _init() -> void:
	for k in STR:
		_rev[STR[k][0]] = STR[k][1]
	for k in CALLOUTS:
		var en: String = k
		if en.contains("%"):
			var rx := RegEx.new()
			var pat := ""
			var i := 0
			while i < en.length():
				if en[i] == "%" and i + 1 < en.length():
					pat += "([-\\d\\w:#×\"]+)" if en[i + 1] == "s" else "([-\\d×\"]+)"
					i += 2
				else:
					pat += "\\" + en[i] if en[i] in "\\.^$|?*+()[]{}" else en[i]
					i += 1
			rx.compile("^" + pat + "$")
			_patterns.append([rx, CALLOUTS[en]])
		else:
			_rev[en] = CALLOUTS[en]

func _ready() -> void:
	lang = String(Settings.get_v("lang", _detect()))
	if lang != "it":
		lang = "en"

func _detect() -> String:
	var l := OS.get_locale()
	return "it" if l.begins_with("it") else "en"

func set_lang(l: String) -> void:
	lang = "it" if l == "it" else "en"
	Settings.set_v("lang", lang)
	changed.emit()

func toggle() -> void:
	set_lang("it" if lang == "en" else "en")

func t(key: String, fallback := "") -> String:
	var e = STR.get(key)
	if e == null:
		return fallback if fallback != "" else key
	var s: String = e[0] if lang == "en" else e[1]
	return s

## Translate a finished English string (callouts, toasts). Passthrough when
## unknown, so partially-localised content never shows garbage.
func tx(en_text: String) -> String:
	if lang == "en":
		return en_text
	if _rev.has(en_text):
		return String(_rev[en_text])
	for p in _patterns:
		var m: RegExMatch = p[0].search(en_text)
		if m:
			var out: String = p[1]
			var gi := 0
			var result := ""
			var pi := 0
			while pi < out.length():
				if out[pi] == "%" and pi + 1 < out.length():
					if gi < m.get_group_count():
						result += m.get_string(gi + 1)
					gi += 1
					pi += 2
				else:
					result += out[pi]
					pi += 1
			return result
	# Last resort: translate token by token so composite callouts such as
	# "GOOD / BANK +2" still read naturally instead of passing through raw.
	var parts := en_text.split(" ")
	var hit := false
	for i in parts.size():
		if _rev.has(parts[i]):
			parts[i] = String(_rev[parts[i]])
			hit = true
	return " ".join(parts) if hit else en_text