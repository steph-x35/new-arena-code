# 📈 Strategia Reel — Hoop City Life

> Playbook di LavoroFacile (`PIANO-CRESCITA.md`) applicato a Hoop City Life.
> Aggiornato: 2026-10-21 · versione gioco: **v2.47.7** (solo tiri liberi in due, 1v1 spento)

---

## 0 — Dove siamo

| Reel | Views | Like | Lettura |
|---|---|---|---|
| HCL «POV appeso al ferro» | 790 **con boost** | — | le views sponsorizzate sono pubblico freddo: **non misurano il video** |
| HCL «sito + tiri in 2» (40s) | **806** organiche | **1** | reach vera, ma **0,12% di like** contro un benchmark del 2-4% |
| LF «8 ore / 6 pagate» | 967 | 1 | 5,3s di tempo medio → la gente usciva **durante l'hook** |

**Diagnosi:** il video viene distribuito, ma non trattiene. Il problema non è il tema né la piattaforma: sono **i primi 2 secondi e la struttura**. Nel reel da 40s il sito compariva al secondo 1,5 — contenuto che non riguarda lo spettatore, prima di qualsiasi basket.

---

## 1 — Le tre leggi che si trasferiscono

| Legge | Prova su LavoroFacile | Errore da non ripetere |
|---|---|---|
| **Domanda sullo spettatore, mai affermazione** | «Lavori da 5 anni?» → **209k** | «Mito dimissioni» (affermazione) → **380** |
| **Un numero che lui vuole sapere** | il TFR che non sa di avere | «Stipendio netto» (numero già noto) → **4.000, 0 commenti** |
| **Il numero è nel primo fotogramma** | — | «8 ore/6 pagate» → **5,3s**: morto prima del contenuto |

Regola sintetica, già scritta nel piano LF: *il problema è l'hook, non la piattaforma — una riparazione dei primi 2 secondi vale per TikTok **e** per YouTube*.

## 1-bis — Le tre cose che NON si trasferiscono

1. **Il "numero nascosto" non esiste in un gioco.** In LF funziona perché i soldi sono *suoi*. A nessuno interessa un numero nel gioco se non ci sta giocando. Va sostituito con l'unica cosa con lo stesso potere: **il record da battere** — un numero che riguarda me, verificabile, dentro il gioco.
2. **"Ho creato un gioco da solo" è fuori nicchia.** È il fratello del "mito dimissioni": parla di te, non di lui. Un reel così ogni tanto, mai come serie.
3. **Il CTA "in bio" oggi non è cliccabile su TikTok** (serve 1.000 follower per il campo Sito). Il ponte attivo è **YouTube Shorts**: link cliccabili in descrizione, canale che parte anche da zero (già provato su LF: 1.300 view in 24h su canale nuovo).

---

## 2 — La formula Hoop City

> **Domanda-identità basket + record da battere + zero introduzione.**

Esempio: *«Giochi a basket? Quanti GREEN di fila fai?»*

Il numero è **vero e verificabile** perché viene dal gioco:
- `best_streak` — la serie di canestri di fila
- `hc_best` — il record della **SFIDA METÀ CAMPO**, salvato nel profilo (`Game.profile["hc_best"]`)
- SFIDA METÀ CAMPO: **60 secondi**, contano solo i GREEN **oltre 34 piedi** (da lì la finestra perfetta è una fessura)

Mai numeri inventati tipo «9 su 10». Stessa integrità del tool che calcola i TFR.

---

## 3 — KPI (i like sono l'ultima metrica)

| Metrica | Soglia | Dove si legge |
|---|---|---|
| Spettatori che superano i 3s | **> 50%** | Analytics → Retention |
| Tempo medio di visualizzazione | **> 7s** (su 18-22s) | Analytics → Panoramica |
| Salvataggi + condivisioni | **> 1% delle views** | Analytics → Interazioni |
| Commenti con un numero (il record) | **> 5** | commenti |
| Like | ultima, non guida | — |

Il reel da 40s è stato giudicato da 1 like. Il prossimo si giudica da **quanti scrivono un numero sotto**.

---

## 4 — REEL #2 — «Quanti GREEN di fila fai?»

**18-22 secondi. Si monta dal girato che hai già.** Nessuna ripresa nuova obbligatoria.

| Tempo | Cosa si vede | Testo a schermo |
|---|---|---|
| **0,0-1,5** | split screen, due telefoni, palla in aria — **nessuna intro** | **QUANTI GREEN DI FILA FAI?** |
| 1,5-4 | il tuo tiro → GREEN, il contatore sale | **io 11** |
| 4-7 | la palla di lui che vola sul tuo schermo | **e il suo la vedi volare** |
| 7-11 | cross-cut sullo stesso tiro: A → B | — |
| 11-15 | schiacciata / il momento migliore | — |
| 15-18 | tentativo da metà campo → sbagliato | **da metà campo: 0 su 14** |
| 18-21 | freeze sul GREEN | **Battimi. Il record è 11.** |
| ultimo frame | torna **identico** al primo (split screen) | **Android · gratis · in bio** |

**Il loop è obbligatorio:** ultimo frame = primo frame, così chi arriva in fondo ricomincia senza accorgersene.

**Cosa NON mettere:** il sito, il caricamento, qualsiasi frase che spieghi cosa stai per mostrare.

