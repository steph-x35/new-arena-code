# 💣 REEL «TI LICENZI: QUANTO TI SPETTA?» — produzione completa

> **Formato: registrazione dello schermo del sito. Non card su fondo scuro.**
> È il formato del reel da **209k**. 22-28 secondi.
> Caso reale, tutto anonimo. Numeri verificati riga per riga sul calcolatore.

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
| **TFR NETTO** (il numero grande a schermo) | **8.360 €** |

**Da dire nel video: 10.857 lordi · 8.360 netti.**
**Da non dire: 12.500 (rivalutazioni) · 11.689 (14 mensilità).**

Verifica indipendente: `10.857 × +13% di rivalutazioni ISTAT su 7 anni e 8 mesi
≈ 12.270` — ecco da dove nasceva il 12.500 del piano.

E la voce ferie, verificata: `9,0956 × 8 ore = **72,76 € al giorno**` (esatta).

---

## 3 — Il copione: cosa registri e cosa scrivi

### Preparazione (3 minuti)

1. Telefono in **verticale**, **Non disturbare** attivo
2. Connetti il caricabatterie (la registrazione prosciuga)
3. Apri **una sola scheda**: `https://steph-x35.github.io/new-arena-code/calcolo-tfr/`
4. Zoom del browser al **110%** (i numeri devono essere grandi)
5. Cancella la cronologia recente dalla barra: **nessun nome, nessun account a schermo**
6. Avvia la registrazione schermo

### Le mosse

| Tempo | Cosa fai | Testo in sovrimpressione |
|---|---|---|
| **0 – 2 s** | **fermo** sul calcolatore vuoto | **Ti licenzi dopo 7 anni?** (grande, bold, in alto) |
| **2 – 6 s** | tocchi il campo **«Retribuzione Mensile Lorda»** e digiti **1577** | — |
| **6 – 8 s** | ⚡ la **RAL si compila da sola: 20.501** — è il momento bello, lascia vedere | — |
| **8 – 12 s** | digiti **7** negli anni e **8** nei mesi | — |
| **12 – 14 s** | piccola pausa: i risultati si aggiornano | — |
| **14 – 20 s** | scrolli fino al riquadro risultati e **ti fermi sul numero grande** | **8.360 € NETTI** |
| **20 – 24 s** | zoom lento sul numero (pinch, non taglio) | sotto, più piccolo: **10.857 € lordi** |
| **24 – 28 s** | torni fermo in cima | **E tu? Scrivi anni + stipendio 👇** |
| **ultimo frame** | — | **Calcolatore gratis in bio 🔗** |

**Durata finale: 28 secondi.** Se sfori, taglia la pausa del 12-14 s, non il
momento del sync (6-8 s): quello è il cuore.

---

## 4 — Montaggio (CapCut, 10 minuti)

| Passo | Cosa fare |
|---|---|
| 1 | Progetto **9:16**, 1080×1920, 30 fps |
| 2 | Importa la registrazione: **taglia testa e coda** (dove tocchi per fermare) |
| 3 | Metti in **velocità 1,5×** la digitazione se è lenta — il sync deve arrivare entro l'8° secondo |
| 4 | **Testo 1** (0-2s): «Ti licenzi dopo 7 anni?» — bianco, bold, in alto, fuori dalla zona bassa |
| 5 | **Testo 2** (14-24s): «8.360 € netti» — giallo `#FFC43D`, grande, centrato sul numero |
| 6 | **Testo 3** (20-24s): «10.857 € lordi» — bianco, più piccolo, sotto |
| 7 | **Testo 4** (24-28s): «E tu? Scrivi anni + stipendio 👇» |
| 8 | **Testo 5** (ultimi 3s): «Calcolatore gratis in bio 🔗» |
| 9 | Audio: «dark suspense» o «tense piano», **colpo a 0:00**, volume **30-40%** |
| 10 | **Ultimo fotogramma = primo fotogramma** (loop): chi arriva in fondo ricomincia |
| 11 | Export **1080×1920, 30 fps**, un file unico per TikTok e YouTube |

**Zona sicura:** testi fuori dai **320 px in basso** e **120 px a destra**
(altrimenti l'interfaccia di TikTok li copre).

---

## 5 — Testi pronti da incollare

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

## 6 — Dove e quando

| Piattaforma | Ora | Perché |
|---|---|---|
| **YouTube Shorts** | **19:00** | unico canale che oggi distribuisce (1.200-1.300 view con 0 iscritti) |
| **TikTok** | **20:00** | un'ora dopo, mai lo stesso minuto: si rubano pubblico |

Non ricaricare lo stesso file due volte su TikTok: lo tratta come duplicato.

---

## 7 — Checklist prima di pubblicare

- [ ] È una **registrazione del sito**, non card su fondo scuro
- [ ] Il numero **8.360** si legge chiaramente quando appare
- [ ] Si vede la **RAL compilarsi da sola** (il momento bello)
- [ ] **Nessun nome, account o dato personale** a schermo
- [ ] Ultimo fotogramma = primo (loop)
- [ ] **28 secondi**, non 13 e non 40
- [ ] Testi fuori dalla zona dei pulsanti TikTok
- [ ] Audio col colpo a 0:00, volume 30-40%
- [ ] Link in descrizione YouTube = **calcolo-tfr**
- [ ] Commento fissato incollato subito
- [ ] Prima ora: rispondi a **tutti** i commenti

---

## 8 — Cosa misurare a 48 ore

| Metrica | Soglia | Se è sotto |
|---|---|---|
| **% spettatori oltre i 3 s** | **> 50%** | la domanda iniziale non aggancia: cambiala, non il resto |
| **Tempo medio** | **> 10 s** su 28 | taglia la pausa centrale, non il sync |
| **Commenti con anni + stipendio** | **> 40** | la CTA non è abbastanza diretta |
| **Salvataggi** | **> like** | — |

Il numero che conta più di tutti: **quanti arrivano sul calcolatore**.
Se il reel fa 5.000 view e 0 click, il problema è la CTA.
Se fa 5.000 view e 200 click, il reel ha funzionato.

---

## 9 — La versione B (solo se la A non gira)

Stesso scheletro, cambia **solo la domanda iniziale**:

```
Da quanto tempo sei nella stessa azienda?
```

È la domanda-identità del 209k, alla lettera. Si usa **al posto** della A,
mai la stessa sera: o una o l'altra.
