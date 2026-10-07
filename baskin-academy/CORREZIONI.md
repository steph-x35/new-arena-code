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
