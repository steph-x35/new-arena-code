# Baskin Academy — continuità di gioco e prossimo APK

Revisione del 26 settembre 2026. Sorgenti basati sulla 1.15.0, comprensivi di tutte le correzioni precedenti.

## Interventi completati

- **Ripartenza tra i quarti:** la diagnostica ha mostrato il watchdog intervenire quando mancavano circa 0,15 secondi al GO. Il conto alla rovescia ora comunica al campo una breve protezione temporizzata (3,5 secondi), che scade: un blocco reale rimane recuperabile.
- **Timeout:** i quattro secondi del timeout non vengono più scambiati per un possesso bloccato dopo tre secondi.
- **Rimesse:** mittente e destinatario rimangono disponibili fino al rilascio; i cambi in coda aspettano anche prima che esista `ball.pass_target`. Protezione applicata anche all'uscita/rientro del giocatore principale.
- **Identità del giocatore:** le sostituzioni generiche non possono eliminare il nodo del giocatore principale quando è guidato dall'IA, né quello del suo sostituto automatico. Entrambi continuano a usare il percorso di rotazione dedicato.
- **Consegna al pivot:** lato di avvicinamento scelto una volta per azione, in base alla posizione del portatore, anziché sorteggiato a ogni frame. Nessun cambiamento alle probabilità di tiro.
- **Uscita dall'area laterale:** il bersaglio di uscita punta all'interno del campo, evitando di spingere il giocatore verso la linea laterale dove verrebbe bloccato.
- **Tempo nell'area:** uscire dall'area azzera il conteggio; una nuova entrata non eredita i secondi della visita precedente. Limiti temporali e sanzioni non sono stati allentati.

## Verifiche effettuate

- Nuovo `ContinuityProbe`: prima delle modifiche **7 fallimenti su 8 controlli**. Dopo le correzioni e l'aggiunta di tre controlli sulla protezione del countdown: **11/11 superati**.
- Batteria completa di questa revisione: **21 scene di test con esito positivo** e senza SCRIPT ERROR.
- Tre simulazioni IA contro IA, difficoltà Normale, partite con panchina, 180 secondi simulati ciascuna:

| Seed del gameplay | Passaggi | Punteggio | Quarto raggiunto | Errori GDScript | Recuperi watchdog | Infrazioni v_area_in |
|---|---:|---|---:|---:|---:|---:|
| 41 | 33 | 7–11 | 2 | 0 | 0 | 0 |
| 73 | 35 | 16–14 | 2 | 0 | 0 | 0 |
| 109 | 35 | 12–12 | 2 | 0 | 0 | 0 |

- Importazione Godot 4.3 senza errori di parsing; controllo differenze e sintassi shell superati.

### Limiti

I risultati non dimostrano che ogni possibile blocco sia risolto. Le simulazioni non sono replay deterministici completi: il seed del gameplay viene impostato dopo la creazione della scena. Non sono partite intere e non coprono ancora tutte le transizioni di fine partita. Rimangono avvisi headless relativi a texture e risorse trattenute all'uscita. Nessun collaudo grafico o su dispositivo Android effettuato.

Il warning del watchdog in `ContinuityProbe` è intenzionale: il test forza un vero arresto senza una ragione valida, per verificare che la rete di recupero funzioni ancora.

Log in `verifiche-continuita/before/` e `verifiche-continuita/after/` nel workspace.

## Preparazione del prossimo APK

**Richiesta dell'utente: consegnare l'APK al prossimo giro. Non è stato compilato in questa revisione.**

Controlli completati:

- Godot 4.3 e JDK 11 disponibili nell'ambiente corrente.
- Preset Android esistente: `com.baskinacademy.app`, ARM64, firma abilitata.
- La chiave `baskin_academy/keystore/debug.keystore` corrisponde al certificato incluso nell'APK originale. Impronta SHA-256 verificata:
  `60:12:DD:C6:22:9E:66:DD:02:EB:AF:71:D4:24:C3:30:45:61:AE:1A:DE:BA:AA:DF:A4:B1:9D:DB:BD:52:94:F3`.
