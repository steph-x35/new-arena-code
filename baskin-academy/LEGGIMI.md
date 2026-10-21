# Baskin Academy — cosa scaricare

## 1. L'APK da installare sul telefono

**`BaskinAcademy-v1.15.0.apk`** (cartella principale, 29,6 MB) — è l'**unico** APK nel workspace.

| | |
|---|---|
| Pacchetto | `com.baskinacademy.app` |
| Versione | 1.15.0 (versionCode 17) |
| Firma | firma di debug del progetto → al primo avvio Android chiede di autorizzare l'installazione da "origini sconosciute" |

## 2. Cosa cambia nella 1.15.0

| # | Miglioramento | Come è stato risolto |
|---|---|---|
| 1 | **sostituzioni dal vivo** | Tasto **CAMBIO** (alto a destra, 5v5): si apre il pannello con **IN CAMPO** a sinistra e **PANCHINA** a destra. Scegli chi esce, poi chi entra. Il cambio si esegue alla **prima palla morta**, non a gioco fermo: chi esce **cammina** verso la panchina e chi entra **cammina** in campo (si incrociano, come in panchina vera). |
| 2 | **il ruolo non si perde** | Chi entra prende lo **stesso ruolo** di chi esce e la **stessa fisionomia** (donna/uomo, taglio di capelli, corporatura): la formazione resta regolamentare — **due donne in campo, un solo pivot** — anche dopo dieci cambi. Nel test: 5 in campo prima e dopo, 2 donne, 1 pivot. |
| 3 | **niente cambi a metà azione** | Se chi deve uscire ha la palla in mano o è in volo, il cambio **aspetta** e si fa appena molla: non ti strappa mai la palla di mano. |
| 4 | **puoi chiedere il cambio anche per te** | Scegli te stesso nella lista: scendi in panchina e il tuo sostituto entra con il tuo ruolo. |
| 5 | **l'allenatore si muove** | Anche l'IA cambia: chi resta **senza gambe** (energia sotto il 18%) viene richiamato in panchina alla prima palla morta. Vale per entrambe le squadre, quindi lo vedi anche nella partita simulata. |
| 6 | **panchina che si libera** | Un posto appena usato ha **22 secondi** di cooldown: niente scambi a raffica dallo stesso posto. Il posto dell'utente resta suo. |

### Punti aperti e proposte

- **Falli in attacco**: restano rari nella partita IA (0-2 in 180 s); si può alzare la soglia se li vuoi più presenti.
- **Numero di cambi**: non c'è un limite per periodo (nel baskin non c'è); se preferisci si può mettere un tetto, tipo 3 cambi a quarto.
- **Vibrazione del canestro**: si può aggiungere il ritardo del tabellone rispetto al ferro.
- **Canestro laterale lontano**: il tabellone resta piccolo contro lo schermo luminoso dell'arena.

### Cosa c'era nella 1.14.0

| # | Miglioramento | Come è stato risolto |
|---|---|---|
| 1 | **doppio palleggio = infrazione** | La **finta raccoglie la palla** (ferma nelle mani). Da lì puoi solo passare o tirare: se tocchi TRICK e provi a palleggiare, fischio e **palla agli avversari**, come i passi. Pannello REGOLE aggiornato. |
| 2 | **il canestro VIBRA** | Sulla **schiacciata** ferro, tabellone e retina **tremano** per un secondo (e mentre resti appeso), con la stessa scossa attenuata quando la palla **sbatte sul ferro** o sul tabellone. Prima il ferro si accendeva soltanto: adesso si vede tremare. |
| 3 | **rimbalzo sull'ultimo tiro libero sbagliato** | Come nel regolamento: sui liberi **non** c'è rimbalzo, ma l'**ultimo sbagliato** resta **palla viva** e si gioca il rimbalzo (chi arriva prima la prende). Prima la sequenza si chiudeva sempre con la rimessa avversaria. |
| 4 | **fila del tiro libero regolamentare** | Due per squadra in corsia (uno per lato, i difensori nel posto più vicino a fondo campo, gli attaccanti subito dopo) e gli altri fuori dall'arco. Serve perché ora dall'ultimo libero si va a rimbalzo. |
| 5 | **canestro laterale lontano più leggibile** | Il maxi-schermo dell'arena gli sta dietro: ora c'è un'ombra che stacca il tabellone dallo schermo e la retina si legge subito. |

