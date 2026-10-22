# 🎬 REEL «1.500 € lordi: quanto ti resta?» — sabato 25/10

> **Formato: registrazione dello schermo del calcolatore stipendio netto.**
> Lo stesso del reel da 209k. **20 secondi**, loop in fondo.
> Numeri verificati riga per riga sul codice di `stipendio-netto/app.js`.

---

## 0 — Perché questo reel e non «scatti di anzianità»

Il piano aveva v10 «SCATTI DI ANZIANITÀ» per sabato. Ha un problema che si vede
solo guardando il formato: **gli scatti non hanno un calcolatore sul sito.**

Senza calcolatore non c'è registrazione dello schermo, e quindi si torna alle
card su fondo scuro — cioè al formato che ha già fatto:

| Reel | Formato | Views |
|---|---|---|
| «Lavori da 5 anni nella stessa azienda?» | **registrazione del sito** | **209.000** |
| «Lavori da 10 anni…» | registrazione del sito | (serie) |
| «36 anni» | card scure | 1.389 |
| «8 ore / 6 pagate» | card scure | 967 |

Girare gli scatti sabato significa **sprecare lo slot migliore della settimana**
su un formato che ha già perso quattro volte.

**Quindi:** sabato va il calcolatore dello stipendio netto (l'unico altro tool
che fa un calcolo vero sul sito), e gli scatti tornano in coda quando esisterà
un modo di mostrarli a schermo. Il testo di «scatti» resta nel piano, non è
cancellato: è solo spostato.

---

## 1 — Il soggetto

La formula del 209k è **domanda-identità + numero nascosto**. Qui:

- domanda-identità: **1.500 € lordi** — è lo stipendio che si riconosce a occhio
- numero nascosto: **1.143 € netti** — non lo sa nessuno finché non fa il conto
- framing perdita: **356 € al mese** che spariscono
- sorpresa visiva: il numero **scende** mentre digiti

Non è un reel che spiega le tasse. È un reel in cui **una persona vede sparire
i propri soldi a schermo**, che è quello che ha fatto 209k.

---

## 2 — I numeri (verificati sul codice del tool)

Caso: mensile lordo **1.500 €**, mensilità **13** (default), regione lasciata
sul default, nessun familiare a carico.

| Passo | Valore a schermo |
|---|---|
| Mensile lordo digitato | **1.500 €** |
| Lordo annuo (sync automatico ×13) | **19.500 €** |
| INPS 9,19% | −1.792,05 € |
| IRPEF netta (dopo detrazioni) | −2.579,22 € |
| Addizionale regionale 1,23% | −217,81 € |
| Addizionale comunale 0,8% | −45,66 € |
| Netto annuo | **14.865,26 €** |
| **NETTO MENSILE** (il numero grande) | **1.143,48 €** |
| Prelievo totale | **23,77%** |

**Da dire nel video: 1.143 € netti · 356 € che non arrivano mai.**
`1.500 − 1.143,48 = 356,52 €` (il "buco" mensile, non annuo).

⚠️ **Regola per chi registra:** **non toccare il campo «regione»**. Il tool parte
con l'aliquota 1,23% già impostata nel campo; se si cambia regione dal menù
l'aliquota cambia (es. Abruzzo 1,73%) e il netto scende a 1.136,67 €. Lasciando
tutto com'è, il numero è **1.143,48** e chiunque lo riproduce ottiene lo stesso.

---

## 3 — Timeline: 20 secondi

| Tempo | Cosa si vede | Testo in sovrimpressione |
|---|---|---|
| **0 – 1,5 s** | **fermo** sul calcolatore vuoto | **1.500 € lordi.** (grande, bold) |
| **1,5 – 4 s** | digiti **1500** nel campo *Oppure mensile lordo* | — |
| **4 – 6 s** | ⚡ il **lordo annuo si compila da solo: 19.500** | **↑ 19.500 € all'anno** |
| **6 – 8 s** | niente da digitare: il risultato è già lì | **Quanto ti resta?** |
| **8 – 12 s** | scrolli al riquadro risultati | — |
| **12 – 16 s** | **zoom** sul netto mensile | **1.143 € netti** (giallo, grande) |
| **16 – 18 s** | resti sul numero | **356 € al mese. Spariti.** |
| **18 – 20 s** | **torni sul primo fotogramma** | **1.500 € lordi.** |
| **fine** | ↻ riparte da 0 — loop invisibile | — |

