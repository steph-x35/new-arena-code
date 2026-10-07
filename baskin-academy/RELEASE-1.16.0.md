# Baskin Academy 1.16.0 — APK aggiornato

**File da installare:** `BaskinAcademy-v1.16.0.apk`, nella cartella principale del workspace.

| Campo | Valore verificato |
|---|---|
| Versione | 1.16.0 |
| versionCode | 18, prima era 17 |
| Pacchetto | com.baskinacademy.app |
| Architettura | ARM64 / arm64-v8a |
| Dimensione | 31.076.336 byte, circa 29,6 MiB |
| minSdk / targetSdk | 21 / 34 |
| Firma | Stessa chiave di debug dell'APK originale, verificata con apksigner |
| Schemi di firma | v1, v2 e v3 verificati |
| SHA-256 APK | 9066885f7bf828d918476365dc2d61eda39d6adf382420505aab32c0041813d2 |

## Palleggio: valutazione e modifiche

Il palleggio è funzionale e leggibile nello stile grafico 2D dell'app, ma resta un'animazione stilizzata, non una simulazione fisica completa del gesto.

Già presenti e controllati: rimbalzo al pavimento, palleggio più basso sotto pressione, mano sopra il pallone e gomito piegato entro la portata del braccio. Nel test finale della posa: gomito piegato in tutti i 97 campioni; il test del palleggio libero misura uno scarto massimo palla/offset di circa 3,26 pixel, entro la soglia del test. Sono state anche ispezionate immagini prodotte con il renderer OpenGL software; questo non sostituisce una prova di fluidità sul telefono.

Correzioni aggiunte in questa release:

1. **Cambio mano senza scatto laterale:** crossover, dietro la schiena, cambio mano e tra le gambe partono dal lato originale e terminano sul nuovo lato. Prima l'animazione usava già la mano invertita e poi tornava bruscamente al lato opposto.
2. **Mano disegnata coerente con il lato della palla** durante il movimento.
3. **Ritmo continuo:** la fase del rimbalzo avanza nel tempo. Cambiare velocità o pressione difensiva non riscrive più la fase moltiplicando tutto il tempo trascorso per un nuovo coefficiente.
4. **Altezza che si adatta gradualmente** quando arriva o si allontana un difensore.
5. **Cadenza meno frenetica in corsa:** circa 1,9 rimbalzi al secondo da fermo e 3,0 in corsa libera alla velocità di riferimento; sotto pressione il ritmo può aumentare. Sono scelte di animazione, non misure di un atleta reale.

## Tutte le correzioni precedenti sono incluse

- Passaggi più sensati sotto pressione e rispetto delle restrizioni sulle consegne al pivot.
- Pick-and-roll senza coinvolgere impropriamente i pivot; ritorno a difesa/attacco con palla quando cambia la situazione.
- Sostituzioni e rimesse protette da riferimenti a giocatori rimossi.
- Countdown e timeout distinti dai veri possessi bloccati, lasciando attivo il recupero dei blocchi reali.
- Consegna al pivot su un lato stabile e uscita dall'area verso l'interno del campo.
- Azzeramento del timer di permanenza nell'area quando il giocatore esce.
- Correzioni ai controlli touch nascosti e alla gestione dei salvataggi.

## Verifica della release

- **22 scene di test con esito positivo** nell'ultima batteria; nessun SCRIPT ERROR.
- Nuovo DribbleContinuityProbe: **11 controlli superati**. Gli otto controlli sui cambi mano fallivano prima della correzione.
- Durante la prima batteria di questa sessione, Rule9Probe aveva segnalato uno scarto palla/offset; il problema di discontinuità del ritmo/altezza è stato affrontato e la batteria finale, ripetuta prima della build definitiva, passa.
- Una simulazione IA contro IA ha completato i quattro quarti: circa **558 secondi simulati**, risultato **34–44**, 111 passaggi. Nessun errore GDScript, nessun recupero del watchdog e nessuna infrazione `v_area_in` in questa esecuzione. Tre infrazioni dei tre secondi sono invece state registrate. Il valore interno `quarter=5` è il contatore dopo la conclusione del quarto quarto, non un quinto quarto giocato.
- Export Android completato, integrità dello ZIP/APK controllata, versione/pacchetto/architettura e firma verificati sul file consegnato. Nessun file sotto `assets/tools/` nell'APK.

**Limiti:** nessuna installazione o prova su un dispositivo Android reale in questa sessione. I test headless segnalano ancora risorse trattenute all'uscita e diagnostiche del renderer dummy sulle texture: non sono stati risolti qui. Le simulazioni non garantiscono che tutti i casi possibili siano privi di problemi. La firma è quella di debug del progetto, non una firma di produzione per il Play Store.

## Installazione

Scaricare l'APK sul telefono Android ARM64 e aprirlo. Se richiesto, autorizzare l'installazione da quella sorgente. Provare l'aggiornamento sopra la versione precedente: package e certificato coincidono e versionCode è aumentato. **Non disinstallare preventivamente**, per non rischiare di perdere i dati locali. Se Android rifiuta l'aggiornamento, conservare l'app esistente e comunicare il messaggio esatto.

## Prossimi miglioramenti consigliati

1. Raccolta della palla, esitazione e transizioni tra palleggio e tiro più naturali, coordinando meglio appoggi dei piedi e mano.
2. Percorsi di smarcamento e passaggi anticipati sul movimento del compagno, verificando che non aumentino i passaggi inutili.
3. Prestazioni e leggibilità su un telefono reale, soprattutto durante sostituzioni, effetti del pubblico e animazioni del campo.

Sorgenti aggiornati in `progetto/baskin_academy/`; log della release in `verifiche-release/`. Questa consegna sostituisce la precedente nota «APK da compilare»: **l'APK 1.16.0 è stato effettivamente generato e verificato**.