### Cosa c'era nella 1.13.0

| # | Miglioramento | Come è stato risolto |
|---|---|---|
| 1 | **il palleggio segue la mano** | La mano del palleggiatore sta **sopra la palla**, stessa verticale: il palmo la tocca quando sale e la **accompagna** mentre scende. Prima il braccio era un bastone che seguiva la palla fino a terra. |
| 2 | **braccio mai più allungato** | Il braccio è disegnato a **due segmenti** (spalla-gomito-mano): il gomito **si piega sempre** e la mano non esce mai dalla portata (il palleggiatore piega un filo le ginocchia, come si fa davvero). In test: 26 px di portata usati su 29 disponibili, gomito piegato in 97 campioni su 97. |
| 3 | **palla sotto la mano, che sale e scende** | La palla rimbalza con **corsa della mano di 19 px** (da 19 a 38 px di altezza), tocca il pavimento e risale: si vede il **gesto** del palleggio, non una palla appiccicata. |
| 4 | **canestro laterale rigirato** | Il canestro laterale **vicino alla telecamera** è girato di 180°: vedi il **tabellone** (retro con viti e staffa) e il palo davanti, con il ferro che spunta sotto. Quello lontano resta in vista frontale. Trasparenza invariata. |
| 5 | **difesa: chi marcare, sempre chiaro** | Ogni volta che sei in difesa l'uomo che il tasto DIFENDI ti manda a prendere ha un **anello verde** ai piedi (verde come il tasto); chi **non puoi** marcare, quando gli sei addosso, ha un **anello rosso** pulsante. |
| 6 | **fallo «L» corretto, non oppressivo** | Fischio solo se **insisti**: un contatto di passaggio (0,18 s) fa solo comparire l'anello rosso, si fischia dopo **0,30 s** addosso al ruolo più basso. Se sei **passivo** l'assist ti porta via e non succede nulla; se il joystick ti spinge addosso a lui, il fallo arriva. Sul **tuo** ruolo non si fischia mai. |

### Cosa c'era nella 1.12.0

| # | Miglioramento | Come è stato risolto |
|---|---|---|
| 1 | **il rimbalzo si può anticipare** | La palla ora **sa dove arriverà a terra** (previsione fatta con lo stesso modello con cui vola) e lo **mostra**: un anello tratteggiato sul parquet quando è in aria e libera. Ci vai prima, arrivi in tempo. Vale anche per gli avversari, quindi non è un vantaggio: è una lettura. |
| 2 | **rimbalzo giocato come si deve** | Sul ferro ci vanno **solo i due più vicini per squadra** al punto di caduta; gli altri restano sul proprio uomo (in difesa) o sulla propria posizione (in attacco). Prima correvano tutti e cinque dietro la palla: sembrava una rissa da cortile. In test: su 10 giocatori se ne muovono 2. |
| 3 | **l'IA legge il rimbalzo vero** | L'IA andava dove la palla **era**, non dove sarebbe arrivata. Ora usa la stessa previsione del gioco e arriva sul punto di caduta. |
| 4 | **la palla va al primo che arriva** | Nella scelta di chi prende il rimbalzo conta molto di più la **vicinanza** (peso più forte sulla distanza, premio sotto i 55 px): anticipare paga davvero. |
| 5 | **rimbalzo preso da te: si vede** | Popup «**RIMBALZO!**» e un filo di adrenalina, come per la schiacciata. |
| 6 | **pulizia e ritocchi** | Il timer "marcato addosso" non resta più appeso quando perdi la palla (palleggio basso per un secondo senza motivo), e il messaggio del rimbalzo è tradotto anche in inglese. |

