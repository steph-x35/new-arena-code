# BaskinAcademy 1.18.0

## Modifiche richieste

- **Palleggio più alto:** apice normale al 56% dell'altezza base del corpo; leggermente ridotto in corsa e sotto pressione, ma ancora vicino a metà corpo. Il contatto a terra resta al raggio della palla. Conservato il braccio curvo della 1.17.
- **CAMBIO:** riprodotto in amichevole 5v5 l'accesso a una riga inesistente della panchina (`Invalid access of index '1'`, `_fill_subs`). Ora le amichevoli hanno una vera panchina e cambi manuali; le rotazioni automatiche restano riservate alle gare ufficiali. Il pannello controlla roster, disponibilità e validità dei giocatori, risolve le selezioni tramite ID e blocca i controlli di gioco sottostanti. Sicuri anche doppia apertura e giocatore rimosso mentre il pannello è aperto. In 1v1 i cambi non vengono offerti.
- **Dissolvenza:** da 0,30 a 1,00 secondo, con 0,40 in entrata e 0,60 in uscita, mantenendo la curva morbida. Le chiamate anticipate della rimessa restano accodate e il passaggio resta fisico.
- **DIFENDI:** postura dell'utente soltanto durante la pressione del pulsante; ripristino immediato al rilascio. La postura viene annullata anche prendendo possesso, uscendo dal campo o aprendo CAMBIO. La difesa autonoma degli NPC è conservata.

## Correzioni collegate

- Il sostituto personale eredita ruolo e caratteristiche dell'utente: il cambio non deve alterare la composizione regolamentare.
- Rientro manuale dalla panchina in amichevole, senza attendere un allenatore automatico che in quella modalità non opera.
- Panchine visibili anche nelle amichevoli; testi della scelta modalità e del riposo aggiornati.
- Le riserve già richieste non vengono proposte come libere per una seconda richiesta.

## Verifiche

- **27 scene di regressione superate**, contando la riesecuzione corretta di RuleProbe. Il primo passaggio di RuleProbe aveva due verifiche fallite perché misurava la rimessa prima del termine della nuova dissolvenza. Il tempo di attesa è stato legato alle costanti della transizione; gli stessi controlli sul pallone fermo e sul passaggio visibile sono poi passati. Log iniziale conservato.
- Nuovo **PlayerFeedbackProbe: 25 controlli, zero fallimenti**, incluse sostituzioni effettive in amichevole, rientro personale, ruolo del sostituto, pannelli obsoleti, roster mancante, difesa premuta/rilasciata e apice del palleggio in tre condizioni e tre altezze.
- Partita IA completa, seed 311: **571,8 secondi simulati, 32–40, 129 passaggi**, nessun SCRIPT ERROR e nessun DEAD_STATE registrato. Verifica esplorativa, non prova statistica di assenza di difetti.
- Controllo grafico con OpenGL software: quattro fasi del palleggio, postura con DIFENDI premuto e rilasciato, pannello cambi in amichevole e dissolvenza.
- APK esportato e firmato; integrità ZIP verificata; strumenti di sviluppo esclusi dall'APK.

## APK

- File: `BaskinAcademy-v1.18.0.apk`
- Pacchetto: `com.baskinacademy.app`
- Versione: **1.18.0**, versionCode **20**
- Architettura: ARM64
- Dimensione: 31.092.720 byte
- SHA-256: `bd3f7947d267d5cf3e08680fafd9bceef599881f74ff8afd00a9decf1288ff55`
- Certificato SHA-256: `6012ddc6229e66dd02ebaf71d424c3304561ae1adebaaadfa4b19ddbbd5294f3`, stessa chiave Android Debug della versione precedente.

Installare sopra la precedente versione senza disinstallare, per conservare i dati locali.

## Limiti e prossimi interventi proposti

**Nessun test su telefono Android reale.** È stato riprodotto e corretto un errore dello script CAMBIO, non una terminazione nativa del processo Android. La risoluzione della chiusura segnalata e la fluidità percepita richiedono una prova sul dispositivo. Restano diagnostiche note del renderer headless e risorse trattenute all'uscita: non vengono dichiarate risolte.

Due problemi di presentazione osservati, lasciati per il prossimo intervento concordato:
1. Nella formazione possono comparire numeri di maglia duplicati: nella schermata acquisita utente e compagno hanno entrambi il numero 5.
2. Se si seleziona l'utente, il sistema usa il sostituto personale dedicato: il pannello attuale dovrebbe distinguere questo percorso dalla scelta di una riserva per gli altri giocatori.

Evidenze in `verifiche-1.18/`; riepilogo conclusivo in `final-summary.txt`. Conservato l'APK 1.17.0 precedente.
