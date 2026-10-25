# 💣 REEL «TI LICENZI: QUANTO TI SPETTA?» — produzione completa

> **Formato: registrazione dello schermo del sito. Non card su fondo scuro.**
> È il formato del reel da **209k**. **20 secondi** (girato il 22/10).
> Caso reale, tutto anonimo. Numeri verificati riga per riga sul calcolatore.

---

## ✅ ESITO (pubblicato 22/10 ore 20, letto il 25/10)

| | 24h | 72h |
|---|---|---|
| Views | 6.510 | 6.510 |
| Like | 7 | **30** |
| Commenti | 3 | **14** |
| Save | 1 | **9** |
| Click Linktree | 1 | 1 |

**Tasso di like: 0,11% → 0,46%.** Il video cresce mentre dorme (7 → 30 like
in tre giorni): non si giudica a 24h.

**Cosa ha funzionato:** il formato screencast (6.510 views da un account a 458
follower) e la CTA nei commenti — la gente ha scritto davvero anni + stipendio.

**Cosa non ha funzionato:** il click. 1 su 6.510 = 0,015%. Causa fisica, non
creativa: sotto i 1.000 follower il campo sito di TikTok non esiste, quindi
«calcolatore in bio» mandava a una porta murata. **Mai più «in bio».**

**Lezione:** un video puo' essere guardato e non amato. Il like era il segnale
mancante, ed e' per questo che dal v26 il like si chiede subito dopo il numero.

---

## 0 — L'errore da non ripetere

Questo documento era stato scritto con **card testo su fondo scuro, 13 secondi**.
È il formato sbagliato, e i tuoi dati lo dicono chiaro:

| Reel | Formato | Views |
|---|---|---|
| «Lavori da 5 anni nella stessa azienda?» | **registrazione del sito** | **209.000** |
| «Lavori da 10 anni…» (stesso format) | registrazione del sito | (seguito della serie) |
| «36 anni» | card scure | 1.389 |
| «8 ore / 6 pagate» | card scure | 967 |
| «Ferie non godute» | card scure 13s | poche centinaia |

Le card scure sono già state provate **quattro volte** e hanno sempre fatto
numerate. Il 209k è venuto dalla **registrazione dello schermo**: si vede il
numero nascere mentre lo digiti.

**Regola:** non si cambia il formato che ha fatto il 209k. Si cambia il soggetto.

---

## 1 — Perché funziona la registrazione

Il pubblico non guarda una guida: guarda **un numero che appare**. La sequenza
«digito lo stipendio → la RAL si aggiorna da sola → esce il TFR» è una piccola
sorpresa, e la sorpresa è quello che tiene incollati. Le card scure, invece,
danno il numero subito e non lasciano niente da aspettare: chi l'ha visto
scorre, perché ha già ricevuto tutto nel primo fotogramma.

---

## 2 — ⚠️ I numeri: due trappole

### Trappola 1 — La cifra vecchia del piano (12.500) è sbagliata
Il piano diceva `TFR ≈ 12.500 lordi`. Quel numero includeva le **rivalutazioni
ISTAT**, che il calcolatore del sito **non calcola**. Chi lo digitava trovava
un'altra cifra e ci smontava nei commenti.

### Trappola 2 — Il calcolatore sincronizza a **13 mensilità**, non 14
In `calcolo-tfr/app.js` la sincronizzazione è letteralmente:

```js
$('#tfr-mensile').value = Math.round(v / 13)   // RAL  -> mensile
$('#tfr-ral').value     = Math.round(v * 13)   // mensile -> RAL
```

Quindi **se nel video digiti lo stipendio mensile, la RAL che appare è ×13**.
Se usassi il calcolo a 14 mensilità (11.689 €) il video mostrerebbe un numero
che **non si riproduce** sullo schermo di chi ti guarda.

### Il conto giusto, rifatto col codice del sito

Stipendio lordo mensile reale del caso: `9,0956 €/h × 173,33 h = **1.576,54 €**`
→ si digita **1.577**.

