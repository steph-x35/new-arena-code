# HoopCity — v2.1.4 · Suoni reali (rimbalzo, rete, voci)

**APK:** `HoopCity-v2.1.4.apk` (29 MB) — versionCode 59, arm64-v8a
**Firma:** invariata — si installa sopra le precedenti

- **Rimbalzo**: 3 prese reali da registrazioni basket (Mixkit, licenza libera per uso commerciale) — "hard hit", "quick hit", "ground hit" — ritagliate sull'attacco, 22.05 kHz mono, normalizzate. Rotatione delle 3 prese + pitch casuale come prima.
- **Swish**: registrato da una rete vera ("Basketball ball hitting the net").
- **Voci di campo**: generate con una voce umana (scelta tra due candidate in fase di sviluppo) — "De-fense! De-fense!", "Ball! Ball here!", "Shoot it!", "Pass it here!", "Rebound! Box out!", "Nice one!" — trim dei silenzi e normalizzazione. Definitivamente intelligibili.
- CREDITS.md in assets/sfx con la licenza Mixkit.

Test: import 0 errori, SceneSmoke OK.

---

# HoopCity — v2.1.3 · Rifiniture dal playtest

**APK:** `HoopCity-v2.1.3.apk` (29 MB) — versionCode 58, arm64-v8a
**Firma:** invariata — si installa sopra le precedenti

1. Fischi in partita: rimossi (restano solo clamori/ooo/cheer).
2. Traffico: rimosso dall'audio città — solo jazz lounge (+ pioggia).
3. Pioggia: rigenerata molto più delicata e con garanzia di loop a runtime.
4. Palla a due: l'arbitro entra nel cerchio, alza le mani, fischia e lancia; i due centri saltano e il tip assegna il possesso; l'arbitro poi rientra in linea.
5. Telefono: orologio centrato nella striscia alta.
6. MENU in città: ora visibile (era coperto dalla barra status), posizionato sulla riga della barra in alto a destra.

Test: import 0 errori · SceneSmoke OK · SimRunner 5v5 FINISHED 14-8.

---

# HoopCity / Hoop City Life — v2.1.2 · Secondo pass audio & feel

**APK:** `HoopCity-v2.1.2.apk` (29 MB) — versionCode 57, arm64-v8a, minSdk 21 / targetSdk 34
**Firma:** invariata — si installa sopra le precedenti

