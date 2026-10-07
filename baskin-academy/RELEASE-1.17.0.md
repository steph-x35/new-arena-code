# Baskin Academy 1.17.0 — feedback su regole, palleggio e rimesse

27 settembre 2026. APK consegnato: `BaskinAcademy-v1.17.0.apk` nella cartella principale.

## I sei interventi richiesti

1. **Regole leggibili.** Il pannello del fallo L mostrava un segnaposto `%d`: il titolo della regola e il messaggio con il numero di maglia usavano la stessa traduzione. Ora il titolo è «FALLO L · DIFESA IRREGOLARE»; il messaggio separato riporta il numero effettivo. Controllate le stringhe dei pannelli in italiano e inglese, senza segnaposto di formattazione o `&amp;` residui.
2. **Braccio del palleggio più morbido.** Sostituiti i due segmenti con spigolo evidente con una curva continua, con estremità arrotondate. Il gomito proiettato piega verso il basso e l'esterno, senza ripiegarsi sul petto; la forma varia mentre la mano accompagna il pallone. Restano condivise le coordinate di mano e palla. È un'animazione 2D stilizzata, non una simulazione anatomica completa.
3. **Anello di atterraggio rimosso.** Non viene più disegnato il cerchietto tratteggiato che anticipava dove sarebbe caduta la palla. La previsione fisica rimane disponibile all'IA per il rimbalzo; resta la piccola ombra naturale del pallone.
4. **Chiamata della rimessa immediata.** Tolta l'attesa fissa di 0,35 secondi dopo la chiamata. Il passaggio parte nello stesso frame; resta il tempo del volo visibile, con una velocità maggiore specifica per la rimessa. La ricezione non è un teletrasporto. Nel caso controllato del test, il volo laterale dura circa 0,15–0,20 secondi; la durata effettiva dipende dalla distanza.
5. **Avversari già in marcatura.** Durante la preparazione della rimessa i difensori IA vengono sistemati vicino ai propri attaccanti, tra uomo e canestro, rispettando le assegnazioni di ruolo e le aree laterali protette. Lo spostamento verso il pallone è limitato: non trascina più il difensore lontano dal tiratore. Durante l'attesa continuano a seguire il proprio uomo anche nelle rimesse automatiche. Il personaggio controllato dall'utente non viene riposizionato automaticamente in difesa.
6. **Dissolvenza prima della rimessa.** Breve transizione scura con scritta «RIMESSA»: 0,12 secondi in entrata e 0,18 in uscita. Il campo viene predisposto sotto la dissolvenza. L'effetto non cattura i tocchi: una chiamata anticipata viene ricordata e parte appena termina la preparazione. Le callback di una rimessa precedente non possono riattivarsi sopra una nuova rimessa.

## Verifiche

- Batteria di **23 scene di test** con esito positivo. Dopo l'ultimo affinamento grafico del gomito sono stati rieseguiti `Rule12Probe` e `InboundUXProbe`, entrambi superati, prima della build definitiva.
- Nuovo `InboundUXProbe`: **23 controlli** su testi IT/EN, forma del braccio, assenza dell'anello, trasparenza animata, input durante la dissolvenza, marcatura, rilascio immediato, volo della palla, doppia chiamata e riavvii sovrapposti.
- Partita IA completa di quattro quarti: circa **545 secondi simulati**, risultato **33–42**, 141 passaggi. Nessun `SCRIPT ERROR`, nessun recupero del watchdog; una violazione dei tre secondi registrata. È una verifica esplorativa, non una garanzia statistica di assenza di bug.
- Controllo visivo con renderer OpenGL software: quattro fasi del braccio, pannello fallo L, dissolvenza e disposizione della rimessa.
- APK esportato, integrità ZIP controllata e firma verificata con `apksigner`; strumenti di sviluppo esclusi dall'APK.

Al primo passaggio della batteria sono emersi un timeout del vecchio probe delle regole e un fallimento del probe sostituzioni. Il probe delle regole è stato isolato dalle decisioni casuali dell'IA e adattato alla preparazione asincrona della rimessa. È stato inoltre corretto un controllo che poteva mantenere riservati alla rimessa i suoi partecipanti anche quando `restarting` era già terminato. I probe sul vecchio indicatore e sul vecchio schieramento sono stati aggiornati alle nuove richieste, conservando la verifica della previsione fisica e delle marcature.

## APK

| Campo | Valore |
|---|---|
| Versione / codice | 1.17.0 / 19 |
| Pacchetto | `com.baskinacademy.app` |
| Architettura | ARM64, come l'APK precedente |
| Dimensione | 31.092.720 byte, circa 29,7 MiB |
| Firma | Stessa chiave di debug del progetto e delle versioni precedenti |
| SHA-256 | `9975d0e93230ca89c800da4e5ef632540e788a71de15ac8de5f247d6f7a2722e` |

Installare sopra la versione precedente, **senza disinstallare preventivamente**, per non rischiare di perdere i dati locali. Se Android richiede l'autorizzazione per questa sorgente, concederla soltanto se si intende installare il file scaricato qui.

**Limiti:** nessuna prova su telefono Android reale in questa sessione. Restano le diagnostiche già note del renderer headless e di risorse trattenute all'uscita; non sono state dichiarate risolte. La fluidità e il gradimento del nuovo braccio vanno confermati sul dispositivo.

Sorgenti in `progetto/baskin_academy/`, log e immagini in `verifiche-1.17/`. La build include anche le correzioni precedenti a gameplay, controlli touch e salvataggi.
