# COLLAUDO 1V1 — due telefoni (v2.49.3)

**APK:** https://github.com/steph-x35/new-arena-code/releases/download/v2.49.3/HoopCity-v2.49.3.apk
Stessa rete (WiFi di casa **o** hotspot di uno dei due). Porta 7777, scoperta UDP 47899.

Installazione: se Android dice «origini sconosciute», è normale — è un APK, non Play Store.

---

## I 8 passaggi (uno alla volta, si scrive solo dove si rompe)

| # | Cosa fai | Cosa DEVE succedere |
|---|---|---|
| 1 | Menu → SFIDA UN AMICO su A, l'altro si collega | tutti e due sul campetto, vi vedete muovere |
| 2 | aspetti 2 secondi | compare **SFIDA 1V1** in alto al centro, su **tutti e due** |
| 3 | A: SFIDA 1V1 → **A 11** | su B si apre la card «... ti sfida — a 11» con ACCETTA / RIFIUTA |
| 4 | B: ACCETTA | countdown 3-2-1 su tutti e due — i due sono **già fermi nella formazione**: attaccante a 22 piedi, difensore 120 px davanti a lui — poi **CHECK** solo su chi attacca; l'altro legge «aspetta il check...» e non ha altri tasti |
| 5 | chi attacca: CHECK (tondo, oro, con l'icona) | «VIA!», e solo lì i due si muovono |
| 6 | tiro sbagliato apposta | palla a terra: chi la prende attacca; se la prende in difesa deve **prima uscire dalla linea** |
| 7 | in difesa: **DIFENDI** (si aggancia da solo, si resta incollati), **RUBA** a contatto, **SALTA** sul tiro | 30% di rubata, popup «RUBATA!» / «PALLA PERSA!» |
| 8 | arriva a 11 | **HAI VINTO** / **HAI PERSO** coi punteggi; chi ha perso vede **RIVINCITA** (e riparte in attacco) |

Dopo **ogni** canestro si torna al punto 4: palla morta, i due rimessi nella
formazione, fermi, e si riparte col CHECK. Se invece corri o tiri durante il
check, quello è il bug da segnarmi.

Poi: **FINE PARTITA** → tutti e due tornano ai tiri liberi, senza uscire dal campo.

---

## Le quattro cose nuove (v2.49.0) — 2 minuti

| # | Cosa fai | Cosa DEVE succedere |
|---|---|---|
| 9 | carichi un tiro | sotto i piedi **12 trattini**: **verdi** se sei libero, gialli se hai una mano addosso, **rossi** (e pulsano) se sei coperto. Anche al campetto e nel 5v5 offline. |
| 10 | sfondi verso il ferro con la corsia libera (SALTA quando sei già sotto) | l'anello diventa un **cronometro**: una pallina corre **e il tratto verde** è la finestra. **TIRA** col pallino nel verde → «PERFECT!»; troppo presto/tardi → la schiacciata è normale e chi salta addosso te la può **stoppare**. |
| 11 | difendi e fai **3 difese buone di fila** (rubata, stoppata, o tiro sbagliato mentre gli stai addosso) | «LOCKDOWN!» + **anello azzurro** che gira: la rubata passa da 30% a 45% e il tuo contest pesa di più. Si spegne appena prendi canestro. |
| 12 | in attacco: **FINTA** (o passo indietro/spin) mentre l'altro sta **correndo** | lui inciampa e resta fermo ~mezzo secondo («CAVIGLIE!» da te, «TI HA SEDUTO» da lui). Se sta fermo davanti a te non succede quasi mai. |

Se l'anello non compare: Impostazioni → **grafica bassa** lo spegne apposta (per il telefono lento). Tienila alta per questa prova.

---

## Ombra, difesa, parquet (v2.49.2)

| # | Cosa fai | Cosa DEVE succedere |
|---|---|---|
| 13 | in difesa premi **SALTA** (o fai saltare l'altro: basta che uno salti) | l'ombra resta **a terra** sotto i piedi e si **rimpicciolisce** salendo, poi torna grande. Il salto **non** ti fa arretrare di un metro. |
| 14 | in difesa tieni **DIFENDI** e l'altro si muove | il difensore ha **le braccia aperte e le gambe piegate**, e mentre si sposta **muove le gambe** (passo strisciato): non scivola più fermo. |
| 15 | Impostazioni → **CAMPO** → Cambia colore | parquet **classico → nero → blu notte → rovere scuro**. Vale dalla partita successiva (non dal campetto: quello è asfalto). |

---

## Halloween (v2.49.3) — un minuto, anche da soli

| # | Cosa fai | Cosa DEVE succedere |
|---|---|---|
| 16 | apri la **città** di sera | sui marciapiedi, davanti alle vetrine, ci sono **zucche intagliate** di misure diverse; sui negozi alterni una **ragnatela** appesa alla tenda; **pipistrelli** che sbattono le ali sopra i tetti (non devono scattare: volano piano). |
| 17 | entra nel **campetto del parco** (SFIDA o allenamento) | zucche **ai piedi delle panchine** e ai lati del prato, ragnatela sullo schienale, 3 pipistrelli sopra il muro. Se giochi di sera i **fari sono arancio caldo** e le zucche hanno **la faccia accesa**. |
| 18 | Impostazioni → **HALLOWEEN** → tocca [ON] | diventa **[OFF]** e tornando in città/campetto le decorazioni **spariscono**; riaccendendolo **tornano**. (Da solo si accende dal 18/10 al 5/11.) |
| 19 | apri il gioco dopo l'aggiornamento | pannello **NOVITÀ** con 8 voci corte, Halloween in cima. |

Se i pipistrelli non si vedono: dimmi **dove** guardavi (città o campetto) e se eri in **verticale o orizzontale** — le quote sono calcolate sulla camera.

---

## Se si rompe, mi serve solo questo

1. **a che numero** si è fermato
2. **cosa vedevi tu** e **cosa vedeva l'altro** (anche solo «fermo lì»)
3. se il WiFi è saltato o è rimasto attaccato

Non serve registrare: due righe scritte bastano a trovare il punto.

---

## Il numero da scrivermi: il PING

In alto a destra c'è scritto **PING xx ms** (compare qualche secondo dopo il collegamento).

- **sotto 40** → la rete va bene: se scatta, il problema è nel gioco
- **40-80** → si sente, ma si gioca
- **oltre 80** → è il WiFi: due telefoni vicini al router, o hotspot, cambia tutto

Basta quel numero per capire dove intervenire.

---

## Cosa NON è un bug (già saputo)

- Il tasto SFIDA 1V1 appare solo quando l'altro è **sul campo** (circa 1 secondo).
- Se uno esce dalla stanza o dal WiFi, l'altro torna al menu con «Connessione persa».
- Il **vincitore** non ha il tasto RIVINCITA: la chiede chi ha perso (regola del 1v1).
