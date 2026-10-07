# Baskin Academy — regolamento a norma + prima volta (post 1.18.0, quarta passata)

Data: 7 ottobre 2026 • Motore: Godot 4.3 stable

## Riferimento aggiornato: Rev.19 (25/09/2024)

L'audit della 2ª passata era sulla Rev.12. Questa passata allinea il gioco al
testo PIÙ RECENTE (Rev.19, scaricata e verificata per intero): le regole già
implementate sono tutte confermate, con una correzione e un completamento.

## I 5 settori dell'area laterale (Rev.19 fig. 2)

- Geometria a norma: il semicerchio da 3 m è diviso in CINQUE settori con
  larghezze lungo l'arco 200/150/70/150/200 cm (770 cm totali). Il settore
  CENTRALE (70 cm, davanti al canestro) è il posto da 2 punti; tutti gli
  altri settori valgono 3.
- `Court.in_central_sector()` ricava il settore dalla posizione di tiro;
  `_baskin_points` per il ruolo 2 ora vale 2 dal centrale / 3 dal laterale
  (prima: 2 fisso sul laterale, semplificazione documentata in 3ª passata).
- Disegno a pavimento (CourtVisual): 4 linee radiali con le proporzioni
  vere, arco TRATTEGGIATO a 3,70 m e cifre "2"/"3" dipinte a stampino nei
  settori — chi prende il gioco in mano capisce a colpo d'occhio quanto
  paga ogni posto.
- Il pivot IA sceglie il settore a ogni consegna (`give_ball` →
  `pivot_sector`: 25% centrale / 75% laterale) e cammina fin lì prima di
  tirare.

## FIX regolamentare: la linea del 2R

Rev.19: il 2R tira da FUORI l'arco tratteggiato a 3,70 m («cioè 0,7 metri
più lontano degli altri»). Il codice lo faceva tirare da una linea PIÙ
VICINA (≈2,1 m). Corretti `shot_must_clear_area` (nuovo `SIDE_DASH_R` =
185 px), lo spot di tiro (`pivot_shot_spot`) e l'IA (`pivot_beyond_line`),
così un 2R non pianta più i piedi dove il tiro verrebbe fischiato. I tiri
liberi del ruolo 3 sul laterale erano già dietro la tratteggiata (194 px).

## Prima volta: si capisce senza manuale

- Nuova voce **COME SI GIOCA** nel menu → `RulesScene`: cos'è il baskin, il
  campo, i 5 ruoli, i punti, le regole chiave, i comandi, più il DIAGRAMMA
  del campo visto dall'alto con i 5 settori e i due ferri sullo stesso palo.
- In partenza il bottone **REGOLE** è in alto a DESTRA (era a sinistra,
  poco visibile), sotto TIMEOUT e CAMBIO; la scheda si apre a destra e ora
  inizia da IL CAMPO.
- Chip «quanto vale il tuo tiro» sotto il tabellone per chi gioca pivot:
  ruolo 1 → «1° TIRO · VALE 3» / «2° TIRO · VALE 2»; ruolo 2 → «SETTORE
  CENTRALE · 2 PUNTI» / «SETTORE LATERALE · 3 PUNTI» / «ESCI DIETRO LA TUA
  LINEA PER TIRARE»; ruolo 3 presso l'area → «CANESTRO LATERALE · 2 PUNTI».
- Popup sul canestro realizzato dal ruolo 2: «+2 SETTORE CENTRALE» /
  «+3 SETTORE LATERALE».
- Il secondo hint della prima azione dice dove sta il bottone REGOLE; le
  schede ruoli (RolePicker) e i testi del riquadro regole sono aggiornati
  ai settori. Tutto in IT/EN (`Loc`).

## Menu iniziale rinnovato

- Pulsanti da menu veri (`UIKit.menu_button`): GIOCA primario arancione,
  COME SI GIOCA + IMPOSTAZIONI secondari in stile «ghost» — addio ai
  bottoni grigi di default sullo schermo di titolo.
- Hero art: il DOPPIO canestro laterale (2,20 + 1,20 m sullo stesso palo,
  scala 90 px/m, stesse proporzioni del campo di gioco) sotto riflettore a
  destra, con le altezze scritte accanto ai ferri: è il simbolo del baskin
  e ora è la prima cosa che si vede.

## Versione e pipeline