### Cosa c'era nella 1.11.0

Palla del tiro che sta nella **tasca** e sale col braccio, caricamento con le gambe e stacco, **follow-through** vero, mano di appoggio, **fallo in attacco** (carica), posizione difensiva bassa e aperta, rimbalzo a due mani, **badge BONUS** nell'HUD.

### Cosa c'era nella 1.10.0

Palleggio realistico: mano e palla sugli **stessi numeri**, rimbalzo a curva **parabolica** che tocca il pavimento, palla **bassa e protetta** quando sei marcato, incrocio sotto il ginocchio, passo indietro ed esitazione con **palla in mano**, **strisciata** in frenata con polvere, palla a **dimensione reale**.

### Cosa c'era nella 1.9.0

Consegna comoda al pivot (hand-off a due mani), falli regolamentari (rimessa prima del bonus, 2 tiri dal 5° fallo di squadra), timeout che restituisce energie (+22), panchina che esulta a canestro, badge del cronometro rosso e pulsante sotto i 5 secondi con beep.

### Cosa c'era nella 1.8.0

Passaggio **magnetico** (palla puntata di continuo alle mani, linea tesa, presa immediata), **difficoltà** Facile/Normale/Forte nelle Impostazioni, **falli degli avversari** con tiri liberi per te, aiuti difensivi sensati (niente raddoppi suicidi), **3 e 5 secondi**, palla dentro la **retina laterale**.

### Cosa c'era nella 1.7.x

Batch 6 completo: marcature **ruolo su ruolo**, rimesse da fondo con **palla ferma in mano** e passaggio visibile, passaggio ricevuto **nelle mani**, fallo «L» **solo col pulsante DIFENDI**, pivot **dietro** il canestro laterale con canestro semi-trasparente davanti, **cambio campo** dopo 2 quarti con il match che continua, difesa più dura sul ruolo 5, schieramento difensivo sulle rimesse, **polvere del tonfo** sotto i piedi dopo la schiacciata.

## 3. Cosa c'è nelle cartelle

| Cartella / file | A cosa serve |
|---|---|
| `BaskinAcademy-v1.15.0.apk` | **l'app da installare** |
| `baskin_academy/` | progetto Godot 4.3 (sorgenti, scene, `assets/`, `keystore/`) |
| `baskin_academy/tools/` | test headless di sviluppo (batteria di verifica): **esclusi dall'APK** |
| `strumenti/` | `setup_build_env.sh` (reinstalla Godot + Android SDK), `ba_logo.py`, `ba_icons_disc.py`, `ba_icons_v2.py`, `ba_patch_k.py` … `ba_patch_t.py`, `ba_patch_u.py` (patch dei batch), `run_battery.sh` (batteria di test in un colpo solo) |
| `grafica/` | sorgenti immagine: logo trasparente (master) e logo grande 1254² |
| `uploads/` | le immagini che hai caricato (logo + icone) |

## 4. Come ricostruire l'APK da qui

L'ambiente di build vive in una cartella cache che **non** viene conservata tra le sessioni.

```bash
bash /home/user/strumenti/setup_build_env.sh          # Godot 4.3 + Android SDK + template
cd /home/user/baskin_academy
mkdir -p export/android                                # la cartella di output deve esistere
export PATH="$HOME/.cache/godot:$PATH"
godot --headless --path . --export-release "Android"  # → export/android/BaskinAcademy.apk
```

La versione sta in `src/core/GameData.gd` (`const VERSION`) e in `export_presets.cfg`
(`version/code`, `version/name`): da alzare insieme a ogni release.