## Feedback → fix
1. **Traffico costante**: loop rigenerato senza buchi (lavaggio stabile + passaggi lontani), volume -16 dB.
2. **Lounge più alto**: da -11 a -6.5 dB; pioggia e lounge ora in LOOP NATIVO (prima si fermavano dopo un giro).
3. **Palleggio realistico**: rigenerato in 3 strati (slap di cuoio 0.7-2.8 kHz + corpo 155 Hz che scende + colpo sul parquet), 3 prese diverse.
4. **Squeak udibile ovunque**: trigger molto più generoso (curve >95 px/s, svolta >32°, cooldown 0.14-0.34 s) + sample più caldo e Mix a +1.5. Anche nei court solo.
5. **Voci afro-inglesi**: F0 bassa (145-205 Hz), vocali pure scandite (DE-FENS, BAAAL, SHUUT), consonanti secche, respiro in ingresso. Leggibili ma sotto il gioco (-2.5 dB).
6. **Retina anche in schiacciata**: swish cupo (pitch 0.84-0.92) a ogni slam.
7. **Pulsante MENU in alto a destra in città**: salva e torna al menu (dove c'è IMPOSTAZIONI).
8. **Caos tribune in OGNI partita** (anche scrimmage/1v1): folla visiva + swell ogni 1-3 s + fischi (15%), tutto più presente.
9. **Suoni retina/squeak/palleggio su ogni court**: i drill ora hanno swish, ferro e rilascio; solo e partita li avevano.
10. **PALLA A DUE** all'inizio di ogni 5v5 (scrimmage compreso): formatione nel cerchio, lancio dell'arbitro, salto dei due centri, tip pesato su altezza+sagacia verso un compagno. 1v1 resta check-ball (regola di strada).
11. **Spin move**: doppio tap su TRICK = 360° con palla che avvolge il corpo e spalle che girano (yaw visivo). Ampiezza crossover/scambio mano aumentata.

## Test
```
SceneSmoke 1v1 OK · SimRunner 5v5 FINISHED 21-6 (palla a due inclusa) · import 0 errori
```

---

# HoopCity / Hoop City Life — v2.1.1 · Audio & feel pass

**APK:** `HoopCity-v2.1.1.apk` (29 MB) — versionCode 56, arm64-v8a, minSdk 21 / targetSdk 34
**Firma:** invariata — installabile sopra la 2.1.0 / 2.0.7

## Cosa è cambiato (feedback playtest)
1. **Città più delicata**: traffico da -12 a -20 dB; nuova **pioggia leggera** (loop 9 s seamless, -22 dB) quando il meteo è "rain".
2. **Voci di partita**: rigenerate con sintesi formantica (F1/F2 con traiettorie, consonanti, fiato, doppione detuned) — meno robotiche, più calde, pitch più basso (0.94–1.10) e Mixate a -3.5 dB.
3. **Tifoseria**: bed più presente (-12/-6 dB), confusione continua (swell ogni 1.1–2.9 s) e **fischi occasionali** (~12% dei swell, warble 11 Hz).
4. **Squeak** rigenerato: stick-slip reale (sweep 2.1→3.4→2.8 kHz, AM 71 Hz, soffio gommato), suona a -1 dB.
5. **Swish** rigenerato secondo la ricerca: snap degli anelli + "shhh" con banda che scende 3.3k→1.05k, flutter dei fili (33 Hz), corpo cotone sotto. Nessun ferro.
6. **Telefono**: tutte le icone app (+ wallpaper, + like/commenti del feed) sono glifi vettoriali di Art.draw_icon — zero emoji, identiche su ogni device.
7. **Stamina**: corsa 1.2→2.4/s, stance 2.0→2.6/s, recupero 7.0→6.2/s, salto 3→4.5, schiacciata 6→8, mossa 4→6. Il serbatoio si sente.
8. **Rimessa chiamata**: la difesa non si congela più — ogni difensore ombreggia il mark tra uomo e canestro (fine del cherry-pick da rimessa).

## Test
```
import 0 errori · SfxProbe (lounge+pioggia+fischi+squeak) OK
SceneSmoke OK · SimRunner 1v1 FINISHED · SimRunner 5v5 FINISHED 8-10
```

---

# HoopCity / Hoop City Life — v2.1.0 · Broadcast Pass + jazz lounge

**APK:** `HoopCity-v2.1.0.apk` (29 MB) — `com.example.hoopcity`, versionCode 55, versionName 2.1.0, arm64-v8a, minSdk 21 / targetSdk 34
**SHA-256:** `12bf8b0be069347a45652cdd964f69ed65e66355ee4fc8605faddb2cf438bf12`
**Firma:** invariata (debug key del progetto) — installabile sopra la 2.0.7

## 1. Broadcast Pass — ogni partita sembra una telecronaca diversa

- **Identità dei club** (`Season.gd`): sigla, kit, arena, stile di gioco e pool nomi per tutti gli 8 club. Il parquet indoor si tinge del colore di chi possiede il palazzetto; l'avversario arriva sempre in maglia propria e i suoi NPC prendono attributi dallo stile del club (+6 su 2 rating).
- **Intro card**: arena, matchup con chip colore, record V-P (deterministico dal seed), stili contrapposti. Tap per saltare; il countdown parte dopo.
- **Commentatore** (`Commentary.gd`, nuovo): frasi IT/EN variabili su run da 6+, schiacciate, triple, cambi vantaggio (dal Q3), periodi freddi, clutch time. Rate-limited (7 s / 4 s sui gioconi).
- **Jumbotron**: marquee con messaggi live (SLAM!, DAL FONDO!, MAKE SOME NOISE...) e pubblicità rotanti; schermi squadre nei colori reali dei club.
- **Post-game card**: FINALE + arena, punteggio con club, punti per quarto, run decisiva (≥8), top scorer di entrambe le squadre, voto e stat line.
- **Fix**: il banner DUNK non compariva mai (Court emette "DUNK WINDMILL", il confronto era `== "DUNK"`); scoreboard con sigle club al posto di HOME/AWAY; la Quick Exhibition ora pesca un club casuale.

## 2. Jazz lounge bar chill — città ed edifici

- Nuovo loop procedurale `music_lounge` (54,9 s, seamless): 16 battiti a 70 bpm in swing, basso walking, Rhodes con 7e/9e, brushes, vibes con fraseggio, murmur di stanza + clink. Generato da `tools/gen_lounge.py` (numpy, seed fisso, riproducibile).
- `Sfx.play_life()` ora usa il lounge: menu, intro, città (sotto il traffico) e **tutti** gli edifici. Il jazz-arena (`music_jazz`) resta come letto sotto la folla nelle partite del campionato; corti e palestre restano senza musica.

## Test eseguiti
```
import headless 0 errori · SceneSmoke OK · SimRunner 5v5 x2 FINISHED (quarti = somma esatta)
probe run/quarti/punti-giocatore OK · PostGame render OK · 8 script toccati compilano OK
SfxProbe: play_life() → music_lounge.wav playing=true · apksigner verify OK
```

---

# HoopCity / Hoop City Life — v1.7.0 · build con schiacciate e shot meter

**APK consegnato:** `HoopCity-v1.7.0.apk` (24 MB) — `com.example.hoopcity`, versionCode 43, versionName 1.7.0, arm64-v8a, minSdk 21 / targetSdk 34
**SHA-256:** `5c68a35f0de1714e7203205f905facaa5427122bcfafbe1d6bfe584fd9f63151`
**Firma:** v1+v2+v3, debug key del progetto (`keystore/debug.keystore`) — installabile sopra la build precedente, non pubblicabile su Play Store
**Prove visive:** `hoopcity/docs/dunks_report.html` (immagini raccolte eseguendo il gioco)

---

## 1. Schiacciate in ogni court (indoor e outdoor, solo, scrimmage, 1v1)

Prima: **zero** schiacciate in ogni simulazione AI-vs-AI, sia 1v1 sia 5v5. Dopo: presenti in tutte le partite simulate.

Cause trovate e corrette:
| # | Problema | Correzione |
|---|---|---|
| 1 | `can_dunk()` richiedeva `atletica × altezza > 40`: molti giocatori creati e buona parte della rosa non poteva **mai** schiacciare | soglia rimossa: limita solo la stamina (`> 0.15`) |
| 2 | L'AI schiacciava solo con ruolo `drive` **e** dopo 8 s di possesso | il ferro si attacca appena si arriva al canestro con un minimo di spazio, anche in 1v1 |
| 3 | La schiacciata era dietro i cooldown del *tiro* (arrivando al ferro in movimento non partiva mai) | ramo dedicato, indipendente da `can_fire` |
| 4 | **La stamina restava a 0 per tutta la partita**: nessuno si ferma mai in 1v1 e il recupero avveniva solo da fermi | recupero anche in movimento, drain da corsa ridotto (pesano salti/mosse/tiri) |
| 5 | La palla non seguiva la mano: veniva solo spenta al momento dello slam | la palla **cavalca la mano** per tutto il volo (`carry_ball_offset` ↔ `Ball`) |

## 2. Animazioni di schiacciata (windmill, 360, tomahawk, cradle, reverse, two-hand)

Nuovo **`src/match/DunkStyle.gd`**: un unico catalogo condiviso da *tutte* le scene (street/solo outdoor, palestra indoor, scrimmage 5v5, 1v1). Ogni stile espone timeline, pose e posizione della palla in unità di *altezza-corpo*, così il canestro non cambia mai e la palla non si stacca mai dalla mano.

- **Windmill**: il braccio compie una rotazione reale di ~4.7 rad (270°) attorno alla spalla.
- **360**: il corpo ruota (assetto + vista di spalle) con la palla sempre in mano.
- **Tomahawk**: braccio caricato dietro la testa e frustato in avanti-alto.
- **Cradle**: palla portata in basso tra le gambe al culmine e poi risalita.
- **Reverse**: giro di spalle e appoggio dall'altro lato del ferro.
- **Two-hand**: due mani, schiacciata secca.

La schiacciata in partita è ora **scriptata** sullo stesso timing dell'animazione (`DunkStyle.rise_time`), quindi la mano arriva **esattamente sul ferro** (verificato a schermo in scala di gioco: corpo 64 px, ferro 188 px).

## 3. Shot meter sempre sopra la testa

- **Street/solo**: `_place_meter()` era definita ma **mai chiamata** → l'arco restava ancorato a un angolo dello schermo. Ora si aggiorna ogni frame.
- **Match (1v1/5v5)** e **drill**: l'arco segue la testa, **anche in salto** (usa la stessa quota con cui il giocatore viene disegnato in volo), con clamp ai bordi perché la banda verde non venga mai tagliata.
- Nel drill l'arco aveva dimensioni diverse (280×200): ora è identico ovunque (120×78).

---

## Test eseguiti

```
5v5  ×3 : 2-6, 7-11, 5-14   → 1-6 schiacciate per partita (SLAM, WINDMILL, 360, TOMAHAWK, CRADLE, REVERSE)
1v1 ×3  : schiacciate presenti (360 SLAM, windmill, reverse)
street  : tutti gli stili, indoor e outdoor
geometria: mano/palla sul ferro a t=1.0 (rim check in scala di gioco)
```

> **Nota di trasparenza:** il primo tentativo introduceva un bug (il giocatore restava bloccato in volo dopo lo slam e l'AI restava sotto il canestro fino alla violazione dei 24"). È stato individuato con le simulazioni automatiche e corretto: le 3 partite 5v5 finali si chiudono regolarmente con punteggi realistici.

## Strumenti aggiunti (riutilizzabili)

- `tools/DunkShowcase.gd` + `.tscn` — pose sheet di tutti gli stili, rim check geometrico, e cattura di fotogrammi da **partite reali**:
  ```
  /opt/hc/godot/godot --path . res://tools/DunkShowcase.tscn -- --mode sheet --page 0 --out /tmp/shots
  # --mode: sheet | rimcheck | 1v1 | full | solo | drill
  ```
- `tools/SimRunner.gd` — ora accetta `--target N` per giocare un 1v1 completo (prima si fermava a 2 punti).

## Ricostruzione (il toolchain non è persistente)

```bash
unzip -o tools/godot.zip -d /opt/hc/godot && chmod +x /opt/hc/godot/Godot_*
export JAVA_HOME=/opt/hc/jdk17 PATH=/opt/hc/jdk17/bin:$PATH
/opt/hc/godot/godot --headless --path hoopcity --import
/opt/hc/godot/godot --headless --path hoopcity --export-release "Android" hoopcity/build/HoopCity-v1.7.0.apk
```
(JDK 17 Temurin, Android SDK platform-tools / platforms;android-34 / build-tools;34.0.0, export templates 4.3.stable — vedi `BUILD_NOTES.md` originale per gli URL.)

---

# v1.8.0 — Art direction + localizzazione IT/EN

**APK:** `HoopCity-v1.8.0.apk` (25 MB) — `com.example.hoopcity`, versionCode 44, versionName 1.8.0, arm64-v8a, minSdk 21 / targetSdk 34
**SHA-256:** `7585bf555f480183702593c19cf133919cdcfa02917278469aa8bbd2dbb99fa7`
**Prove visive:** `hoopcity/docs/v18/` (menu EN/IT, HUD partita, impostazioni IT, città)

## 1. Identità visiva (src/ui/Art.gd + HoopTheme.tres)
- Nuovo modulo `Art`: palette unica (charcoal / cream / arancio pallone), icone vettoriali, costruttore del tema.
- `HoopTheme.tres` generato da `tools/MakeTheme.gd` e installato project-wide (`gui/theme/custom`): tutti i Button/Panel/ProgressBar/LineEdit del gioco (menu, negozi, phone, dialoghi) hanno ora lo stesso look senza toccare le singole scene. Rigenerare con: `godot --headless --path . --script res://tools/MakeTheme.gd`.

## 2. HUD partita "broadcast"
- Scoreboard a pillola centrata: chip color squadra + CASA/OSPITI + punteggio grande, sotto quarto/orologio/24"; bordo arancio.
- Pad touch ridisegnati: disco fumé traslucido, anello colorato per fase (arancio attacco, rosso difesa, blu playmaking, oro check), glifo vettoriale + caption piccola → il campo resta leggibile.
- Stamina: barra verde arrotondata + icona fulmine; EXIT compatta in alto a sinistra.

## 3. Menu & città
- MainMenu: logo su card cream, skyline animata con finestre accese e braci alla deriva, colonna menu a destra.
- StatusBar: banda charcoal con filetto arancio, chip con icone vettoriali (niente più emoji, che renderizzano diversamente su ogni skin Android).

## 4. Localizzazione IT/EN (src/core/Loc.gd)
- Autoload `Loc`: `Loc.t(key)` per la UI e `Loc.tx(testo)` per i callout emessi dal sim (match esatto + pattern con %d/%s + fallback parola-per-parola; ciò che non c'è passa in inglese senza rompersi).
- Lingua in Impostazioni → "Lingua EN/IT", default dal locale del dispositivo.
- Coperto ora: menu, intro, impostazioni, HUD partita, toast/callout partita, post-partita, phone (nomi app), creatore personaggio, barra stato.
- **Non ancora tradotti (prossimo giro):** contenuti di negozi, casa, città, palestra, lavoro, drill e testi dei libri (restano EN in modalità IT).

## 5. Strumenti nuovi
- `tools/SceneShot.tscn` — screenshot da display virtuale:
  `xvfb-run -a godot --path . res://tools/SceneShot.tscn -- --scene res://src/scenes/MainMenu.tscn --wait 1 --out /tmp/x.png [--lang it] [--drive]`
- `tools/ParseAll.tscn` — compile-check di tutti i .gd con gli autoload vivi.
- `tools/MakeTheme.gd` — rigenera HoopTheme.tres da Art.make_theme().

## Ricostruzione APK (toolchain non persistente)
Come v1.7.0, più: JDK 17 Temurin in `/opt/hc/jdk17`, SDK in `/opt/hc/sdk`
(cmdline-tools 11076708 + platform-tools + build-tools;34.0.0 + platforms;android-34),
export templates 4.3.stable in `~/.local/share/godot/export_templates/4.3.stable`.

---

# v1.8.1 — Audio, pick&roll, decisioni AI, balance

**APK:** `HoopCity-v1.8.1.apk` — versionCode 45, versionName 1.8.1 (installabile sopra 1.8.0/1.7.0)
**SHA-256:** vedere output di `sha256sum HoopCity-v1.8.1.apk` (riportato sotto)

## 1. Audio finalmente udibile (bug reale, non di volume)
`Sfx._ready()` caricava i suoni con una scansione `DirAccess` della cartella `res://assets/sfx/`.
Dentro un `.pck` esportato i `.wav` sorgente NON compaiono come file (ci sono solo i remap
`.sample` importati): la scansione non trovava nulla e **ogni `Sfx.play()` diventava un no-op
silenzioso** — da qui il "non sento nulla" sul telefono. Ora la lista dei suoni è esplicita
(`SFX_NAMES`) e caricata per nome. Musica avviata già dall'intro, non solo dal menu.

## 2. Pick & roll
- `Court` ora ricorda CHI ha portato il blocco (`pnr_screener`): il roll va al bloccante vero,
  non al primo compagno capitato nel loop (bug che lasciava il bloccante piantato per tutta
  la partita mentre un altro "rollava").
- Finestra di 5 s: se non rilasci mai il P&R, il bloccante rolla da solo (mai più piantato).
- Il roller è marcato come bersaglio privilegiato dei passaggi (`pnr_roller`).
- Anche i portatori di palla AI chiamano il proprio P&R quando sotto pressione.

## 3. Decisioni di passaggio (scrimmage)
Nuovo layer `_best_feed()` nell'AIBrain: il portatore passa davvero quando
- un compagno è **libero sotto canestro** (< 8 ft e poco contestato): priorità massima;
- il roller sta tagliando al ferro scoperto;
- il portatore è soffocato e c'è una mano più libera della sua.
Prima il passaggio avveniva solo col portatore già soffocato (pressione > 0.80) e al 20%:
il compagno libero sotto non la vedeva mai.

## 4. Balance & simulatore affidabile
- **Volo della palla analitico** (`Ball.gd`): l'arco balistico era integrato a passi Eulero,
  quindi l'arrivo sul ferro dipendeva dal delta fisico (sim veloci → tiri "made" che
  mancavano il ferro di 100+ px; stesso rischio su telefoni che perdono frame).
  Ora la traiettoria è in forma chiusa: identica a qualunque delta.
- `SimRunner`: i risultati passati a scale>1 erano falsati da quel bug; ora le sim girano
  corrette e i numeri sotto sono reali.
- Shot clock 24 → 18 s (più possessi); trigger schiacciata AI 8.5 → 6.5 ft con condizione
  di spazio (meno festival di slam identici); pull-up AI più pronto; curva tiri alzata
  (mid 0.36-0.66, tre 0.28-0.60).

### Sim dopo le fix (scale 12, fisica onesta)
```
1v1 x3 : 9-11, 9-11, 4-11   → tutte chiuse, ~45% dal campo, slam presenti
5v5 x3 : 8-20, 11-12, 10-22 → chiuse, punteggi competitivi con blowout realistici
5v5 x2 (pre-balance) : 10-10, 7-14
```
SHA: fda7a68251bd59bbfa24639fdb2f4ef0e65b19ced752570898bd82bd52bcd4e6

---

# v1.9.0 — Panchine, coach, timeout, tavolo segnapunti, audio ambientale

**APK:** `HoopCity-v1.9.0.apk` — versionCode 46, versionName 1.9.0
**SHA-256:** vedere in coda a questa sezione.

## Audio nuovo
- `traffic_loop.wav` (procedurale, 10 s loop): letto di traffico in città,
  avviato/fermato da CityScene.
- `music_lofi.wav` (loop lofi chill 70 BPM: Rhodes, basso, kick/hat swingati,
  fruscio vinile): musica delle scene life-sim al posto del loop energetico.
- Swish della retina: già presente ma inudibile per il bug audio di 1.8.0;
  ora i tiri "nothing but net" hanno uno swish più pieno (`ball.swish_clean`).
- Caos tifosi: durante le partite vere `Sfx.match_live` genera ondate
  casuali di tifo/ohh sopra il bed della folla, più fitte quando l'hype sale.

## Panchine, riserve sedute, coach (solo partite vere)
- `Court.is_fixture` (flag `match_is_fixture` messo da ArenaLobby/Phone/Intro;
  lo scrimmage da TeamCourt lo mette a false): nello scrimmage le panchine
  ci sono ma VUOTE, gli spalti restano vuoti.
- Lato in fondo: panchina squadra casa a sinistra, ospiti a destra, tavolo
  segnapunti al centro con tre ufficiali seduti (estetica).
- Riserve sedute disegnate in posa seduta (testa/torso/gambe piegate),
  coach in piedi con targhetta a fine panchina.
- Rotazioni del coach sull'utente: valutazione ogni ~22 s di gioco su
  impatto (punti+rimbalzi+assist+ recuperate*1.5 - palle perse*2 / minuto)
  e stamina: gioco sotto tono o gambe finite → cambio, con animazione
  (la riserva entra camminando dalla panchina, tu esci e ti siedi).
- Rientro: dopo ~65 s di panchina, se la squadra va sotto di 8+, o alla
  pausa di quarto (la stamina nel frattempo recupera in panchina).
- Overlay "IN PANCHINA": GUARDA (resti a vedere, comandi spenti) oppure
  SIMULA FINO AL RIENTRO (time_scale x6 finché il coach ti rimanda dentro).
- Spalti: `crowd_fill` parte da 0 e si riempie in ~45 s solo nelle partite
  vere e negli 1v1; scrimmage = spalti vuoti.

## Timeout
- Pulsante TIMEOUT (2) in alto a destra nelle partite 5v5: fischio, clock
  fermo 4 s reali, poi ripresa con palla alla squadra chiamante.
- 2 timeout a squadra per partita.

## HUD
- Niente più parole fluttuanti sopra la testa mentre carichi il tiro:
  i popup vicini al tiratore vengono soppressi finché il meter è attivo.

## Note tecniche
- Telecamera leggermente più alta (CAM_HEIGHT -88) per inquadrare la fila
  delle panchine sotto il tabellone segnapunti.
- Cheerleaders spostate sul grembiule davanti alle panchine.
- Workspace ripulito dagli APK vecchi per restare nel budget snapshot.

### Sim di regressione (scale 12)
```
1v1 x3 : 6-5(TO), 4-11, 1-11     5v5 x2 : 8-21, 18-16
```
SHA: 86d430134e72b15ca5c26b361ad2f277b5200ed3f3c828166fcbd23ac44edd7d

---

# v2.0.0 — Jazz, parquet vivo, impianto reale, localizzazione completa

**APK:** `HoopCity-v2.0.0.apk` — versionCode 47, versionName 2.0.0
**SHA-256:** in coda a questa sezione.

## Audio
- `music_jazz.wav`: trio jazz procedurale (ride swing, walking bass, Rhodes,
  spazzole) — OVUNQUE nelle scene life-sim (menu, città, casa, negozi, lavoro,
  lobby), mai nei court. Il router centrale (SceneRouter) la riavvia a ogni
  cambio scena non-court: niente più città silenziosa.
- `squeak.wav`: squeak delle scarpe sul parquet sui cambi di direzione
  veloci, con rate-limit e pitch casuale.
- Palleggio sul terreno più presente (volume alzato); caos tifosi continuo
  per tutta la partita: bed della folla più alto + ondate casuali fitte.

## Impianto (solo partite vere; scrimmage = struttura senza persone)
- Spalti SOLO sul lato in fondo: 9 file di sedie in prospettiva (le sedie
  vuote si vedono), folla mista seduta/in piedi che segue la palla con la
  testa e si alza quando l'hype esplode; riempimento graduale a inizio match.
- Panchine e tavolo segnapunti come PARALLELEPIEDI solidi (faccia superiore,
  frontale, laterali); riserve sedute sopra la panchina, coach in piedi con
  lavagnetta, tre ufficiali seduti dietro il tavolo.
- Lato vicino: muro pubblicitario broadcast al posto della seconda curva.
- Verdetto del tiro NON più stampato sopra l'arco/la testa: il meter resta
  leggibile (feedback via colore + toast in alto).

## Coach e minuti
- Rotazione garantita: il coach ti manda in panchina almeno 2 volte a
  partita (inizio Q2 e metà Q3) oltre ai cambi per rendimento/stamina.
- In KitPicker scegli la DURATA DEI QUARTI prima della palla a due:
  1:30 / 2:00 / 3:00 (default 2:00).

## Localizzazione IT completa
- Sweep di 165 stringhe: negozi (libreria/poster, mobili, pet, fisio),
  appartamento (hotspot mobili, frigo, letto, doccia, TV, scrivania, pets),
  città, palestra, lavoro, drill, campo squadra, arena, kit picker,
  biblioteca. Tutto passa da Loc.t/Loc.tx con fallback graceful.

### Sim di regressione (scale 12)
```
1v1 x3 : 11-10, 10-7(TO), 7-11     5v5 : 15-12
```
SHA: c46916802f6ccd15c58c687e832763fca44296ad75369c64a9285544cce6d60e

## v2.0.1 (code 48) — round 6
- APK: /home/user/HoopCity-v2.0.1.apk — SHA-256 e80bd742dcf1bf4500098ff0ffee0859daaaacdced676bb6f8a170d9cfe137d4
- Fix freeze Arena lobby + Home & Hearth: erano PARSE ERROR GDScript (indent ArenaLobby.gd:53, `ifGame` FurnitureShop.gd:32) -> schermo monocrome e kill forzato. Gate parse per-file aggiunto alla routine.
- Fix audio su device: loop_mode impostato a runtime su WAV importati (loop_end=-1) silenziava i player (playing=false). Ora loop in import (`edit/loop_mode=1` per crowd_amb, music_loop, music_jazz, traffic_loop); scritture runtime rimosse da Sfx.gd. AudioProbe: music/crowd/traffic/sfx playing=true.
- Perf: folla+panchina su CrowdLayer ridipinto a ~8 fps (prima ogni frame, ~350 primitive); mobilio panchina nel layer statico; dettagli NPC ridotti sulle file lontane (sc<=0.8).
- Spalti: crowd_fill default 0 -> court solo/practice sempre vuoti; solo partite vere (1v1/fixture) riempiono (lerp ripristinato in _process, layer sopra static z0 vs -1).
- Shot meter: niente più toast qualità ("WIDE OPEN" ecc.); solo "+N" a canestro.
- Canestro: supporto FIBA (colonna imbottita spessa, base larga, braccio + contrappeso), piede al centro della linea di fondo.
- Loc: sweep.176-183 (sottotitoli lobby, nomi mobilio), common.phone; UIKit BACK/PHONE e ItemIcon/ApartmentRoom/FurnitureShop ora localizzati.
- Regressioni: parse 0/77, SceneSmoke OK, Sim 1v1 race-to-11 11-5/11-5/6-11, 5v5 full 22-20, AudioProbe tutti playing.
- Proof: docs/v21/ (match_crowd_fiba, solo_empty_stands, arena_lobby_it, furniture_shop_it).

## v2.0.2 (code 49) — round 7
- APK: /home/user/HoopCity-v2.0.2.apk — SHA-256 cdeb245ede41bf865499ffd0da92b12d26490047b169e97ecd55b06adaf67a9e
- Scritte qualità RIMOSSE ovunque: lo ShotMeter non stampa più WIDE OPEN/CONTESTED/RELEASE (pip colorato silenzioso al loro posto); SoloCourt lbl_mid solo "+N · xN"; drill "CONTESTED! x%d" -> "x%d".
- Perf spalti: folla CONGELATA nel layer statico (bake una volta, zero redraw in match); CrowdLayer 8fps resta solo per panchina (~15 NPC).
- Spalti arretrati e salienti: prima fila a -(H/2+150), step 30, 8 file; concourse vuoto tra dasher wall e prima fila; panchine mai più dentro la folla.
- Spalti POPOLATI solo per partite di campionato (crowd_on = is_fixture): solo court, scrimmage e 1v1 = spalti vuoti.
- Bordocampo: tifosi seduti di lato dietro entrambe le linee di fondo + 3 fotografi accovacciati con flash (sparkle) sui canestri fatti.
- Cheerleader ancorate a terra: piedi proiettati sull'apron con ombra di contatto (prima disegnate in coordinate raw = "volavano").
- Palla dopo la schiacciata: cade dalla retina al CENTRO del lato corto sotto il sostegno (lerp dunk_from->dunk_to in Ball.gd + SoloCourt).
- Rehab Lab: gear posseduto permanente in profile["gear"] {on, col hex, side}; visibile sul corpo (Avatar.draw_body): ginocchiera, cavigliera, fascia polso (lato DX/SX), calze compressive (gambe colorate); UI shelf con equip/remove, lato e 6 swatch colore; chiavi sweep.184-195.
- Regressioni: parse 0/77, SceneSmoke OK, Sim 1v1 11-3/4-11/5-12, 5v5 10-17, shot fixture/solo/gear in docs/v22/.

## v2.0.3 (code 50) — round 8
- APK: /home/user/HoopCity-v2.0.3.apk — SHA-256 063b122afe2ffcc02b7501402d20c84fbc4828e25e5d18caef40d47676dd2f7c
- Freeze Rehab Lab: era un PARSE ERROR (riga duplicata `func _buy_treat(` dopo il patch round 7). Gate per-file su TUTTI src+tools ora nella routine.
- Spalti: folla e catino RASTERIZZATI UNA VOLTA in texture (SubViewport UPDATE_ONCE + readback, fallback vettoriale headless): per frame = 1 quad testurizzato. Cheerleader throttle 15 fps.
- Tifosi con VOLTO verso il campo: capelli a calotta + occhi (prima sembravano di spalle).
- Movimento nel tiro in partita: air control 55% dopo il rilascio del jumper (come ai court solo); carica già mobile.
- Pump fake OVUNQUE: tap rapido su SHOOT anche nei court solo (indoor/outdoor), posa rise&settle.
- Palla post-schiacciata: cade al CENTRO della semicirconferenza (punto a terra sotto il ferro), partenza dalla mano sul ferro.
- Animazioni ferro (swish/iron) anche nei court solo indoor/outdoor (rim_fx su made/backboard).
- Telefono: rimosse le due X in alto (close dx + back home sx); si chiude toccando fuori dal telefono.
- Rimessa dopo canestro NON automatica (solo squadra umana, non 1v1): tutti si muovono, tu chiami il pallone (PASSA/TIRA); dopo 3 s passaggio automatico a un compagno. Hint "Chiamala! (tasto passa)" / sweep.196.
- Regressioni: parse 0/78, SceneSmoke OK, Sim 1v1 2-11/2-11/4-11, 5v5 9-13; shot docs/v23/.

## v2.0.4 (code 51) — Round 9
- Pump fake piantato: niente saltino, solo mani/avatar (Avatar.gd flag "fake", Player/SoloCourt).
- Gear Rehab Lab solo sul corpo dell'utente (gate `if acc else {}` in Avatar).
- Sostituzioni realistiche: l'utente esce camminando verso la panchina; il sub entrante attende a bordo campo finché chi esce non ha completato la camminata (meta "wait_sub"); camera segue la palla quando l'utente è in panchina o si simula, centro campo durante l'intervallo.
- Intervallo quarti 10s -> 7s con huddle: le squadre jogano verso i rispettivi lati panchina durante il balletto delle cheerleader (court.intermission), poi ripresa con rimessa: mai campo vuoto.
- Rimessa: chi rimette sta FUORI dal campo, dietro la linea di fondo (baseline_x = sign*(W/2+46)).
- Flash fotografi più evidente (halo+core+6 raggi, 0.34s).
- Arena indoor: anello superiore con folla a punti, jumbotron appeso al centro con cavi e schermi colorati, cluster casse sospesi sulle due metà (bake statico, draw dopo la folla); niente decorazioni sui campetti street.
- Squeaks più udibili ovunque (-8 dB, soglie taglio/atterraggio abbassate); vita da parquet nei campetti soli: squeak sui cambi di direzione, thud del palleggio ogni 0.42s, swish -6 dB, ferro -7 dB.
- Voci giocatori (TTS voice-00): 6 clip assets/sfx/voice_{defense,ball,shoot,pass,rebound,nice}.wav; trigger solo in partita con altri giocatori: "defense" pr>0.60 cd5s, "pass" pr>0.85 cd6s, "shoot" shot clock <5s una volta per possesso, esclamazione sul canestro 45%, rimbalzo sul tiro sbagliato 40%, "ball" sul toast chiama-passaggio. Da soli: solo squeaks+swish+palleggio.
- Regression: gate parse 0 errori per file; SMOKE OK; 1v1 --target 11 FINISHED (7-11, 6-11); 5v5 --full FINISHED 12-13; AudioProbe music/crowd/traffic/sfx true; shot Xvfb arena+solo ok (docs/v24/).
- APK: HoopCity-v2.0.4.apk, code 51, SHA-256 0ae85a3aca52cc4639ef5caecefc4f0c4dc7820d1449a6df3b871014d6f878cb, 27.237.480 byte.

## v2.0.5 (code 52) — Round 10 (risposte quiz round 9)
- Jumbotron LIVE: punteggio reale sui due schermi squadra, quarto + clock sulla fascia centrale; flash con anello espanso a ogni canestro, stella a 8 raggi sulle triple (draw vettoriale dinamico, polling score/clock in _process).
- Intervallo tra quarti 7s -> 5s; jog huddle 250 -> 300 px/s (arrivo al capannello entro il balletto).
- Feel: squash & stretch sui giocatori (stretch 0.11 allo stacco, compressione -0.13 all'atterraggio, recovery 0.85/s) applicato alle transform di disegno.
- Audio: bus "Crowd" dedicato; ducking -6 dB per 0.7s sotto le voci giocatori, poi restore.
- Voci confermate in inglese (scelta utente).
- Regression: gate parse 0 errori; SMOKE OK; 1v1 FINISHED 11-6; 5v5 --full 5 gare FINISHED (22-6, 12-14, 4-22, 19-13, 12-17); AudioProbe music/crowd/traffic/sfx true; shot jumbo live docs/v24/jumbo_live.png.
- APK: HoopCity-v2.0.5.apk, code 52, SHA-256 f9b709d18f430837e67dcefa76f0dd4d74931a5ab3152ac20eb70cf5baecba92, 27.241.576 byte.

## v2.0.6 (code 53) — Round 11: missaggio
- Misurati RMS dBFS di tutti i 34 wav: voice_rebound era a -40.7 (20 dB sotto le altre voci) -> normalizzato offline a -20.0 dBFS (gain 10.8, peak-safe) e re-importato.
- Tabella MIX in Sfx.gd (trim per asset applicati in play()): voice_defense +2, voice_nice +1, whistle/whistle_short -2, buzzer -3, beep -1.
- Voci a -1 dB (erano -4): urla ben sopra parquet e folla; squeak -8 -> -6.5 dB.
- Ducking folla sotto le voci confermato (bus Crowd, -6 dB 0.7s).
- Scelte utente round 10: jumbotron flash OK, intervallo 5s OK, focus = mix audio.
- Regression: gate parse 0; SMOKE OK; 1v1 FINISHED 12-5; AudioProbe music/crowd/traffic/sfx true.
- APK: HoopCity-v2.0.6.apk, code 53, SHA-256 6ebbd5052739f206d2a75cac95839a5125870fcf73dc6a5eb277326ab7388ae8, 27.245.672 byte.

## v2.0.7 (code 54) — Round 12: audio vivo + slider
- Jazz: watchdog in Sfx._process (life_want) — il letto jazz non muore mai nelle schermate vita; nelle FIXTURE entra come bed a -16 dB sotto la folla (scelta utente: sempre tranne 1v1 e scrimmage); 1v1/scrimmage/solo/Gym/Drill/TeamCourt fermano la musica (regola solo: squeaks+swish+palleggio).
- Voci rigenerate (voice-00) con urla doppie più aggressive: defense/ball/shoot/pass/rebound/nice; volume 0 dB, pitch 1.02-1.18, cooldown dimezzati (defense 2.5s pr>0.55, pass 3s pr>0.80, shoot clock<6.5, nice 55%, rebound 50%) → ritmo partita.
- Squeak: -3 dB, trigger più facili (speed>120, dot<0.70; solo dot<0.65, cd 0.14).
- Palleggio: bounce -6 → -2.5 dB (si sente finalmente il thud).
- Slider impostazioni nuovi: Voci e Folla (bus Voice e Crowd dedicati,Settings voice/crowd, Loc settings.voice/settings.crowd IT/EN); ducking folla ora relativo alla base impostazioni.
- Pool voci separato (4 player bus Voice); AudioProbe aggiornato a scan del pool.
- Toolchain ricostruita dopo wipe /tmp e .cache (JDK17 Adoptium, sdk 34, templates tpz).
- Regression: gate 0; SMOKE OK; 1v1 FINISHED 9-11; 5v5 --full 5×FINISHED (18-22, 22-14, 18-14, 10-25, 15-6); probe music/crowd/traffic/sfx true.
- APK: HoopCity-v2.0.7.apk, code 54, SHA-256 48b27b4fc39deef0f77b0d7085c01d094dd2e45dd031bb79ad1e1001f239650d, 27.327.592 byte.

## v2.1.7 (build 62)
- Palestra: `kind` ora passa id PIANI ("weights"/"cardio") a DrillScene — niente piu' fermo immagine (la stringa tradotta "pesi" non matchava nessun ramo).
- Folla: un solo campione ma presa piena 15.5 s con crossfade 1.2 s + respiro organico (micro onde di pitch/volume legate all'hype) — niente ripetizione percettibile.
- Palleggio: bounce1/2/3 ricomessi a 90 ms netti con lowpass 3.6 kHz (elimina la coda metallica "stonata"), pitch stretto 0.95–1.07.
- Rim-rattle leggibile: 35%, salto 340–430 vh (picco 30–50 px), shake 0.45, rim a −2.0 dB.
- Telefono: orologio GRANDE (68 px centrato) in cima alla home aggiornato in diretta + strip sempre live.
- Menu: logo con sfondo bianco rimosso (chroma-key 1.38M px → logo_t.png), card inchiostro con bordo arancio, tagline chiara.
- Musica città: aggiunto jazz #2 "Lonely in the Bar" (Mixkit 518, 86 s loop ADPCM); play_life() alterna i due brani.

## v2.1.6 (build 61)
- 1v1: CHECK solo sul tuo possesso; l'avversario si checka da solo dopo 0.9 s.
- Palleggio solo attack-onset (nessuna coda); fischi e voci eliminate dal match; folla = un solo campione (cheer/ooh solo hype).
- Rim-rattle 30% (poi potenziato in v2.1.7); orologio telefono in strip + live _process.

## v2.1.5 (build 60)
- Folla reale da Mixkit, bounce first-impact, squeak v3; MENU ripristinato nella riga di stato (il vecchio blocco non era mai migrato), z_index 100.

## v2.1.8 (build 63)
- RIM-RATTLE finalmente visibile: causa trovata — la palestra usa un motore di tiro separato da Court, quindi il rattle non poteva MAI uscire nei drill. Ora: 100% sui canestri ravvicinati in partita, 30% nel shooting drill, salto di 69–114 px sopra il ferro, fx dedicato (doppio anello bianco-arancio + scintille), shake 0.60, ferro a −0.5 dB, cattura allargata entro 48 px (il canestro resta valido dopo il pop).
- Contatto col ferro sui tiri sbagliati più presente (−3.5 dB, shake 0.32).
- Orologio telefono a CHIP scuro (strip + home grande centrato): leggibile su qualunque wallpaper; guardie .get() sui salvataggi vecchi. Geometria verificata in headless (probe: strip e home dentro il viewport, testi pieni).
- Orologio di gioco ANCHE nella barra in alto della città (chip accanto a MENU, live).
- Pulsante telefono: tolta l'emoji ("PHONE" a testo, regola niente emoji).

## v2.1.9 (build 64)
- Rim-rattle ANCHE nel court libero (SoloCourt): 30%, pop 69-114 px, fx "rattle", cattura allargata a 48 px. Ora il momento firma esiste ovunque: partita, 1v1, shooting drill, tiri liberi e court solo.
- Tolto l'orologio dalla barra in alto della citta' (richiesta utente: restano solo i chip dentro il telefono).

## v2.1.10 (build 65)
- Icona telefono VETTORIALE (Art.draw_icon "phone") in citta' e appartamento: via il testo "PHONE" e l'emoji 📱 — identica su ogni device (regola: niente emoji).
- Drill: tolta la COPIA della palla — dopo 0.22 s l'avatar riprendeva la palla in mano mentre il tiro volava ancora (il volo dura ~1 s): ora l'avatar ha la palla solo quando non e' in volo.
- SPIN MOVE = DOPPIO TAP sullo schermo (meta' destra, fuori da joystick/bottoni): ora funziona in 5v5, 1v1 E court libero (prima esisteva solo come doppio tap sul pulsante TRICK). Dedupe touch/mouse sintetico.

## v2.2.0 (build 66) — CONTENUTI A: obiettivi di partita
- Prima di ogni partita (5v5, scrimmage e 1v1) viene sorteggiato un OBIETTIVO individuale Duro (taglio richiesto dall'utente): 18+ punti, 5+ assist, 10+ rimbalzi, 3+ steal, 3+ stoppagi, 4+ tripli, 55% FG con 10+ tiri, double-double, zero perdite; nel 1v1: vinci tenendo l'avversario sotto 6, 3+ tripli, stoppagio, 2+ steal.
- Ticker live sotto il punteggio ("GOAL - PTS 12/18") che diventa verde al completamento, toast "+XP".
- Completamento = XP EXTRA nel post-game (40-60 XP per obiettivo; la busta base di Career non cambia). Verdetto finale su box score e risultato.
- Nuovo modulo puro src/core/MatchGoals.gd (testato headless); mai due volte di fila lo stesso obiettivo.
- Prossimi contenuti in coda: B statistiche stagione, C eventi carriera.

## v2.2.1 (build 67)
- Spin move: il doppio tap ora usa _input (vede i tocchi PRIMA della GUI) — non puo' piu' essere bloccato da bottoni/joystick; funziona anche tappeggiando sopra SHOOT/TRICK.
- Orologio telefono "NULL": causa = campi corrotti nel salvataggio (minutes/day null rompevano la formattazione). Ora: i valori nulli al load tornano default (SaveSystem), clock_string/daypart difensivi, PhoneUI senza accessi diretti a profile["day"].
- Nuovo suono palleggio: tre campioni Mixkit DIVERSI scelti per classificazione acustica (massima energia bassi = thump): 2083/2076/2096, attacco 100 ms, lowpass 3.1-3.3 kHz, zero coda.

## v2.2.2 (build 68)
- REGOLA METER (richiesta utente, verificata statisticamente: verde 300/300, giallo 151/300, rosso 0/300): VERDE = 100% sempre (anche contestato), GIALLO = 50/50, ROSSO = MAI. Vale nel match, nel court solo e nei drill.
- Animazione/suono coerenti: un tiro mancato non atterra mai dentro il ferro (clamp 30 px nel match; aim su fascia clang 44-52 px nel court solo e nei drill; rosso = airball corto/lungo). Niente piu' finti canestri o ferri muti.
- Palleggio a FREQUENZA COSTANTE: il ritmo non accelera piu' con la corsa (dribble_clock separato da anim_t) e il thud e' SEMPRE lo stesso campione alla stessa altezza (Sfx.dribble_thud -> bounce1 pitch 1.0); la rotazione bounce1/2/3 resta solo per i rimbalzi liberi.
- Schiacciata: parte SOLO dalla semicirconferenza sotto canestro (12 ft -> 4.5 ft, sia court solo che partite).
- Telefono: tolti i piccoli giorno/ora in alto nella striscia (resta la batteria); l'orologio e' solo quello grande della home.

## v2.2.3 (build 69) — CONTENUTI B: statistiche stagione
- App STATS del telefono ricostruita: bilancio W-L con % vinte, griglia medie (PTS/REB/AST/STL/BLK/TO), percentuali di tiro dal campo e dalle tre, CAREER HIGH stagionali, game log colorato (W verde/L rossa) con avversario, punteggio e voto.
- Nuovi dati persistenti nel profilo stagione: fgm/fga/tpm/tpa + high {pts,ast,reb,stl,blk}; il merge dei default riempie automaticamente i vecchi salvataggi (verificato).
- Career.apply_match_result accumula il tiro, aggiorna i career high e memorizza l'avversario nel game log.
- Probe headless: merge vecchi salvataggi OK, medie griglia OK (18.0 su 5 gare/90 punti), FG% 47%, vuota gestita senza crash.

## v2.2.4 (build 70) — CONTENUTI C: eventi carriera
- Nuovo modulo src/core/CareerEvents.gd: ogni 3-5 giorni di gioco (calibrazione utente) si accoda un evento che si apre come pannello all'arrivo in citta'. Frequenza normale, mix scelte/sfide, conseguenze LEGGERE.
- Scelte: sponsor sneaker (150€ vs rep+follower), fan da firmare (rep vs follower), filmstudio (XP vs energia).
- Sfide giocabili: BLACKTOP "3 canestri di fila" nel court solo (+120€ +20 XP) e ALLENATORE "3 PERFECT in palestra" (+80€ +30 XP); contatore persistente nel profilo, toast di avanzamento, pagamento automatico.
- Mai lo stesso evento due volte di fila; i salvataggi vecchi si agganciano da soli (merge default).
- Probe: accodamento OK (giorno 5 -> prossimo 8), pannello OK, pagature sfide OK (120/20 e contatore perfect3), smoke + 3/3 sim.
- Roadmap contenuti completata: A obiettivi (2.2.0) + B statistiche (2.2.3) + C eventi (2.2.4).

## v2.2.5 (build 71)
- Nuovo suono palleggio: i campioni Mixkit erano tutti "schiaffo" (centroide 1.3-5.3 kHz, nessun corpo) — per questo non convincevano. Nuovo bounce1 IBRIDO: attacco reale (2083) ribassato del 40% + tonfo sintetico 150->62 Hz + micro tap di mano, lowpass 1.3 kHz, decadimento naturale 230 ms (busta liscia 0.50->0.02). Riprodotto OVUNQUE a -9 dB (basso basso, come richiesto). Swish e stecca sul ferro: confermati presenti in tutti e tre i motori (match, court solo, drill).
- Sfide consegnate come voleva l'utente: quando accodato un evento-sfida arriva un MESSAGGIO nel telefono (Blacktop dal migliore amico, Coach Ellis per la palestra); quando entri nel court libero / in palestra un NPC ti parla con DIALOGO (nome, battuta, bottoni accetta/rifiuta). Piu' niente pannelli a sorpresa in citta' per le sfide (restano per gli eventi-scelta).
- Menu a sinistra rifatto: HERO con glow arancio pulsante dietro il logo, ombra portata, bob lento (il menu respira), arco da tre e strisce diagonali da parquet. Verificato: bob animato frame-per-frame.
- Probe: dialogo streak3 nel court OK, hero+bob OK, smoke OK, 3/3 sim.

## v2.2.6 (build 72) — AUDIO DELL'UTENTE (ricevuti via Google Drive)
- palleggio.mp3 (court indoor): selezione automatica del colpo piu' pulito con decadimento naturale (340 ms) -> nuovo bounce1, riprodotto ovunque a -9 dB. Sostituito l'ibrido sintetico: ora e' PALLEGGO VERO.
- freesound basketball-game (20.6 s): nuovo crowd_amb = IL TUO CAOS in loop 19 s (crossfade 1.2 s, mono 22 kHz). Un solo suono, come da regola.
- ambient ucc.mp3: nuovo court_amb = ambiente del COURT ESTERNO in loop 60 s (ADPCM 647 KB), player dedicato in Sfx (start_amb/stop_amb), parte solo all'aperto nel court libero e si spegne all'uscita.
- Probe: palleggio presente (0.34 s), folla 19 s in loop, ambiente 60 s attivo all'aperto e spento all'uscita; smoke OK, 3/3 sim.

## v2.2.7 (build 73)
- Palleggio: piu' LENTO (ritmo -28%, non accelera mai) e piu' DELICATO (-11.5 dB) in ogni ambiente, sempre col campione reale dell'utente.
- Suoni dei tasti RIMOSSI (TouchButton + UIKit): il gioco parla con il campo, non coi click. Resta solo il blip di test nel cursore volume delle impostazioni (e' il campione di ascolto, non un click).
- Court esterno = PARCO: via il fondo azzurro, ora erba (fondo verde naturale) con panchine in legno e cestini in primo piano sul bordo in basso.
- Spin move: ora ANCHE nel court libero con la rotazione completa del corpo (yaw, passa di schiena alla telecamera) come nello scrimmage/1v1.
- Batteria del telefono REALE: si scarica col tempo (~0,3%/min, rossa sotto il 20%), etichetta con percentuale vera. Si ricarica lavorando alla scrivania di casa: 3 lavori (Correzione bozze +35%, Contabilita' aritmetica +30%, Consegne +20%) con pagamenti diversi. Probe: scarica 100->82 in 1h, ricariche OK, etichetta OK.

## v2.2.8 (build 74)
- Consegne in bici RIMOSSE (guadagno facile): sostituite da SMISTAMENTO PACCHI, gioco di MEMORIA vero (codice a 5 cifre per 2 s, poi ricompilarlo nell'ordine giusto tra 6 cifre con esca; 4 pacchi, paga solo se ricordi).
- Telefono a 0% = SCHERMO NERO inutilizzabile (contorno batteria vuoto appena accennato, nessuna app, solo chiusura). Verificato con probe.
- Sponsor/sfide in citta': FINITI i pannelli che uscivano dallo schermo — ora TUTTO arriva come DIALOGO NPC (bolla in basso sempre visibile) + notifica nei messaggi per le sfide.
- Schiacciata: suono SWISH quando la palla entra, in ogni ambiente (match e court libero).
- Ombra realistica nella schiacciata: resta A TERRA, scorre al centro della semicirconferenza sotto il ferro e DIVENTA PIU' GRANDE salendo (match e court libero); niente piu' ombre che volano col corpo.
- Menu: tolta la striscia verde in basso (era il clear color del parco che filtrava — ora sfondo inchiostro omogeneo), logo riposizionato (centrato a sinistra, piu' in basso), label versione aggiornata (diceva v2.1.0!).
- FISCHI e "tick tick" ELIMINATI dallo scrimmage: zero whistle in Court.gd; squeak sintetico disattivato (i trigger aspettano il VERO suono scarpe dell'utente — il file su Drive risulta assente, in attesa di ri-upload).

## v2.2.9 (build 75)
- SQUEAK REALE dell'utente (shoes squeak.mp3): tagliati i 3 stridori piu' puliti e isolati (340 ms ciascuno, da 3.58s / 4.45s / 6.93s) -> squeak1/2/3 con rotazione e pitch 0.95-1.12. Raro e discreto (cooldown 0.55 s, -2 dB) come da gusto dell'utente. Trigger gia' attivi in partita (2 punti) e court libero (1). Il "tick tick" sintetico e' definitivamente fuori.

## v2.2.10 (build 76) — HOTFIX mitragliatrice
- CAUSA: nella 2.2.8 il swish della schiacciata nel court libero era finito (per una sostituzione alla "prima occorrenza") FUORI dalla macchina a stati del dunk -> suonava OGNI FRAME: 288 swish in 5 secondi = il "suono mitragliatrice" all'ingresso nei court.
- FIX: il swish ora scatta UNA sola volta dentro la transizione rise->throw-down (al momento dello slam). Verificato con strumentazione Sfx: court libero 5 s = 12 palleggi ritmici, ZERO swish; ingresso partita 5 s = 2 soli beep (shot clock), nessuno spam.

## v2.2.11 (build 77)
- SCHIACCIATA RIPRISTINATA: il raggio a 4.5 ft era cosi' stretto che can_dunk non scattava quasi mai (riprodotto e diagnosticato: a 5.3 ft risultava false). Ora si parte da 6.5 ft = la semicirconferenza sotto canestro, in partita e nel court libero. Probe: rise -> hang -> canestro segnato.
- Ombra della schiacciata piu' sobria (crescita limitata, non domina piu' la scena).
- Palleggio ANCORA piu' lento (ritmo -45% rispetto alla base) e piu' basso (-13.5 dB).
- Squeak piu' presente: cooldown 0.55 -> 0.32 s e suona SEMPRE sui trick (crossover/behind/stepback/hand-switch/hesi) e sulla spin move (doppio tap), oltre ai cambi di direzione veloci gia' presenti.

## v2.3.0 (build 78) — PATCH v2.3 (dall'altra AI, revisionate e integrate)
- EVENTI CARRIERA ESPANSI (da 5 a 13): intervista hot streak (3 vittorie di fila), coach su cold spell (3 sconfitte), momento virale (28+ punti), cena di squadra, mentore veterano, sponsor Volt Athletics (rep 25+), scout esterno (rep 18+), SMISTAMENTO con soldi veri "city game" (sfida streak5: 5 canestri = 250 euro), evento INFORTUNIO con scelta (2 giorni stop vs rischio 30% grave 5-14 giorni) e recupero giorno per giorno con bonus energia.
- Gating eventi per reputazione/forma recente: _eligible_pool() filtra per rep, streak vittorie/sconfitte, punti nell'ultima partita; mai l'infortunio se gia' infortunati. Verificato: a rep 0 escono solo eventi base, sponsor_big arriva a rep 30.
- SFIDE via messaggio confermate anche per streak5; offerta NPC nel court FIXATA (la patch confondeva id evento "city_game" con id sfida "streak5": non sarebbe mai stata offerta).
- CAREER: forma recente (rolling 3 partite) che colora le reazioni social (8 rami), paga scalata alla reputazione (fino a x2.2), +1 evento in coda dopo ogni partita.
- Corretto nell'integrazione: niente emoji nei toast, niente doppio conteggio PERFECT dal voto drill, default injury_* per i salvataggi vecchi.
- Probe: gating OK, infortunio 2->1->0 con bonus energia OK, forma OK, streak5 offerta+pagamento OK, smoke OK, 3/3 sim.

## v2.4.0 (code 79) — 2026-09-17
**Finta nei match (regola dei passi)**
- Durante la finta la palla resta IN MANO al petto (come i court solo), niente palleggio.
- Dopo la finta la palla resta raccolta: puoi SOLO passare o tirare. Un input di corsa deciso (~0.2s) = "Traveling!" + palla all'avversario (stesso flusso del shot clock violation).
- Fuori partita (court liberi) la finta resta libera: riparti e ri-palleggi.
- Fix: `track.size.h` → `.y` in `_draw_timing_bar` — l'errore di parse avrebbe rotto TUTTA la palestra.

**Iron Gym**
- Zone verdi più ampie (box_jump 0.34/0.20, med_slam 0.32/0.18, squat 0.28/0.13, power_clean 0.24/0.11, deadlift 0.26/0.13) e tempi più lenti: la pliometria non è più un click impossibile.
- Nuova barra di timing sotto la traccia (zona verde pulsante + cursore) su tutti gli esercizi coi pesi.

**Estetica & consumi**
- 8 colori capelli (nuovi: paglia, ramè, grigio, biondo platino) + 5 stili (normale, rasato, afro, trecce, ricci) nel creator.
- 1 cibo nuovo (fruit) + 4 drink (espresso, lemonade, iced tea, mate) — DRINKS=18. (sushi/salmon/burrito già esistevano: rimossi i duplicati.)
- Frigo con CATEGORIE (Tutto/Cibo/Bevande) come lo shop: le liste non escono più dallo schermo; colonne calcolate col margine di sicurezza anche nel wardrobe.

**Varie**
- Label consegne bici onesta ("4 codici a memoria" invece di "nessun quiz").

Test: import 0 errori; smoke OK; SimRunner 3/3 FINISHED; probe travel (finta→lock, pass lecito, corsa→turnover), gym (zona 0.34, press OK), hair/items/frigo tutti verdi.

## v2.5.0 (code 80) — 2026-09-17
**Bug routing & regole**
- Gym → Team Court → court solo apriva l'OUTDOOR: `last_building` lo scriveva solo la città. Ora ogni edificio imposta il proprio id (il solo court indoor col parquet arriva da qualunque percorso).
- 1v1: zero rimesse — loose ball, rimbalzo fuori e fine liberi terminano tutti in CHECK-BALL (ai 5v5 resta la rimessa).

**Capelli & menu**
- Gli NPC (avversari, compagni, passanti, difensore del drill) hanno ORA il proprio taglio pesato su 6 stili: non copiano più quello scelto dal giocatore. Anche colore/muscoli restano personali.
- Creator: i 4 bottoni "look" sono una griglia 2×2 compatta — prima la fila da 4×178px usciva dalla colonna e finiva sotto l'anteprima.
- Nuovo stile 6: DREADLOCKS lunghi (per il giocatore e per gli NPC).
- Menu: versione letta da Game.VERSION (non più "v2.2.8" scritta a mano).

**Trick & spin**
- Nuovo trick TRA LE GAMBE ("THROUGH THE LEGS"): la palla scende quasi a terra sotto la gamba e risale sull'altra mano; busto abbassato.
- Da fermi TRICK alterna crossover / tra le gambe (prima sempre la stessa palla).
- Spin move: yaw con plateau — il corpo resta di schiena gran parte della rotazione, si VEDE il 360.
- BACK/PHONE negli edifici: più piccoli, staccati e spostati sotto la barra di stato (prima si sovrapponevano ai chip e tra loro).

**Match HUD**
- Ticker obiettivo/sfide spostato a destra sotto i bottoni: non copre più il punteggio.

**Shop**
- Fit & Kicks e Home & Hearth: scaffale in SCROLL verticale con colonne calcolate dallo spazio reale — niente più cibo tagliato e gli item nuovi (frutta, espresso, lemonade, iced tea, mate) sono raggiungibili in fondo alle liste.

**AI avversaria (1v1 e scrimmage)**
- Skill legata a rep/livello: la difficoltà cresce con la carriera.
- Difesa: gap più stretti (58-66px), close-out dentro l'arco a 42px, contest più frequenti (fino al 78%), rubate più vive, deny sui tagli più aggressivo.
- Memoria adattiva: chi ripete sempre lo stesso trick viene letto — il difensore esperto da terra e allarga invece di farsi shook ogni volta.
- Attacco: tiro più selettivo (tre con pressione <0.52-0.70), passaggio sotto pressione più rapido, pump fake nell'1v1 prima del tiro, tiro più pulito per mani capaci (σ 0.028-0.13).
- Rimbalzo: anticipa la caduta e fa scatolamento tra l'avversario e la palla.

**Fisico palestra (richiesto)**
- Ogni ripetuta coi pesi costruisce "muscle" (0-1): spalle e braccia si allargano davvero in palestra, nei match e nelle anteprime.

Test: import 0 errori; smoke OK; SimRunner 3/3 FINISHED (avversario ora segna di più: 1-3/1-2/1-3 vs 0-2 storico); probe routing/capelli/tra-le-gambe/spin/passi (5v5 e 1v1 con CHECK)/UI edifici tutti verdi.

## v2.6.0 (code 81) — 2026-09-17
**AI ancora piu' forte (richiesta del test)**
- Skill base 0.40->0.97, gap difesa 52-76px, close-out interno a 38px, contest fino all'86%, rubate x1.7, sigma di tiro 0.024-0.12.

**Carriera profonda: CONTRATTI**
- Ogni partita ufficiale paga ora anche lo STIPENDIO settimanale del contratto (140$ iniziali, 10 gare).
- Alla scadenza: l'AGENTE scrive e in Arena > "Contratto & goals" arrivano le OFFERTE: rinnovo col club attuale + (da rep 40) 2 club che puntano su di te, con bonus alla firma e stipendio crescente con la rep.
- Accettare un trasferimento CAMBIA SQUADRA (maglia, colori, roster avversari coerenti) e apre un contratto da 12 gare.

**Carriera profonda: OBIETTIVI STAGIONE**
- 3 traguardi generati sulla rep: vittorie (6-11), punti totali (120+), partita da 20+ punti.
- Progresso letto dalle statistiche reali di stagione; premio in $, XP e rep + messaggio del coach quando li centrati.

**Pannello Arena**
- Nuovo bottone "Contract & goals": contratto, stato scadenza, offerte da firmare, obiettivi con progresso.

Test: import 0 err; probe contratto 10/10 verdi (stipendi, scadenza, 3 offerte, trasferimento, obiettivi, premi); SimRunner 3/3 FINISHED con punteggi vari 2-0/1-2/2-0; smoke OK.

## v2.6.1 (code 82) — 2026-09-18 — HOTFIX
**Compatibilita' Galaxy A13 ("app non compatibile")**
- Causa: APK con sole librerie arm64-v8a. Il Galaxy A13 4G (Exynos 850) su molti firmware gira userspace 32-bit: nessuna lib compatibile -> il sistema rifiuta l'installazione.
- Fix: build DUAL-ABI (armeabi-v7a + arm64-v8a). APK un po' piu' grande (~+10 MB) ma installabile su qualunque telefono ARM.

**Audio palleggio coperto dal pubblico**
- Il file utente del palleggio (-13 dB) stava 5-7 dB SOPRA ... no, SOTTO il letto della folla (-6..-8 dB): mascherato.
- Ora: nel match il letto scende a -14..-8 dB e il palleggio sale a -11.5 dB SOLO quando c'e' pubblico (da solo resta -13.5 come approvato).

**"Telefon" -> "TELEFONO"**
- Il clip_text del bottone ristretto in 2.5.0 tagliava l'ultima lettera: PHONE allargato a 156px.

Test: import 0 err; probe audio (solo -13, con folla -11, letto match -13.5) verde.

## v2.7.0 (code 83) — 2026-09-18
**FINE STAGIONE & PLAY-OFF**
- La regular season dura 60 giorni (20 gare): al termine c'e' il BILANCIO — premio societa' (300$ + 60$/vittoria) e archivio stagionale.
- Con 8+ vittorie si entra nei PLAY-OFF: quarti -> semifinale -> FINALE, avversari rinforzati (+8 rating, cervello +0.05), premi 250/400/1500$.
- Vincendo la finale: TROFEO (contatore visibile), +5 rep, +400 XP, messaggi di festa, e si apre la nuova stagione.
- Sconfitta/eliminazione o stagione sotto soglia -> nuova stagione immediata: archivio, calendario rigenerato (nuovo seed), obiettivi e statistiche a zero, giorno 1.
- Il bottone PLAYOFF appare in Arena solo quando si e' vivi; l'agente e il coach avvisano in chat.

**AGENTE piu' vivo**
- Estensione contratto in corso: da 4 gare alla scadenza si puo' estendere +8 gare con ingaggio rinegoziato sulla forma recente (una volta per contratto).
- "Rumore di corridoio": dopo partite da 22+ punti con rep 30+, i club chiedono di te in chat (throttle 6 giorni).

**Fix**
- end_regular_season non qualificata ora APRE la nuova stagione (prima il gioco restava senza partite).
- Archivio non piu' duplicato tra chiusura e inizio stagione.

Test: probe ciclo completo verde (12 gare -> playoff -> scudetto -> stagione 2; eliminazione -> stagione 3; no-playoff -> stagione 4 immediata; estensione; interessi+throttle); smoke OK; 3/3 simulate FINISHED.

## v2.8.0 (code 84) — 2026-09-18
**Salto rapido (richiesta test)**
- Impostazioni > bottone "TEST · Salta alla prossima gara": porta il giorno alla gara successiva (ore 09:00), con energia >=80 e batteria >=80. Se c'e' un PLAYOFF in sospeso non salta: punta all'Arena.
- Se il giorno e' oltre la fine stagione, chiude prima la regular season (o apre i playoff) e poi salta.

**Palmares nel telefono (richiesta)**
- My Card > sezione PALMARES: trofei vinti, stagione in corso e righe per ogni stagione archiviata (V-S, punti totali, high game).

Test: probe salto (giorno gara, energia/batteria, mattina 09:00, playoff pendenti) verde; import 0 err.

## v2.8.1 (code 85) — 2026-09-18
**Il pubblico ora e' la TUA registrazione**
- Il letto del folla nei match (scrimmage, 1v1, playoff) usa la registrazione utente da 60s (finora solo ambiente del court esterno): loop continuo senza seam; il corto loop Mixkit resta come riserva.
- Livelli invariati (delicati, come approvato): letto -14..-8 dB nel match, palleggio -11.5 col pubblico.

**Pulizia workspace** (nessun dato necessario rimosso)
- Eliminati: build/ intermedia dell'export (~55 MB), cache import .godot/ (rigenerabile con --import), vecchi APK sostituiti.
- Conservati: tutti gli asset audio (incluso il file utente), reference/, BUILD_NOTES, toolchain.

## v2.8.2 (code 86) — 2026-09-18 — correzione audio spalti
- L'utente chiarisce: la registrazione 60s (court_amb) e' l'ambiente del COURT OUTDOOR, NON il caos degli spalti. Il vero audio di folla non e' mai arrivato (era nel WeTransfer illeggibile).
- Revert: gli spalti tornano al loop stock in attesa del file giusto. Aggiunto gancio: appena metteremo crowd_user.wav in assets/sfx, verra' usato AUTOMATICAMENTE come folla dei match (loop seamless).
- court_amb resta solo sull'outdoor.

## v2.8.3 (code 87) — 2026-09-18 — AUDIO UTENTE (via Google Drive)
**Spalti dei match = caos della folla (phillyfan972, freesound #412161)**
- crowd_user.wav (59.6s, mono 22 kHz, ADPCM): loop continuo per TUTTO il match (scrimmage, 1v1, playoff). Volumi invariati (letto -14..-8 dB, palleggio -11.5 sopra la folla).

**Court INDOOR = musica ritmica (Vaitsez "Basketball Highlights", Pixabay)**
- music_rhythm.wav (3'12", mono 44.1 kHz, ADPCM): parte SOLO nel court solo indoor (parquet), in loop; esce dal court e si ferma. Mai in citta', mai outdoor, mai nei match.
- L'outdoor resta con l'ambiente utente 60s e NESSUNA musica.

Crediti aggiunti in assets/sfx/CREDITS.md. Originali dell'utente conservati in /home/user/utente_audio/.

Test: probe A1-A4 tutti verdi (folla utente in loop; ritmica solo indoor; stop all'uscita; outdoor silenzioso con ambiente); import 0 err; smoke OK.

## v2.9.0 (code 88) — 2026-09-18 — DIFFICOLTA 1v1
Le due scappatoie segnalate (trick->schiacciata franca, finta->salta->segno) sono chiuse:
- TRICK: i difensori AI con skill alta recuperano l'equilibrio quasi subito ("shook" ridotto fino al 68%).
- FINTA: chance di morso scalata sulla skill (fino a -62%) e disciplina progressiva: dopo il primo morso in un'azione le finte successive prendono pochissimo; se morde, il recupero scende da 0.55s a 0.26s.
- SCHIACCIATA: il difensore SCATTA da dietro quando attacchi il ferro (inseguimento con cooldown) e nell'1v1 arriva al contest anche da 165px.
- GAP 1v1: il bravo si ascuga ancora di piu (gap -20%).
- Verifica dal vivo: a skill 0.97 le finte mordono 2 volte su 24 (prima circa 1 su 2); il difensore ora RUBA la palla se corri addosso dopo la finta (corretto: non e' un bug della regola passi, e' la difesa che vive).

Test: probe H1-H4 verdi; SimRunner 3/3 FINISHED; smoke OK; import 0 err.

## v2.10.0 (code 89) — 2026-09-18
**Selettore di DIFFICOLTA (Impostazioni > DIFFICOLTA)**
- FACILE / NORMALE / DURO / INCUBO. Moltiplica la skill AI e NE ALZA IL MINIMO: con salvataggio nuovo skill passa da 0.42 (Normale) a 0.72 (Incubo) — niente piu reclute per chi testa con profili freschi. Vale dalla partita successiva.
- FERRO PROTETTO: a difficolta alte le finite sotto canestro rendono meno (open layup 0.76 -> 0.69 su Incubo) e il contest pesa fino al 45% in piu.
- INSEGUIMENTO potenziato: trigger a 320px, cooldown 0.32s, contest al ferro fino a 185px.

**Nuove mosse offensive**
- EUROSTEP: in area, correndo a canestro, TRICK diventa eurostep (scatto laterale + cambio mano, toast "EUROSTEP").
- FADEAWAY: se al rilascio stai indietreggiando dal canestro il contest pesa il 38% in meno ma il timing peggiora del 15% — trade-off reale.

Test: probe D1-D5 verdi (skill per difficolta, euro, ferro protetto); SimRunner 3/3; smoke OK; import 0 err.

## v2.11.0 (code 90) — 2026-09-19
**PERFORMANCE su dispositivi datati (Galaxy Tab S / Android 6)**
- AUTO-DETECT nel menu: dopo 2.5s sotto le ~42 fps passa a 30 fps e spegne i decori (una volta, toast "Modalita performance attiva"). Il toggle 60/30 resta in Impostazioni.

**1v1: tiro SBAGLIATO = PALLA VIVA**
- Fix importante: dopo un tiro sbagliato si gioca il RIMBALZO (palla al piu vicino, "Palla viva!") — prima finiva ingiustamente in check quando nessuno era sotto il ferro. Il check resta solo dopo i PUNTI.

**INCUBO davvero incubo**
- Skill floor 0.80, mult 1.28; gap 1v1 ancora -8%; rubate +30%; contest al ferro fino a ~203px.

**GUADAGNI in percentuale per difficolta**
- FACILE 70% - NORMALE 85% - DURO 100% - INCUBO 125% (stipendi, premi, obiettivi, bonus firma: tutto). Le spese non scalano. Hint aggiornato in Impostazioni.

Test: probe P1-P5 verdi; SimRunner 3/3; smoke OK; import 0 err.

## v2.12.0 (code 91) — 2026-09-19
**1v1: INCUBO fa davvero male**
- Nel duello l'avversario e' sempre un gradino piu cattivo (skill +0.04, aggression +0.05) e a INCUBO pesca di braccio i tuoi trick (6% a mossa se ti sta addosso).
- La difficolta scelta SI VEDE nell'intro di OGNI partita ("Difficolta INCUBO" in rosso da DURO in su): niente piu dubbi che valga anche nell'1v1.

**ATERRAGGIO da dunk: polvere e tonfo**
- slam_fall impostato da do_dunk: alla caduta dopo la schiacciata la polvere e' GRANDE (10 nuvolette, 0.7s, spread 78px), squash del corpo -0.18 e suono sordo del tonfo ("body" -6dB).

**Segreto al posto del bottone TEST**
- Rimosso il bottone TEST dalle impostazioni. Ora: 5 TAP RAPIDI sul logo nel menu principale = salto alla prossima gara (la funzione e' solo tua; nessun riferimento in giro).

Test: dust D1/D2 verdi, segreto skip giorno 42, intro INCUBO trovata, SimRunner 3/3, smoke OK, import 0 err.

## v2.12.1 (code 92) — 2026-09-19 — PERFORMANCE tablet vecchi
- MSAA 2D DISATTIVATO di default (costo enorme su GPU 2014 a schermi 2560x1600, beneficio quasi nullo su questo stile).
- lowgfx (auto + toggle in Impostazioni > Prestazioni): fisica 30Hz (CPU dimezzata), viso dettagliato/tagli capelli/stance arc/polvere ridotti, folla a 3fps, MSAA off.
- AUTO-DETECT anche IN PARTITA: se dopo 4s live le fps sono <25, attiva tutto da solo con toast (prima c'era solo nel menu).

## v2.13.0 (code 93) — 2026-09-19
**IL BUCO dell'1v1 chiuso: l'AI ora salta sui DUNK**
- Causa della facilita': la schiacciata non e' un "gather" di tiro, quindi il difensore NON saltava mai a contrastare un dunker. Ora reagisce al dunk in corso: NORMALE 55% circa, DURO 74%, INCUBO 92% (probe: 18/20 salti a Incubo, 11/20 a Normale).
- Poke sui trick a Incubo: 6% -> 10% (raggio 68px).

**Polvere anche nel court SOLO (indoor e outdoor)**
- Alla caduta dello slam: polvere grande 0.7s + tonfo "body", identica ai match. Rispetta lowgfx.

**Performance (senza toccare il gameplay)**
- Cheer squad ferma in lowgfx; sfondo del menu ridisegnato 1 volta su 4 in modalita performance.

Test: S1 dust solo ✓, S2/S3 dunk-react 18/20 vs 11/20 ✓, SimRunner 3/3, smoke OK, import 0 err.

## v2.14.0 (code 94) — 2026-09-23 — BATCH: Reverse+Post moves & Premiazioni
**Round 1 — nuove mosse (voste scelte: reverse + post moves)**
- REVERSE LAYUP: lanciato sotto canestro e scatti VIA dal ferro (velocity opposta, entro 8ft): contest x0.55, timing +20%, popup "REVERSE".
- HOOK SHOOK: spalle al canestro entro 12ft: il tiro archia SOPRA il difensore, contest x0.45 ma timing +30%, popup "HOOK". (Serve davvero essere di spalle: il probe conferma che guardando il ferro non parte.)
- DROP STEP (post move): spalle al ferro entro 12ft -> scatto attorno al difensore (burst laterale + verso il ferro), cambio mano, via in layup. Toast "DROP STEP".

**Round 2 — premiazioni & festa scudetto**
- FINE STAGIONE: MVP (12+ vittorie e 20+ ppg: +800$, +3 rep, messaggio del COACH) e CAPOCANNONIERE (24+ ppg: +500$, +2 rep, messaggio del BEST). Minimo 8 partite. I premi restano nel TELEFONO > My Card (palmares sopra l'archivio stagioni).
- SCUDETTO: il primo rientro in citta' e' una FESTA: pannello "CAMPIONI!" con trofei/stagione, +250 followers (una volta sola).

**FIX (scoperto validando)**
- Pedoni: il tinto notturno moltiplicava TUTTO per un Color, anche "muscle" (float) e hst (int): errore spam a ogni frame di ogni passante in citta' (costo fps). Ora solo i Color si attenuano.
- Festa: il pannello non svuota piu' il flusso _ready della citta' (rischio schermo nero senza flag).

Test: MovesProbe M1 reverse ✓ M2 hook ✓ M3 dropstep ✓ (burst 314 = 290/120 esatto, cambio mano) M4 premi ✓ (+1300$/+5rep, 2 premi) M5 festa ✓ (pannello+flag), combo match+citta' 0 errori script, SimRunner 3/3 FINISHED, smoke OK, import 0 err, aapt 94/2.14.0 dual-abi.

## v2.15.0 (code 95) — 2026-09-23 — STENZATE VERE + BOTTONE POST
**La difesa ora blocca davvero (i salti a tempo pagano)**
- Prima il sistema stenzata esisteva ma era quasi invisibile: 88px, apex strettissimo, coeff bassi, e il dunk si bloccava al 4-42% fisso. Risultato: la difesa saltava e la palla ENTRAVA UGUALE.
- Ora: raggio 120px, apex perdonoso (0.30-1.25), coeff 0.95, cap 78%. Il salto della FINESTRA dura 1.15s (copre meter lento e tutta la risalita del dunk).
- Difficolta' SOLO quando l'AI difende l'utente: x0.75/0.95/1.15/1.35. L'utente che salta a tempo sull'AI blocca con la sua alone timing (nessuna penalita' diff).
- Dunk al ferro: block/140 (cap 55%) x diff 0.80/1.00/1.20/1.40, con popup BLOCK! + shake. Probe: difensore block=90 incollato = 6/12 dunk stenzati.
- Probe matematico: AI a tempo su utente (block 80, 60px, apex) ~32/60 a Normale; utente su AI ~14-19/60.

**BOTTONE POST (le mosse ora si Vedono)**
- Nuovo bottone POST in attacco: 1v1 sempre (slot PASS), 5v5 entro 14ft al posto del P&R. Mette le spalle al canestro (popup "POST", velocita' x0.6 da back-down, facing bloccato sul ferro contrario).
- Da POST: SHOOT = hop indietro automatico + FADEAWAY (oltre 9ft) o HOOK (sotto 9ft, popup visibile anche sul fade normale). Niente auto-dunk da post (si esce con il secondo tap).
- Da POST: TRICK = DROP STEP a qualunque distanza: burst attorno al difensore, cambio mano, rientro nel post spento e girato verso il ferro.
- FADEAWAY ora ha popup anche fuori dal post (la terza branca della famiglia era muta: per questo "non si vedeva").
- Prima volta in post: toast spiegazione. Auto-uscita oltre 16ft o senza palla.

Test: V215 P1-P5 post ✓ (entrata/spalle/fade/hook/dropstep), B1/B3 stenzate ✓, R1 rim 6/12 ✓, SimRunner 3/3, smoke OK, import 0 err, aapt 95/2.15.0 dual-abi, APK firmato (apksigner verify OK — nota: serve JAVA_HOME + tmpdir su /home perche' /tmp e' un tmpfs da 1GB).

## v2.15.1 (code 96) — 2026-09-23 — POST anche nel court solo + scopribilita'
- Feedback form: stenzate GIUSTE, Incubo GIUSTA, ma il POST "non si attiva".
- Causa: il court solo (dove si provano le mosse) NON aveva POST/drop step: tutto Modalita' POST era solo in partita.
- COURT SOLO: bottone POST (gold, sopra TRICK). Da post: velocita' x0.6, spalle bloccate al ferro; TIRA = hop indietro + HOOK! (<9ft) o FADEAWAY! (oltre, etichetta sul risultato, soglia misurata PRIMA dell'hop come nel match); TRICK = DROP STEP (burst laterale+ferro ~103px, cambio mano, uscita dal post); niente auto-dunk da post. Il tap post viene rifiutato mentre la palla e' viva (come il resto).
- MATCH: in 5v5 il bottone POST ora compare entro 18ft (era 14); hint "una volta sola" quando prendi palla in area (toast POST: TIRA = fade - TRICK = drop step).
- Probe: SoloPostProbe S1-S5 verdi (post/spalle/dropstep 103px/FADEAWAY/HOOK), V215 regressione OK, SimRunner 3/3, smoke OK, aapt 96/2.15.1 dual-abi, firmato.

## v2.16.0 (code 97) — 2026-09-23 — AUDIO OVUNQUE + FADE ANIMATO + COMBO
**Suoni dei court solo ovunque (1v1 e scrimmage)**
- Il palleggio (thud delicato bounce1) in partita era coperto dal letto di folla: ora sale a -9dB quando c'e' folla (nei court solo resta -13.5). Lo squeak era gia' lo stesso ovunque.
- CAOS ARENA rimesso (richiesta): il letto di folla nel match era stato abbassato di 2dB in una patch passata; ora torna ALTO: -11..-4 dB con hype (prima -14..-8). Gli spalti si sentono in 1v1, scrimmage e playoff (crowd_user.wav 60s in loop + respiro/swell organici).

**Fadeaway realistico (animazione)**
- Nuova animazione FADE: durante il follow-through il torso si archia INDietro (lean_back fino a 0.16*h, decresce in 0.55s). Si attiva su ogni rilascio "andando via" dal ferro (post hop, combo, contropiede).

**COMBO di pulsanti (nuove mosse)**
- TIRA + stick indietro (via dal canestro) al rilascio = FADEAWAY con hop indietro automatico e popup.
- TRICK -> TIRA entro mezzo secondo = PULL-UP (popup, timing +10%).
- Gia' presenti: doppio tap TRICK = SPIN, stick su/giu/lati = behind/hand switch/stepback, POST = fade/hook/drop step.

Test: V216 F1-F4 verdi (fade_anim, combo fade, pull-up, folla -7dB), SoloPost + V215 regressione OK, SimRunner 3/3, smoke OK, import 0 err, aapt 97/2.16.0 dual-abi, firmato.

## v2.16.1 (code 98) — 2026-09-23 — CAOS ARENA VERO + fade piu' marcato
- Feedback: audio "non cambiato" e fade "debole".
- CAUSA TROVATA: i CAMPIONI di tifo (crowd_cheer, crowd_cheer2, crowd_ooh) erano STATI TOLTI dalla lista SFX_NAMES nella 2.8.3 (quando e' entrato il letto utente): esistevano nei file ma non venivano ne' caricati ne' esportati. Il "caos" vero era quello.
- Ripristinati: canestro = crowd_cheer2 (35% whistle), canestro normale = crowd_cheer, ooh = crowd_ooh — SOPRA al letto (solo in partita). Il letto resta alto (-11..-4).
- FADE piu' marcato: lean 0.16h -> 0.30h, durata 0.75s, hop 300 (era 250). Popup famiglia (REVERSE/HOOK/FADEAWAY/PULL-UP) ora GRANDI.
Test: V217 A1-A3 OK, V216/SoloPost regressione OK, SimRunner 3/3, smoke OK, import 0 err, aapt 98/2.16.1 dual-abi, 12 voci crowd nel pack, firmato.

## v2.17.0 (code 99) — 2026-09-23 — PARITA' TOTALE court solo <-> partita
**Stessa palla**
- Colori/cuciture della palla del match IDENTIFICI a quelli del court solo (tinta chiara 0.95/0.55/0.15, cuciture 0.35/0.18/0.07): prima era piu' scura.
- Stesso RITMO di palleggio: un rimbalzo ogni ~0.42s (nel match era 0.95s, "rilassato"): ora il thud e la corsa della palla vanno allo stesso ritmo ovunque.
**Stessi trick**
- TRICK da fermo = HESITATION (come nel solo; tolta l'alternanza crossover/tra-le-gambe). Mappa unica: fermo=hesi, giu=cambio mano, sinistra=stepback, su=behind, destra=crossover, doppio tap=spin, POST=drop step. (L'eurostep resta solo quando Parti al ferro in partita: e' situazionale, non cambia i gesti.)
**POST sempre visibile (come nel court solo)**
- In attacco il bottone POST sta SEMPRE a schermo: 1v1 slot destro, scrimmage in alto a sinistra (accanto al P&R, senza coprirlo). Prima compariva solo con palla entro 14-18ft.
**Audio (conferme)**
- Indoor court: musica rap utente (Vaitsez, 3'12" loop) CONFERMATA presente.
- Spettatori: letto stadio utente (59.6s) + cheer/ooh/whistle in partita CONFERMATI (v2.16.1).
- ARENA SCREAM: file NON presente nel progetto e non ritrovato neanche nel backup Drive (contiene solo il vecchio workspace "baskin" con gli stessi sfx). Serve un ri-upload dell'utente.
Test: V219 U1-U4 verdi (cadenza ~0.42-0.54s, hesi, POST 1v1+5v5), V216/SoloPost OK, SimRunner 3/3, smoke OK, import 0 err, aapt 99/2.17.0 dual-abi, firmato.

## v2.18.0 (code 100) — 2026-09-24 — STEPBACK 3 + FLOATER
- STEPBACK 3: fai lo stepback (stick sinistra) e archia da oltre l'arco entro 0.9s: contest x0.75 (spazio creato), timing +25% (pop, non gratis). Popup grande "STEPBACK 3". I punti restano 3 per distanza: bilanciato sui floor del ShotSystem.
- FLOATER: in corsa al ferro con un difensore entro 90px (6-16ft), TIRA = sospensione sulla palla: arco alto (flight +0.18), contest x0.5, stenzata 2.5x piu' rara (chance x0.4, raggio block 70px). Popup grande "FLOATER". Situazionale come l'eurostep (serve un difensore: nel court solo non esiste).
- Ordine famiglia tiro: REVERSE -> HOOK -> STEPBACK 3 -> FLOATER -> FADEAWAY -> PULL-UP (lo stepback3/floater erano irraggiungibili in coda: fix).
- Arena scream risolto: era il file stadio 59.6s gia' integrato (conferma utente).
Test: V220 M1-M4 verdi (stepback3 popup, floater popup, blocchi floater 11/50 vs 35/50, decay finestra), regressione V219/V216/SoloPost/V215 OK, SimRunner 3/3, smoke OK, import 0 err, aapt 100/2.18.0 dual-abi, firmato.

## v2.19.0 (code 101) — 2026-09-24 — HEAT CHECK (la sorpresa)
- 3 canestri consecutivi (match O court solo) = ON FIRE!: popup grande, micro-fiamme sopra la testa (off in lowgfx), folla esulta, e la FINESTRA VERDE del meter si allarga +18% (good +15%). Contratto meter INTATTO: rosso=mai, giallo=50/50, verde=100% — il verde e' solo piu' largo.
- Un errore e si spegne: popup "COLD" e finestra torna normale. I palleggi/trick non contano: solo canestri. Stenzato = palla persa = fuoco spento.
- Parita' solo/partita: stessa regola, stesso meter, stesse fiamme.
Test: V221 H1-H3 verdi (finestra 0.055->0.065, ON FIRE al 3mo, COLD sul miss), regressione V220/V219/SoloPost OK, SimRunner 3/3, smoke OK, import 0 err, aapt 101/2.19.0 dual-abi, firmato.

## v2.19.1 (code 102) — 2026-09-24 — IL PALLEGGIO DEL SOLO, IN PARTITA
- Il dettaglio mancante (dall'utente): "il palleggio del solo (bello e realistico) non corrisponde a 1v1/scrimmage".
- CAUSA: nel solo la palla e' DISEGNATA NELLA MANO dell'avatar (il braccio la spinge su e giu'); nel match la Ball rimbalzava da sola accanto al giocatore su un seno puro.
- FIX: Avatar ora registra la posizione della mano forte a ogni frame (last_palm), e la Ball del match, nel palleggio normale, sta ESATTAMENTE in quella mano: stesso braccio, stesso ritmo, stesso look. Thud sincronizzato col TOCCO TERRA della mano.
- I percorsi dedicati restano: spin che avvolge il corpo, crossover con overshoot, finta = palla tenuta al petto.
- Probe V222: D1 in mano (dx 0.4px) ✓, D2 oscillazione col braccio ✓, D3 spin wrap ✓; regressione V221/220/SoloPost OK, SimRunner 3/3, smoke OK, aapt 102/2.19.1 dual-abi, firmato.

## v2.20.0 (code 103) — 2026-09-24 — palleggio clonato + fiamme vere
- "No, LO devi copiare": nel match la posa DRIBBLE girava a 5.2+velocita' rad/s (piu' veloce, variabile); nel solo a 4.2 COSTANTE. Ora il match usa lo stesso orologio 4.2 del libero, fermo E in corsa: stesso braccio, stesso ritmo, stessa palla in mano (helper Avatar.last_palm).
- Fiamme HEAT: da 3 pallini a LINGUE DI FUOCO a 3 strati (base arancio, pancia gialla, nucleo bianco-caldo) che ondeggiano e sfarfallano — helper UNICO Avatar.draw_flames per solo e partita (parita' garantita).
- Probe V223: ritmo 4.200 esatto in corsa, palla in mano (lag 1 frame ~1.7px), fiamme ok; V222/V221/SoloPost OK, SimRunner 3/3, smoke OK, import 0 err, aapt 103/2.20.0 dual-abi, firmato.

## v2.21.0 (code 104) — 2026-09-24 — palleggio CHIUSO + scia palla
- Bug che spiegava tutto ("palla si sposta a dx e sx"): la mano stava in una variabile STATICA globale (Avatar.last_palm): l'ultimo avatar disegnato nel frame vinceva -> la palla seguiva la mano dei DIFENSORI. Oscillazione che spariva o doppiava a seconda dell'ordine di disegno. Sostituita con un registro per-owner (palms[instance_id]): la Ball legge SOLO la mano del suo holder (probe: oscillazione reale 6-41px = tocco terra + spinta, dx=0).
- Laterale STABILE: palla ferma al lato della mano (11px), no piu' oscillazione laterale del palmo col ciclo di corsa.
- SCIA PALLA (sorpresa): in volo (tiro, pass, dunk-drop) rimangono fino a 7 fantasmi che svaniscono, stessa proiezione della palla reale; si svuota appena viene ripresa. Presente ovunque: court solo E partite (stessa matematica _screen/m_project).
Test: V222 D1-D3 (palm per-owner, oscillazione solo), V223 R1-R3, V224 L1-L3 (laterale fisso, scia 7 punti, clear), V221/V220/SoloPost OK, SimRunner 3/3, smoke OK, import 0 err, aapt 104/2.21.0 dual-abi, firmato.

## v2.22.0 (code 105) — 2026-09-24 — posizione ESATTA del palmo + scia visibile
- Il palleggio ora copia la posizione ESATTA del palmo (x E y) dall'avatar del possessore: x laterale = hd*h*0.30 (~19px, stabile), y = la spinta reale del braccio. Prima usavo un laterale arbitrario (11px) e solo la y.
- Parita' QUANTITATIVA misurata probe: ampiezza palleggio IDENTICA solo vs partita (range 35px, delta 0.2), laterale stable x_range=0. I due avatar usano la stessa identica formula DRIBBLE (Avatar.gd): da questa build la palla si muove identico perche' e' la stessa posizione.
- Lezione debug: il registro palms e' per instance-id del CHI disegna; NPC del solo condividono la chiave della scena (per misure utente usare il court INDOOR o la partita).
- Scia palla VISIBILE: 10 fantasmi (era 7), raggio 0.48-0.90*r, alpha 0.10-0.37 (era quasi trasparente: per questo "non la vedevi").
- Probe V222: dx=0.00001 (palla incollata al palmo), V224 L1-L2 (laterale fisso, scia 10), V221/SoloPost OK, SimRunner 3/3, smoke OK, import 0 err, aapt 105/2.22.0 dual-abi, firmato.

## v2.23.0 (code 106) — 2026-09-24 — palla SINCRONA col braccio nei trick + scia a nastro
- Feedback utente: "se cambia l'intensita' il braccio va piu' veloce, ma la palla resta ferma" — vera per tutti i giocatori (utente E avversari). Causa: durante un trick il braccio accelera (phase anim_t*1.9) mentre il percorso palla bounce su un altro orologio (dribble_clock*6) -> braccio veloce, palla quasi ferma. Fix: il bounce del percorso usa lo STESSO phase del braccio (probe: h_palla 31 vs braccio 28, sincroni). Fuori trick la palla resta incollata al palmo (registro per-owner).
- Scia palla a NASTRO: sostituiti i fantasmini (invisibili anche pompati) con una POLILINEA spessa (r*1.15, alpha 0.55) dietro la palla in volo: finalmente inconfondibile. Stesso nastro nel court solo: parita' mantenuta.
- Probe V226 S1-S3 verdi; regressione V222/V224/V221/V220/SoloPost OK; SimRunner 3/3; smoke OK; import 0 err; aapt 106/2.23.0 dual-abi; firmato.

## v2.23.1 (code 107) — 2026-09-24 — TELEFONO OK + nastro soft
- Bug vero segnalato: sul telefono il pannello del letto (e ogni GamePanel: frigo, guardaroba...) compariva META' fuori schermo. Causa: la UI usa canvas_items+expand (spicco logico ~1520x720 su 20:9), ma Panel._screen() misurava i PIXEL grezzi (2280x1080) e centrava li' -> card spostata fuori a destra/basso. Ora misura il visible_rect del viewport + clamp finale (mai fuori schermo, in ogni caso). Tablet invariato.
- Probe PhoneProbe: card dentro lo schermo logico a 1280x720, 2280x1080, 2400x1080 — tutti verdi.
- Nastro scia piu' soft (era troppo marcato): alpha 0.55->0.38, spessore x1.15->x0.85. Sync dribble-trick confermato ok dall'utente.
Test: V226/V222/V221/SoloPost OK, PhoneProbe 6/6, SimRunner 3/3, smoke OK, import 0 err, aapt 107/2.23.1 dual-abi, firmato.

## v2.24.0 (code 108) — 2026-09-24 — RIMESSA SVEGLIA + velocity +5%
- Feedback amico: "dalla rimessa rimangono tutti fermi, gli sfidanti restano indietro". Vero: play_live=false congelava TUTTI per 0.85s dopo ogni canestro (solo l'attesa umana 5v5 li lasciava muovere), e la AIBrain era spenta.
- Ora: durante la rimessa si muovono TUTTI tranne il rimettitore (fuori campo), e la brain torna in formazione: i compagni giocano spazio, i difensori rientano. Probe: 8 si muovono / 1 fermo, live in 0.85s.
- Velocita' giocatori +5% (stesso moltiplicatore 0.76 per utente e AI: nessuna squilibratura tra te e gli avversari, solo il gioco piu' vivo).
Test: InboundProbe I1-I3, regressione V226/Phone/V221/V220/SoloPost OK, SimRunner 3/3, smoke OK, import 0 err, aapt 108/2.24.0 dual-abi, firmato.

## v2.24.1 (code 109) — 2026-09-24 — telefono OK + scia eliminata
- Scia palla ELIMINATA del tutto (match + solo): appends, nastro, var. Richiesta utente.
- Telefono del gioco: il FRAME era piazzato nel _ready usando misure NON affidabili (get_viewport_rect e anche get_visible_rect al _ready puo' dare 1280x1280 dopo la rotazione) -> sul telefono la cornice straripava in alto/basso e le CHAT venivano tagliate ("bene il telefono, male le chat"). Ora c'e' _place_phone(): TOP_LEFT, ricalcolo deferred + a ogni resize, clamp on-screen (pattern GamePanel). Probe: 412x664 dentro 1520x720.
- Chat: larghezza bolla dal FRAME (mai dallo scroll non centrato: lo scroll a 0 sforzava le bolle in colonne di una-parola-per-riga); label che avvolge il testo con cappatura max e pavimento min.
Test: ChatProbe C1-C3 (frame in schermo, bolle sane, scia=0), PhoneProbe, Inbound, V226 (S3 adattato), V222, SoloPost, SimRunner 3/3, smoke OK, import 0 err, aapt 109/2.24.1 dual-abi, firmato.

## v2.24.2 (code 110) — 2026-09-24 — STANZE ADATTIVE (telefono allungato)
- Bug vero su telefono 20:9: le stanze (PALESTRA, APPARTAMENTO, FISIO) sono mondi FISSI 1600x900 disegnati 1:1: sul viewport logico da 720 il fondo spariva ("esercizi tagliati la parte bassa" = tapis/bike a y>720).
- Ora _fit_room(): scala integra (0.8 su telefono), centra, e ridisegna a ogni resize. SOLO spot_layer (hotspot) scala: i PANNELLI (letto/frigo/start) restano pieno schermo perche' usano gia' lo schermo logico.
- Chat "prima lunghissima, dopo la risposta a posto": le bolle si misuravano su frame.size stale del _ready (558x900); _place_phone() ora e' SINCRONO a ogni open_app, e i cappelli iniziali sono gli stessi del ricalcolo (ph<=760, pw<=540).
- Probe utili: per misure UI con layer scalati usare get_global_transform_with_canvas() (get_global_rect ignora il transform del CanvasLayer!).
Test: RoomFitProbe 10/10 hotspot dentro (scale 0.8, pos (120,0)), ChatProbe C1-C3, PhoneProbe, Inbound, V226, V222, V221, SoloPost, SimRunner 3/3, smoke OK, import 0 err, aapt 110/2.24.2 dual-abi, firmato.

## v2.24.3 (code 111) — 2026-09-25 — MENU & chat uniformi su telefono allungato (da screenshot utente)
- MENU: tutto il layout era a posizioni fisse su 1280x720 (bottoni a (640,150), hero (120,158), skyline fino a 1360): su telefono largo la meta' DESTRA restava vuota e l'hero restava attaccato al bordo sx. Ora il layout segue le dimensioni LOGICHE reali (mv_w/mv_h + mv_rel() a ogni resize e dopo il primo frame, anche per la rotazione): colonna bottoni nella meta' DESTRA reale, hero centrato nella sinistra reale, skyline/motes fino al bordo. Probe: colonna x=870 su 1520, hero x=180.
- CHAT (fix "coach lungo, altri corti"): preview UNA riga sola (34 caratteri + ellissi, wrap OFF), righe altezza uniforme 84. Scrollbar telefono: da spesso dito di colonna a linea da 6px al 22% opaco.
- Imparato: lambda GDScript non catturano ident "_" locali di _ready (parse error) -> variabili membro; UIKit.column posiziona lo SCROLL (non la VBox ritornata: spostare il parent).
Test: MenuProbe M1-M3, ChatProbe, RoomFit, Phone, Inbound, V222, SoloPost, SimRunner 3/3, smoke OK, import 0 err, aapt 111/2.24.3 dual-abi, firmato.