- **v1.19.0 / versionCode 21** (`GameData.VERSION` finalmente allineato: era
  rimasto a 1.17.0 mentre il preset diceva 1.18.0).
- Nuovo workflow `build-apk-baskin.yml`: APK firmato SOLO con il keystore
  dai GitHub Secrets (mai nel repo; `keystore/` è ignorato da git); senza
  secret la pipeline si salta in verde con un avviso; un tag `baskin-v*`
  crea la Release con l'APK allegato. Istruzioni passo-passo per i secret in
  `CONTINUITA-E-APK.md`.

## Verifica

CI smoke (Godot 4.3 headless: SceneSmoke, MatchTest 5v5 con IA, tutte le
scene dei menu più la nuova RulesScene) verde, nessuno SCRIPT ERROR.

---

# Baskin Academy — upgrade EISI (post 1.18.0, terza passata)

Data: 7 ottobre 2026 • Motore: Godot 4.3 stable

## Doppio canestro laterale (regolamento Rev.12)

Ogni lato campo ha ora DUE canestri sullo stesso palo, alle altezze
regolamentari: **ALTO a 2,20 m** (reg. 2,00-2,20) per il tiro del **ruolo 2**,
**BASSO a 1,20 m** (reg. 1,00-1,20) per il **ruolo 1**. Canestri tradizionali
a 3,05 m. (`Court.SIDE_RIM_HIGH` / `SIDE_RIM_LOW`, scala 61,6 px/m.)

- La palla ricorda l'altezza del ferro del PROPRIO tiro (`Ball.shot_rim_h`):
  collisioni, canestro, rimbalzi ed effetti usano quella, non più una sola
  altezza unica — il tiro del ruolo 1 entra nel basso, quello del ruolo 2
  nell'alto, stessa posizione x/y.
- `rim_height_of(hoop, role)` decide per ruolo: lancio, tiri liberi, dunk.
- Disegno: palo unico con pannello alto (vetro + quadrato arancio + rete) e
  pannello basso più piccolo (rete corta), in entrambe le viste (frontale e
  da dietro), con ombra di stacco.

## Punteggio del ruolo 2 corretto

Prima era invertito: laterale 3 / frontale 2. Ora come da regolamento:
**canestro laterale alto = 2 punti** (settore centrale, semplificazione
documentata dei 5 settori), **canestro tradizionale = 3 punti**.

## Ruolo 1 in carrozzina

Il pivot di ruolo 1 (giocatore senza cammino) si disegna sulla **sedia a
rotelle da baskin**: ruote grandi da ~0,60 m di diametro con cerchione e
raggi, telaio, schienale, poggiapiedi, gambe raccolte con i piedi sul
poggiapiedi. Tutto il busto scende all'altezza del sedile (~0,55 m), così le
proporzioni restano coerenti con la figura in piedi. Vale per il giocatore
utente e per l'IA.

## Verifica

- CI `smoke-baskin.yml`: SceneSmoke + MatchTest + scene menu, verde.

---

# Baskin Academy — revisione dei sorgenti (post 1.18.0, seconda passata)

Data: 7 ottobre 2026 • Motore: Godot 4.3 stable • Basato sui sorgenti 1.18.0

## Animazioni delle schiacciate (portate da Hoop City Life v2.39)

Stesso lavoro di rifinitura fatto su Hoop City Life, applicato al match 5v5:

1. **FERRO A MENSOLA** (`HoopArt.gd`). La piega parte dall'ATTACCO COL
   TABELLONE (peso zero lì) e cresce fino al fronte libero: molla reale
   (`rim_bend`/`rim_bend_v`, k=26 damp 7) guidata dai giocatori appesi
   (`CourtVisual.gd`, canestro più vicino). Vale per i due canestri da fondo.
2. **LA RETE SEGUE IL FERRO**: tutta la maglia — prospettica e mezza rete
   davanti alla palla — si sposta col ferro piegato, agganciata in cima e
   smorzata verso l'orlo raccolto (`draw_net_perspective`, `draw_net_front`).
3. **HANG ABBASSATO CON PENDOLO** (`Player.gd`, `Avatar.gd`). Appeso dopo lo
   slam: corpo più basso (spalle sotto il bordo, testa fuori dal canestro),
   la mano dello slam risale al LABBRO PIEGATO (`rim_drop`), oscillazione
   destra/sinistra a pendolo attorno al ferro, e — quando la posa slam non
   guida — presa a DUE mani convergenti sul tubo (`hang` + `hang_one`).