**Ordine di importanza:** il sync del lordo annuo (4-6 s) e i due numeri
(1.143 e 356). Il resto è contorno.

**Il video NON finisce sul CTA.** Finisce sul ritorno al primo fotogramma. Il CTA
sta nella **penultima** card (16-18 s), insieme al numero perduto.

---

## 4 — Montaggio

Stessa procedura del reel v9, sezione 4 (`REEL-22-LICENZIAMENTO.md`): **il loop
si fa per ultimo**, dopo aver messo i testi e prima dell'export.

Le uniche differenze:

| Passo | Qui |
|---|---|
| Progetto | 9:16, 1080×1920, 30 fps |
| Testo 1 | «1.500 € lordi.» — 0-1,5 s **e** 18-20 s |
| Testo 2 | «↑ 19.500 € all'anno» — 4-6 s |
| Testo 3 | «Quanto ti resta?» — 6-8 s |
| Testo 4 | «1.143 € netti» — 12-16 s, giallo `#FFC43D`, grande |
| Testo 5 | «356 € al mese. Spariti.» — 16-18 s |
| Audio | «dark suspense», colpo a 0:00, volume 30-40% |
| Loop | clip 0-1,5 s copiata in coda, tagliata a 1,5-2 s, sovrapposta al primo frame |

---

## 5 — Testi pronti

### TikTok — Caption

```
1.500 € lordi. Netti? 1.143 €.

356 € al mese che non arrivano mai sul conto.

Su 13 mensilità sono 4.635 € l'anno.

Quanto ti resta a te? Calcolalo gratis 👇
#stipendio #bustapaga #lavoro #netto #tasse
```

### TikTok — Commento fissato

```
Scrivete il vostro lordo mensile 👇 vi dico l'ordine di grandezza del netto.
(Il conto esatto cambia con regione e carichi di famiglia: il tool in bio li considera)
```

### YouTube — Titolo

```
1.500 € lordi: quanto ti resta davvero in tasca
```

### YouTube — Descrizione

```
1.143 € netti su 1.500 € lordi. Il 23,77% se ne va prima che i soldi arrivino sul conto.
Calcola il tuo in 30 secondi 👇

https://steph-x35.github.io/new-arena-code/stipendio-netto/

E se vuoi capire ogni riga della busta paga (ratei, addizionali, conguagli):
https://payhip.com/b/kbpxY

⚠️ Stima indicativa su 13 mensilità, regione a aliquota base, nessun familiare a carico.
Il netto reale dipende da CCNL, regione, comune e detrazioni.

#shorts #stipendio #bustapaga #lavoro
```

---

## 6 — Cosa vende (e perché questo e non il TFR)

Il reel del TFR porta gente sul calcolatore TFR, che vende il **Pacchetto
Dimissioni** a chi **sta per andarsene**: pubblico stretto, momento raro.

Questo porta gente sullo stipendio netto, che vende la **Busta Paga
Decodificata — 2,90 €** a chi **ha già la busta paga in mano**: pubblico larghissimo,
momento che si ripete ogni mese.

È il prodotto con il funnel più largo che hai, ed è quello che finora ha
convertito meno (2 click su Linktree). Non perché sia debole: perché **non l'hai
mai messo davanti a un video che parla di stipendio**.

---

## 7 — Metriche a 48 ore

| Metrica | Soglia | Se è sotto |
|---|---|---|
| Spettatori oltre i 3 s | **> 50%** | l'hook «1.500 € lordi» non aggancia |
| Tempo medio | **> 14 s** su 20 | il loop non lavora |
| Commenti con il proprio lordo | **> 30** | la CTA è troppo timida |
| Click Linktree su «Busta paga» | **> 5** in 48h | il video informa ma non vende |

Il numero che conta: **quanti toccano «Busta paga 2,90 €»**. Era a 2. Se arriva a
7-8 in 48 ore, questo formato vende, e si replica.

---

## 8 — Versione B (se la A non gira)

Stesso scheletro, la sorpresa diventa l'aumento:

> **Un aumento di 100 € lordi. Quanto ti arriva davvero?**
> → digiti 1500, poi 1600 → **+52,61 € al mese**

Verificato sullo stesso tool: il netto mensile passa da **1.143,48** a
**1.196,09**. Metà dell'aumento non arriva.

È più forte come "rabbia", più debole come ricerca: si usa **al posto** della A,
mai la stessa sera.