Per gli **screenshot di controllo** serve `xvfb` (non è nell'ambiente base):
`sudo apt-get install -y xvfb`, poi `xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/<Shot>.tscn`.

## 5. Test di verifica (dev)

```bash
bash /home/user/strumenti/run_battery.sh   # tutti i probe + MatchTest + BalanceProbe
```

Oppure uno alla volta:

```bash
cd /home/user/baskin_academy && export PATH="$HOME/.cache/godot:$PATH"
for T in BaskinProbe FlowTest QProbe PadProbe DunkProbe LProbe RuleProbe Rule6Probe Rule7Probe Rule8Probe Rule9Probe Rule10Probe Rule11Probe Rule12Probe Rule13Probe Rule14Probe; do
  godot --headless --path . res://tools/$T.tscn | tail -1
done
godot --headless --path . res://tools/MatchTest.tscn 90     # partita AI vs AI
godot --headless --path . res://tools/BalanceProbe.tscn 180 # mix di gioco dell'IA
```

- `Rule11Probe` copre il batch 11: palla libera in aria che **ha una previsione di atterraggio**
  (verificata contro l'atterraggio vero, scarto 0 px), segno a terra mostrato solo in aria e
  libera, e **rimbalzo non affollato** (2 giocatori su 10 si muovono sul punto di caduta).
- `Rule10Probe` copre il batch 10: **fallo in attacco** (fischia sul contatto vero, non fischia
  col difensore in movimento o fuori posizione), **palla del tiro** che sta nella tasca e sale
  col braccio fino sopra la testa, **follow-through** più lungo, **posizione difensiva** bassa e
  aperta, rimbalzo a due mani, **badge BONUS** (nascosto, mostrato al 5° fallo, con la sigla
  della squadra che tira).
- `Rule9Probe` copre il batch 9: palleggio con mano e palla sugli **stessi numeri**, rimbalzo che
  **tocca il pavimento**, palleggio **basso quando sei marcato**, incrocio sotto il ginocchio con
  cambio di mano reale, passo indietro ed esitazione con **palla in mano**, **strisciata** in
  frenata (segni + polvere) e inclinazione del corpo in corsa.
- `Rule8Probe` copre il batch 8: consegna al pivot (arrivo sul punto e presa), falli
  regolamentari (rimessa prima del bonus, 2/3 tiri dal bonus e sul tiro), timeout che
  restituisce energie, panchina che esulta, badge del cronometro.
- `Rule7Probe` copre il batch 7: difficoltà che cambia davvero l'IA, falli degli
  avversari con tiri liberi per te, 3 e 5 secondi, aiuti sensati, retina laterale.
- `Rule6Probe` copre le regole dei batch 6-7: marcature ruolo-su-ruolo, passaggio magnetico (nessuna inversione, presa nelle mani)
  e presa al volo, rimessa da fondo con palla ferma e lancio, "L" solo col tasto DIFENDI
  (e legale senza), pivot dietro il ferro, cambio campo a fine 2° quarto con match che
  prosegue, schieramento difensivo sulle rimesse, marcatura stretta sul ruolo 5, polvere
  del tonfo.
- `RuleProbe` e `LProbe` coprono le regole della 1.6.0 (aree come muri, cronometri,
  fallo "L" e tiri liberi laterali del ruolo 3).
- Screenshot di controllo: `tools/InboundShot.tscn` (rimessa ferma + lancio),
  `tools/Batch6Shot.tscn` (pivot dietro il ferro, canestro trasparente, fine 2° quarto),
  `tools/Batch7Shot.tscn`, `tools/Batch8Shot.tscn` (panchina che esulta, badge cronometro),
  `tools/Batch9Shot.tscn` (palleggio libero/marcato, incrocio, passo indietro, frenata),
  `tools/Batch10Shot.tscn` (tiro in 4 fasi, rilascio, follow-through, difesa, scivolata,
  rimbalzo a due mani, badge BONUS), `tools/Batch11Shot.tscn` (segno a terra del rimbalzo,
  reazione del ferro e della rete).

Nelle esecuzioni in batteria può capitare che un probe guidato dall'IA (`Rule6Probe`,
`Rule7Probe`) segni 1 fallimento: sono test con esiti casuali (contatto / 5 secondi) —
rilanciati da soli passano; non è un bug di gioco.