**Audio:** solo gioco nei primi 2 secondi (swish). Musica trend al 15-20% dopo. Tagli **solo** sul rilascio o sullo swish.

---

## 5 — REEL #3 — video-risposta al commento

Hai **1 commento**: quello è la prossima miniatura. Su LF le video-risposte fanno **8.300 view** contro 4.000 di un reel normale.

- 12-15s, apre con **il commento ingrandito** a schermo
- Rispondi **mostrando**, non spiegando: se chiede come si fa, fai vedere il tap
- Pubblica **come risposta al commento** (il commentatore riceve la notifica e spesso risponde di nuovo)
- Stesso giorno in cui arriva, non rimandare

---

## 6 — La serie (mai tre episodi identici)

LF è morta sulla serie «quanti anni» per **tre episodi uguali di fila** (1.389). Quindi: stesso scheletro, **soggetto diverso**.

| # | Domanda-identità | Numero da battere | Modalità in gioco |
|---|---|---|---|
| 1 | Quanti GREEN di fila fai? | `best_streak` | campetto libero |
| 2 | Da metà campo: quanti su 10? | `hc_best` (60s) | **SFIDA METÀ CAMPO** |
| 3 | Quanto ci metti a fare una schiacciata? | prova cronometrata | campetto libero |

Scheletro identico per tutti: domanda-identità → numero → escalation → CTA «scrivi il tuo numero» → loop.

---

## 7 — Testi pronti

### Reel #2
**Caption**
> Il mio record è 11 GREEN di fila. Quanti fai tu? 👇 Due telefoni, stesso WiFi, un campetto solo — senza internet. Gratis su Android, link in bio 🏀
> #basket #streetball #gamingitalia #basketitalia

**Commento fissato (il motore dei commenti)**
> Scrivi il tuo record di GREEN di fila qui sotto, li conto tutti 👇 E se hai un amico con Android: due telefoni sullo stesso WiFi e siete sullo stesso campo, senza server (link in bio)

### Reel #3 (SFIDA METÀ CAMPO)
**Caption**
> 60 secondi, solo GREEN da oltre metà campo. Il mio record è ___. Quanti fai tu in 60 secondi? 👇
> #basket #streetball #gamingitalia #sfidametacampo

**Commento fissato**
> Il gioco ti dà già il messaggio da incollare: dopo la sfida tocca «SFIDA GLI AMICI», copia il punteggio e sfidali su WhatsApp. Chi batte il mio record? 👇

> 💡 **Asset nativo da mostrare in video:** a fine SFIDA METÀ CAMPO c'è il bottone
> `SFIDA GLI AMICI (copia messaggio)` che mette negli appunti
> «🟢 N GREEN in 60 secondi… Riesci a battermi?». È un CTA dentro il gioco:
> mostrarlo vale più di qualsiasi «link in bio».

---

## 8 — Cadenza, piattaforme, boost

- **19:00-21:00**, **3-5 reel a settimana**, costanza > perfezione
- **Stesso video su YouTube Shorts la sera stessa**, versione **senza watermark TikTok** (YouTube declassa i video col watermark)
- **Prima ora: rispondere a TUTTI i commenti** — ogni risposta è un segnale per l'algoritmo
- **Boost: mai per testare.** I crediti si usano solo su un video che ha già superato le **5k organiche**. Le 790 view del POV erano pubblico freddo: non dicono niente sul video
- **Mai cancellare i video sotto-performanti**

---

## 9 — Checklist prima di pubblicare

- [ ] Il numero / la domanda è **nel primo fotogramma**, non al secondo 2
- [ ] Nessun fotogramma del **sito** (va in descrizione)
- [ ] Nessuna scritta che spieghi cosa stai per mostrare
- [ ] Durata **18-22s**, non 40
- [ ] Ultimo frame **identico** al primo (loop)
- [ ] Testi fuori dai **320px in basso** e **120px a destra** (interfaccia TikTok)
- [ ] **Nessun fotogramma con «SFIDA 1V1»** — in v2.47.7 non esiste
- [ ] Audio di gioco nei primi 2s, musica ≤ 20%
- [ ] Export **1080x1920**, salvata anche la versione senza watermark
- [ ] Caption + commento fissato già scritti e incollati
- [ ] Orario **19-21**

---

## 10 — Scheda misurazione a 48h (da compilare)

| Reel | Data | Views | Like | Commenti | Salvataggi | Tempo medio | % >3s | Verdetto |
|---|---|---|---|---|---|---|---|---|
| #2 Quanti GREEN | | | | | | | | |
| #3 Metà campo | | | | | | | | |

**Come leggere:**
- **% >3s bassa (< 40%)** → problema di hook: cambia la prima inquadratura, non il contenuto
- **% >3s alta ma tempo medio basso** → il centro del video annoia: taglia 4-5 secondi
- **tempo medio alto ma zero commenti** → manca la richiesta: la domanda finale non è abbastanza diretta
- **commenti alti ma poche view** → è il reel giusto, rifallo con un altro soggetto (serie)

---

## 11 — Cosa NON fare

- Niente contenuti fuori nicchia (l'algoritmo testa prima coi follower)
- Niente numeri non verificabili (il gioco è la fonte unica: `best_streak`, `hc_best`)
- Niente 40 secondi con 6 secondi di vuoto
- Niente boost per «vedere se funziona»
- Niente ripubblicazione dello stesso video identico (TikTok lo tratta come duplicato)