| Passo | Valore a schermo |
|---|---|
| Mensile lordo digitato | **1.577 €** |
| RAL sincronizzata (×13) | **20.501 €** |
| Quota TFR annua (RAL/13,5 − 0,5%) | 1.416,09 € |
| Anzianità | 7 anni e 8 mesi |
| **TFR LORDO** | **10.857 €** |
| Tassazione separata (23%) | −2.497 € |
| **TFR NETTO** (il numero grande a schermo) | **8.359,64 €** → nel testo **8.360 €** |

**Da dire nel video: 10.857 lordi · 8.360 netti.**
Le cifre esatte che compaiono a schermo sono **10.856,67 €** e **8.359,64 €**:
i centesimi restano visibili durante lo zoom, l'overlay arrotonda. Non è un
errore e non va nascosto — anzi, i centesimi fanno sembrare il conto vero.
**Da non dire: 12.500 (rivalutazioni) · 11.689 (14 mensilità).**

Verifica indipendente: `10.857 × +13% di rivalutazioni ISTAT su 7 anni e 8 mesi
≈ 12.270` — ecco da dove nasceva il 12.500 del piano.

E la voce ferie, verificata: `9,0956 × 8 ore = **72,76 € al giorno**` (esatta).

---

## 3 — Il copione: com'è fatto il girato e come si taglia

### Preparazione (3 minuti)

1. Telefono in **verticale**, **Non disturbare** attivo
2. Connetti il caricabatterie (la registrazione prosciuga)
3. Apri **una sola scheda**: `https://steph-x35.github.io/new-arena-code/calcolo-tfr/`
4. Zoom del browser al **110%** (i numeri devono essere grandi)
5. Cancella la cronologia recente dalla barra: **nessun nome, nessun account a schermo**
6. Avvia la registrazione schermo

### Le mosse — timeline da **20 secondi**

Il girato è di ~20 s: non si ri-registra, si **taglia** su questa griglia.

| Tempo | Cosa si vede | Testo in sovrimpressione |
|---|---|---|
| **0 – 1,5 s** | **fermo** sul calcolatore vuoto | **Ti licenzi dopo 7 anni?** (grande, bold, in alto) |
| **1,5 – 4,5 s** | digiti **1577** nel campo *Retribuzione Mensile Lorda* | — |
| **4,5 – 6,5 s** | ⚡ la **RAL si compila da sola: 20.501** — **1 secondo fermo**, è il momento bello | — |
| **6,5 – 9 s** | digiti **7** negli anni e **8** nei mesi | — |
| **9 – 11 s** | scrolli e i risultati si aggiornano | — |
| **11 – 15 s** | **zoom** sul numero grande | **8.360 € NETTI** (giallo) |
| **15 – 18 s** | resti sul numero | **E tu? Scrivi anni + stipendio 👇** |
| **18 – 20 s** | **torni sul primo fotogramma** (calcolatore vuoto + domanda) | — |
| **fine** | ↻ riparte da 0 — il loop è invisibile | — |

**Il CTA non è l'ultima cosa.** L'ultima cosa è il **ritorno al primo
fotogramma**: è quello che rende il loop invisibile. Se il video finisce sulla
frase "scrivi gli anni", la ripartenza si vede come uno stacco e il loop non
funziona.

**Cosa non tagliare mai:** il secondo fermo sul 20.501 (4,5–6,5 s). È
l'unico punto in cui succede qualcosa che lo spettatore non si aspetta.
Se devi togliere roba, toglila dalla digitazione degli anni.

**Cosa guarda il sito in quel momento:** il riquadro risultati mostra
`TFR Netto stimato liquidabile` in grande e, appena sotto, `TFR Lordo totale:
10.856,67 €`. Quindi lo zoom **contiene già entrambi i numeri**: non serve
sovrapporre altro, basta che l'inquadratura li prenda tutti e due.

---

## 4 — IL LOOP: come si fa davvero

Il loop non è "il video ricomincia": è **l'ultimo fotogramma che è identico al
primo**. Se sono identici, la ripartenza è invisibile; TikTok e Shorts contano
la seconda visione e la leggono come "questo video aggancia". È il motivo per
cui i reel brevi possono superare il 100% di spettatori che arrivano in fondo.

### Procedura in CapCut (5 minuti)