- Sistemati i percorsi nello script di preparazione e aggiunto `strumenti/build_android.sh`, che configura i percorsi Android dell'editor, esporta e verifica la firma. Sintassi verificata; esecuzione completa ancora da fare.

### Checklist per la consegna successiva

1. Eseguire gli ultimi test e decidere la versione di rilascio. Proposta: **1.16.0, versionCode 18**. I sorgenti e il preset sono ancora a 1.15.0 / 17: aggiornarli insieme solo per la build nuova.
2. Eseguire `bash progetto/strumenti/build_android.sh`. Lo script installa i componenti mancanti tramite `setup_build_env.sh`: Android SDK/build-tools 34 e template Godot 4.3. Sono cache e potrebbero dover essere reinstallati dopo il ripristino del workspace.
3. Verificare l'APK con `apksigner`, package name, versionCode e impronta del certificato; confrontare con l'originale.
4. Copiare l'APK verificato in un percorso di consegna chiaro e presentarlo all'utente. Non confonderlo con l'APK 1.15.0 contenuto in `originale.zip`.
5. Dichiarare l'eventuale assenza di test su dispositivo. La firma è ancora quella **di debug del progetto**: non presentarla come firma di produzione o approvazione Play Store.

La coincidenza di package e firma serve per l'aggiornamento della stessa app. La compatibilità effettiva dell'installazione andrà comunque verificata sul dispositivo; non chiedere di disinstallare preventivamente, per evitare la perdita dei dati.


## Pipeline APK su GitHub (da v1.19.0)

L'APK ora si può compilare su GitHub Actions, senza computer locale:
workflow **Baskin APK** (`.github/workflows/build-apk-baskin.yml`).
Bottone: repo → scheda **Actions** → **Baskin APK** → **Run workflow**.

### Perché serve il keystore

L'APK va firmato con la STESSA chiave dell'app già installata, altrimenti
Android rifiuta l'aggiornamento («App not installed»). La chiave NON può
stare in un repo pubblico: viaggia solo nei GitHub Secrets.

### Configura i 4 secret (una volta sola, ~5 minuti)

1. Apri il repo su GitHub → scheda **Settings** (barra in alto) → colonna
   sinistra **Secrets and variables** → **Actions** → bottone verde
   **New repository secret**.
2. Primo secret, nome `KEYSTORE_BASE64`: serve il keystore convertito in
   testo. Se hai il file `debug.keystore` del vecchio progetto, chiedi la
   conversione qui in chat e incolla il risultato nel campo Value.
   (In locale su Mac/Linux sarebbe: `base64 -i debug.keystore -o firma.b64`,
   poi apri `firma.b64` con un editor di testo e copia TUTTO il contenuto.)
3. Secondo secret `KEYSTORE_PASSWORD`: la password del keystore (per il
   debug keystore di Godot è `android`).
4. Terzo secret `KEY_ALIAS`: il nome della chiave (per il debug keystore di
   Godot è `androiddebugkey`).
5. Quarto secret `KEY_PASSWORD`: la password della chiave (di solito uguale
   a quella del keystore: ripetila lo stesso).
6. Finito. Actions → **Baskin APK** → **Run workflow**: run verde = APK
   pronto nella sezione **Artifacts** in fondo alla pagina del run. Per una
   Release pubblica: crea un tag `baskin-v1.19.0` e pushalo, la Release con
   l'APK allegato si crea da sola.

Il vecchio keystore di debug (impronta SHA-256
`60:12:DD:C6:22:9E:66:DD:02:EB:AF:71:D4:24:C3:30:45:61:AE:1A:DE:BA:AA:DF:A4:B1:9D:DB:BD:52:94:F3`)
serve SOLO per continuare ad aggiornare l'APK già distribuito; per ripartire
da zero (nuova installazione) va bene anche un keystore nuovo.

Il preset Android resta `com.baskinacademy.app`, ARM64, versionCode 21,
firma in `keystore/release.keystore` (file git-ignorato: la CI lo crea dai
secret al volo).