4. (dalla prima passata: tabellone che insegue il ferro in ritardo, falli in
   attacco calibrati, canestro laterale più leggibile.)

## Audit regolamento (Rev.12 ufficiale, 18/10/2016)

Verificato punto per punto sul motore regole esistente. GIÀ CONFORME:
pivot = ruoli 1-2 (uno solo in campo, liberi da marcatura); ruolo 1: 3 punti
al primo tiro / 2 dopo; ruolo 2: canestro laterale, obbligo palleggi prima
del tiro; ruolo 3: laterale 2 / tradizionale 3, corsa con palleggi, no
layup ravvicinato; ruoli 4-5: 3 da oltre l'arco; limite 3 TIR a tempo per
il ruolo 5 e 3 CANESTRI a tempo per i ruoli 1-4 (regola 9); divieto di
ingresso nelle aree laterali per i ruoli 3-4-5 salvo consegna (regola 5);
canestri laterali più bassi. Documentate come semplificazioni: un solo
canestro laterale per lato (il regolamento prevede alto+basso), punteggio
del ruolo 2 semplificato (3 laterale / 2 frontale invece dei settori
centrale/laterale).

## Verifica

- Workflow CI `smoke-baskin.yml`: SceneSmoke (MatchScene completa headless),
  MatchTest (5v5 simulato), scene dei menu — verde, nessuno SCRIPT ERROR.

---

# Baskin Academy — revisione dei sorgenti (post 1.18.0)

Data: 7 ottobre 2026 • Motore: Godot 4.3 stable • Basato sui sorgenti 1.18.0

## Stato della consegna

Sorgenti corretti, non una nuova release Android. Il progetto ora vive in
`baskin-academy/` nel repository di lavoro, con smoke test automatico in CI
(workflow `smoke-baskin.yml`: import + SceneSmoke/MatchTest headless ad ogni
push sui sorgenti).

## Correzioni e migliorie

1. **Falli in attacco più presenti** (`Court.gd`, `_charge_check`). La
   soglia richiedeva 34px di distanza (meno del contatto fisico dei corpi)
   e uno scatto a 195: per questo uscivano 0-2 fischi in 180 secondi.
   Calibrato a contatto a braccio disteso (52px), scatto 170, traiettoria
   0.45 e difensore tollerato fino a 95 di velocità. Restano falli rari,
   ma nella partita IA si vedono. Cooldown invariato (2 s): niente sfilate.
2. **Il tabellone arriva dopo il ferro** (`CourtVisual.gd`, `HoopArt.gd`,
   `NetFront.gd`). Nuovo `board_shake` che insegue `rim_shake` come una
   molla lenta: la scossa parte dal ferro e il pannello la riceve con un
   filo di ritardo, come nella struttura reale. Vale per i canestri da
   fondo e per i laterali (entrambe le viste). A riposo nessuna differenza.
3. **Canestro laterale lontano più leggibile** (`NetFront.gd`). L'ombra di
   stacco era troppo accennata: ora pannello scuro più esteso (alpha 0.42)
   e cornice scura attorno al vetro, in entrambe le viste. Contro il
   maxi-schermo dell'arena il tabellone si legge subito.

## Note

- Il limite dei cambi per periodo (punto aperto del LEGGIMI) resta una
  decisione di gioco: non implementato in attesa di scelta (proposta: 3
  cambi a quarto, come da nota).
- Verifica: workflow CI `smoke-baskin.yml` su ogni push dei sorgenti.

---

# Baskin Academy — revisione dei sorgenti 1.15.0

Data: 26 settembre 2026 • Motore usato: Godot 4.3 stable

## Stato della consegna

Sorgenti corretti, non una nuova release Android. La versione applicativa resta 1.15.0: **l'APK originale non è stato ricompilato e non contiene queste correzioni**. Il pacchetto aggiornato non include APK, cache Godot, chiavi ADB o configurazioni personali dell'ambiente.

## Correzioni