| Passo | Cosa fare |
|---|---|
| **1** | Porta il cursore a **1,5 s** (fine dell'hook, prima che inizi la digitazione) e premi **Dividi** |
| **2** | Ora hai `Clip A` = 0–1,5 s. Selezionala → **Copia** (icona due fogli) |
| **3** | Porta il cursore **alla fine della timeline** → **Incolla** |
| **4** | **Taglia la coda** della clip appena incollata: deve durare **1,2–2 s**. Meno è meglio |
| **5** | **Zoom sul bordo destro** (tasto + della timeline) e trascina il bordo finché l'ultimo fotogramma **non è identico al primissimo**: devono combaciare, altrimenti si vede un lampeggio di 1 frame |
| **6** | Il testo «Ti licenzi dopo 7 anni?» è su una **pista separata**: duplicalo anche sull'ultimo segmento, così riappare insieme all'immagine |
| **7** | **Nessuna transizione, nessun fade.** Taglio netto. Il fade tradisce il loop |
| **8** | Musica: se ha un battito, **fai cadere il taglio sul battito**. Se non cade, abbassa l'audio negli ultimi 0,3 s (ma **non** l'immagine) |
| **9** | **Prova**: guarda il video in ciclo 4 volte di fila. Se al 3°, 4° giro **non distingui** dove ricomincia, il loop è fatto |

### Come verificare che sia venuto (senza fidarsi dell'occhio)

Esporta, poi nel rullino del telefono apri il video, **fermati sull'ultimo
frame**, torna all'inizio e **confronta**: la barra di stato, l'ora, il cursore,
la posizione dei numeri devono essere **identici**. Se c'è anche solo un numero
diverso (es. il campo RAL ancora compilato), hai preso il fotogramma sbagliato.

### Gli errori che rompono il loop

| Errore | Perché si vede |
|---|---|
| Finire sul CTA | la frase sparisce di colpo → stacco evidente |
| Finire sul risultato | il numero grande diventa il calcolatore vuoto → salto forte |
| Mettere 4-5 s di ritorno | sembra che il video sia finito e continui a girare → la gente scorre |
| Aggiungere un fade | il nero in mezzo al ciclo si nota subito |
| Ultimo frame ≠ primo frame | lampeggio di 1 frame, l'occhio lo becca sempre |
| Musica che riparte a metà frase | l'orecchio lo sente prima dell'occhio |

### Se non ti riesce

Alternativa accettabile: **chiudere sul numero**, senza ritorno. Perdi il loop
ma non rovini niente. Quello che **non** si fa è chiudere sul CTA.

---

## 5 — Montaggio (CapCut, 10 minuti)

| Passo | Cosa fare |
|---|---|
| 1 | Progetto **9:16**, 1080×1920, 30 fps |
| 2 | Importa la registrazione: **taglia testa e coda** (dove tocchi per fermare) |
| 3 | Riallinea sulla griglia dei 20 s del §3 — **non serve rigirare** |
| 4 | Se la digitazione è lenta, **velocità 1,5×** solo su quel tratto: il sync deve arrivare entro il **6,5° secondo** |
| 5 | **Testo 1** (0–1,5 s **e** 18–20 s): «Ti licenzi dopo 7 anni?» — bianco, bold, in alto |
| 6 | **Testo 2** (11–18 s): «8.360 € netti» — giallo `#FFC43D`, grande, sul numero |
| 7 | **Testo 3** (15–18 s): «E tu? Scrivi anni + stipendio 👇» |
| 8 | **Testo 4** (ultimi 2 s del CTA): «Calcolatore gratis in bio 🔗» |
| 9 | **Loop** → §4, rifallo alla fine: è l'ultima cosa prima dell'export |
| 10 | Audio: «dark suspense» o «tense piano», **colpo a 0:00**, volume **30–40%** |
| 11 | Export **1080×1920, 30 fps**, un file unico per TikTok e YouTube |

