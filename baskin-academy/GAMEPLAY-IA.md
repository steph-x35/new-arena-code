# Baskin Academy — gameplay e IA

Revisione del 26 settembre 2026, basata sui sorgenti 1.15.0 già corretti nel passaggio precedente. Motore: Godot 4.3 stable.

## Cosa cambia in gioco

### Passaggi sotto pressione
L'IA confrontava lo spazio libero del compagno con la **pressione sul portatore**, invece che con lo spazio libero del portatore. Oltre il 78% di pressione il confronto richiedeva uno spazio superiore al 100%, quindi quella scelta diventava impossibile. Ora un compagno libero sul perimetro può essere considerato come uscita dalla pressione. Resta una scelta probabilistica, non un passaggio obbligatorio a ogni azione.

Sia la scelta tattica sia quella di ripiego escludono i passaggi vietati dalle regole già presenti nel gioco, e i giocatori in entrata/uscita. Per esempio, l'IA non sceglie un passaggio al pivot dall'esterno dell'area laterale per poi vederselo rifiutare dal motore. La valutazione delle opzioni non genera notifiche sullo schermo.

### Pick-and-roll coerente con il ruolo
- I pivot di ruolo 1–2 non vengono più scelti per il blocco, né dall'IA né dal comando del giocatore.
- L'IA non tenta di comandare il personaggio controllato dall'utente come bloccante e non seleziona compagni già impegnati in un pick-and-roll.
- Un blocco o un roll vengono annullati quando il possesso passa all'altra squadra, il giocatore riceve la palla, inizia un tiro o il compagno coinvolto non è più disponibile.
- Quando il roll termina con la ricezione, il giocatore passa alla lettura del tiro/passaggio invece di continuare soltanto la corsa senza palla.

### Palla e sostituzioni
Una simulazione della versione precedente ha riprodotto errori ripetuti quando il destinatario di un passaggio veniva eliminato durante una sostituzione: la palla continuava a inseguire il nodo rimosso, e il timer della ricezione tentava di usarlo.

Ora:
- il cambio di un giocatore destinatario di un passaggio in corso aspetta;
- i controlli di validità precedono quelli di tipo sugli oggetti potenzialmente eliminati;
- se il destinatario scompare comunque, la palla smette di inseguirlo e diventa libera;
- il timer della ricezione verifica la validità del destinatario e che mittente/destinatario del passaggio corrente corrispondano ancora.

**Invariati:** percentuali di tiro, bonus di difficoltà, velocità dei giocatori, regolamento e grafica. Questa revisione lavora sulle decisioni e sulla continuità delle azioni, non rende l'IA più forte tramite bonus nascosti.

## Verifiche

| Verifica | Esito |
|---|---|
| AITeamworkProbe prima delle modifiche | 9 controlli falliti su 10 |
| AITeamworkProbe dopo | 10/10 superati |
| AIPassLifetimeProbe | 5/5 superati |
| Batteria di regressione | 20 scene di test con esito positivo, nessun SCRIPT ERROR |
| Importazione editor | Nessun errore di parsing |
| Simulazioni aggiornate | 3 × 180 secondi simulati, nessun SCRIPT ERROR |
| Controllo delle differenze e sintassi runner shell | Superati |

La batteria include i 16 probe storici, ReliabilityProbe, PracticeSubProbe e i due nuovi probe. I controlli di gioco passano, ma restano diagnostiche headless su texture e risorse trattenute alla chiusura: non è una dichiarazione di assenza di qualsiasi errore del motore.

### Telemetria delle simulazioni

Il nuovo `AIAudit` conta gli eventi di passaggio anziché il tempo trascorso in ciascuna etichetta tattica. Tutte le simulazioni sono IA contro IA, modalità partita con panchina, difficoltà Normale.

| Seed del gameplay | Passaggi prima | Passaggi dopo | Tentativi prima* | Tentativi dopo* | Errori GDScript prima / dopo |
|---|---:|---:|---:|---:|---:|
| 41 | 20 | 39 | 5 | 9 | 0 / 0 |
| 73 | 35 | 31 | 6 | 9 | 0 / 0 |
| 109 | 19 | 40 | 7 | 8 | 1945 / 0 |

\* Contatore `total_attempts` del motore, non una misura completa e validata di tutti i tiri/liberi. Non è usato per calcolare percentuali realizzative.

**Limiti:** tre run non dimostrano un miglioramento statistico del bilanciamento. Il seed viene impostato dopo la creazione della scena; roster iniziale e timer basati sul tempo reale non rendono le run identiche. La run precedente con seed 109 era inoltre compromessa dagli errori. I dati sono una verifica esplorativa, non una promessa di più passaggi o più punti in ogni partita.

## Problemi rimasti e prossima priorità

- Nelle tre simulazioni aggiornate il watchdog ha recuperato complessivamente **4 possessi bloccati**. La correzione del destinatario eliminato non risolve quindi ogni possibile stallo. La prossima priorità tecnica è registrare lo stato completo di questi possessi prima del recupero e correggerne la causa.
- Sono rimaste infrazioni di ingresso nell'area laterale: migliorare il percorso di consegna e uscita è il prossimo intervento tattico consigliato.
- Restano avvisi di risorse alla chiusura e diagnostiche del renderer dummy nei test headless.
- Non effettuati collaudo grafico, prova su dispositivo Android o misurazione delle prestazioni sul telefono.

## File e riproduzione

Aprire `baskin_academy/project.godot` in Godot 4.3. I sorgenti includono anche le correzioni precedenti a input, salvataggi e sostituzioni.

```bash
godot --headless --path baskin_academy res://tools/AITeamworkProbe.tscn
godot --headless --path baskin_academy res://tools/AIPassLifetimeProbe.tscn
# Seed del gameplay e durata in secondi simulati:
godot --headless --path baskin_academy res://tools/AIAudit.tscn -- 41 180
# Batteria completa, su un profilo di sviluppo:
GODOT=/percorso/godot bash strumenti/run_battery.sh
```

I test storici possono modificare dati/impostazioni locali. I risultati di questa revisione sono in `verifiche-ia/`, con confronto JSON, log prima/dopo e patch dei tre sorgenti di gioco modificati.

## Consegna

**Sorgenti aggiornati, non un nuovo APK.** La versione rimane 1.15.0; prima della distribuzione occorre incrementare le versioni, ricompilare, firmare e collaudare su Android. Lo ZIP non contiene cache, chiavi ADB o un APK presentato come aggiornato. L'originale scaricato rimane in workspace come `originale.zip`.