1. **Sostituzioni nelle partite senza panchina** (`Court.gd`). Il coach attivava cambi anche quando `is_fixture` era falso e il roster delle riserve era vuoto. Riprodotto in MatchTest: errori ripetuti di accesso agli indici, dopo la creazione di nodi giocatore incompleti. Ora il coach opera solo nelle partite con panchina; `_start_sub` verifica modalità, giocatore e posto prima di creare il sostituto.
2. **Comandi touch nascosti** (`TouchButton.gd`). Nascondere un pulsante o il suo genitore ora rilascia il comando attivo. Il rilascio del mouse non può più interrompere il dito che sta tenendo premuto un pulsante: identificatori separati.
3. **Joystick nascosto** (`VirtualJoystick.gd`). Nascondere il joystick o un suo genitore azzera immediatamente il movimento; i controlli invisibili non acquisiscono nuovi tocchi.
4. **Recupero dei salvataggi parzialmente corrotti** (`SaveSystem.gd`). Ripristino ricorsivo dei valori predefiniti per campi null o di tipo incompatibile, compresi `attrs` e `season.high`. Preservati campi aggiuntivi e numeri JSON. Non è una validazione completa dei limiti e di ogni campo dinamico del profilo.
5. **Scrittura dei salvataggi** (`SaveSystem.gd`). Il vecchio file non viene più cancellato prima della sostituzione; gli errori di scrittura/rinomina restituiscono `false` invece di un successo fittizio. Provata creazione, sostituzione e rilettura su Linux; non simulati esaurimento spazio o interruzione di alimentazione su Android.
6. **Errore di parsing nello strumento TmpCharge**. Corretta l'indentazione mista che faceva fallire l'importazione dello script.
7. **Runner dei test** (`strumenti/run_battery.sh`). Percorsi relativi al pacchetto, override `GODOT`/`PROJECT`/`LOGS`, log completi e risultato non-zero per timeout, errori GDScript o controlli falliti. Gli errori diagnostici generici del motore vengono segnalati separatamente. Sintassi shell verificata; i test sotto sono stati eseguiti direttamente, non tramite un'esecuzione integrale del nuovo runner.

## Verifiche eseguite

| Verifica | Risultato |
|---|---|
| ReliabilityProbe, prima delle correzioni | 7 controlli falliti su 15 |
| ReliabilityProbe, dopo | 15/15 superati |
| PracticeSubProbe, nuovo test mirato | ALL OK: nessuna richiesta di cambio o creazione di giocatori senza panchina |
| 16 probe esistenti, da BaskinProbe a Rule14Probe | Tutti riportano ALL OK dopo le correzioni a input e salvataggi |
| Rule14Probe dopo la correzione di Court | ALL OK |
| MatchTest, 90 secondi simulati, dopo la correzione di Court | MATCH TEST OK, senza SCRIPT ERROR; partita arrivata al secondo quarto |
| BalanceProbe, 180 secondi simulati, dopo la correzione di Court | Completato senza SCRIPT ERROR; punteggio 10–9, 9 tentativi |
| LoadTest | Caricati menu, scelta divisa e impostazioni |
| Importazione editor dopo correzione TmpCharge | Nessun errore di parsing |
| git diff --check | Nessun errore di whitespace |

I log completi sono in `verifiche/`. Rimangono diagnostiche nei test headless: `Parameter "t" is null` dal renderer dummy e risorse/istanze ancora in uso all'uscita. **Non sono state risolte in questa revisione** e non vanno confuse con un collaudo totalmente privo di errori. I test guidati dall'IA restano soggetti a casualità.

## Aprire e verificare

Aprire `baskin_academy/project.godot` con Godot 4.3. Per i nuovi test:

```bash
godot --headless --path baskin_academy res://tools/ReliabilityProbe.tscn
godot --headless --path baskin_academy res://tools/PracticeSubProbe.tscn
```

Per la batteria completa:

```bash
GODOT=/percorso/godot bash strumenti/run_battery.sh
```

Usare un profilo di sviluppo: alcuni test preesistenti cambiano impostazioni e dati locali dell'app.

## Da fare prima di distribuire una nuova versione

- Prova su dispositivo Android: due dita, cambio possesso, scomparsa comandi, background/rientro, ripresa della carriera e sostituzioni.
- Verifica grafica e delle prestazioni: non effettuata con renderer reale in questa revisione.
- Indagare risorse trattenute alla chiusura e diagnostiche del renderer dummy.
- Incrementare insieme versione in GameData.gd e version/name + version/code in export_presets.cfg, ricompilare e firmare l'APK.

Il progetto rimane disponibile in workspace per continuare lo sviluppo senza riscaricarlo.