**Zona sicura:** testi fuori dai **320 px in basso** e **120 px a destra**
(altrimenti l'interfaccia di TikTok li copre).

**Ordine di lavoro consigliato:** prima taglia e metti i testi, poi **per
ultimo** il loop. Se fai il loop prima e poi cambi durata, lo devi rifare.

---

## 6 — Testi pronti da incollare

### TikTok — Caption

```
7 anni e 8 mesi nello stesso lavoro: di TFR sono 10.857 € lordi, 8.360 € netti.

E la maggior parte delle persone non lo sa finché non si licenzia.

Quanto spetta a te? Scrivi gli anni nei commenti 👇
#licenziamento #tfr #bustapaga #lavoro #dimissioni
```

### TikTok — Commento fissato

```
Scrivete anni di lavoro + stipendio lordo mensile e vi dico l'ordine di grandezza del TFR 👇
(per il conto esatto serve il prospetto di liquidazione, ma già così capite se vi stanno pagando giusto)
```

⚠️ Prometti «l'ordine di grandezza», non «la cifra esatta». È la linea dei tuoi DM
ed è quella che ti rende credibile.

### YouTube — Titolo

```
Ti licenzi dopo 7 anni? Quanto prendi davvero di TFR
```

### YouTube — Descrizione

```
10.857 € lordi di TFR, 8.360 € netti. Per 7 anni e 8 mesi di lavoro.
Calcola il tuo in 30 secondi 👇

https://steph-x35.github.io/new-arena-code/calcolo-tfr/

Le lettere pronte (dimissioni, giusta causa, sollecito del TFR):
https://steph-x35.github.io/new-arena-code/lavorofacile/

⚠️ Stima indicativa: la liquidazione ufficiale può variare per rivalutazioni
ISTAT e accordi di secondo livello. Per le cifre ufficiali serve un commercialista.

#shorts #tfr #licenziamento #bustapaga
```

Il link va in **prima riga dopo il testo**: su YouTube il click è immediato,
su TikTok oggi non è cliccabile sotto i 1.000 follower.

---

## 7 — Dove e quando

| Piattaforma | Ora | Perché |
|---|---|---|
| **YouTube Shorts** | **19:00** | unico canale che oggi distribuisce (1.200-1.300 view con 0 iscritti) |
| **TikTok** | **20:00** | un'ora dopo, mai lo stesso minuto: si rubano pubblico |

Non ricaricare lo stesso file due volte su TikTok: lo tratta come duplicato.

---

## 8 — Checklist prima di pubblicare

- [ ] È una **registrazione del sito**, non card su fondo scuro
- [ ] Il numero **8.360** si legge chiaramente quando appare
- [ ] Si vede la **RAL compilarsi da sola** (il momento bello)
- [ ] **Nessun nome, account o dato personale** a schermo
- [ ] **Loop provato 4 volte di fila**: al 3° giro non si distingue la ripartenza
- [ ] Ultimo fotogramma **identico** al primo (barra di stato, ora, numeri)
- [ ] Il video **finisce sul ritorno**, non sul CTA
- [ ] **20 secondi**, non 13 e non 40
- [ ] Nessun fade e nessuna transizione dentro il ciclo
- [ ] Testi fuori dalla zona dei pulsanti TikTok
- [ ] Audio col colpo a 0:00, volume 30-40%
- [ ] Link in descrizione YouTube = **calcolo-tfr**
- [ ] Commento fissato incollato subito
- [ ] Prima ora: rispondi a **tutti** i commenti

---

## 9 — Cosa misurare a 48 ore

| Metrica | Soglia | Se è sotto |
|---|---|---|
| **% spettatori oltre i 3 s** | **> 50%** | la domanda iniziale non aggancia: cambiala, non il resto |
| **Tempo medio** | **> 12 s** su 20 | taglia la pausa centrale, non il sync |
| **Commenti con anni + stipendio** | **> 40** | la CTA non è abbastanza diretta |
| **Salvataggi** | **> like** | — |

**Il segnale del loop:** se il tempo medio è **vicino o sopra i 20 s**, il loop
funziona (la gente ricomincia). Se si ferma a 8-9 s, il problema è l'hook dei
primi due secondi, non il loop.

Il numero che conta più di tutti: **quanti arrivano sul calcolatore**.
Se il reel fa 5.000 view e 0 click, il problema è la CTA.
Se fa 5.000 view e 200 click, il reel ha funzionato.

---

## 10 — La versione B (solo se la A non gira)

Stesso scheletro, cambia **solo la domanda iniziale**:

```
Da quanto tempo sei nella stessa azienda?
```

È la domanda-identità del 209k, alla lettera. Si usa **al posto** della A,
mai la stessa sera: o una o l'altra.
