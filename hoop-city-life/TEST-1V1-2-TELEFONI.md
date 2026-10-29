# COLLAUDO 1V1 — due telefoni (v2.48.0)

**APK:** https://github.com/steph-x35/new-arena-code/releases/download/v2.48.0/HoopCity-v2.48.0.apk
Stessa rete (WiFi di casa **o** hotspot di uno dei due). Porta 7777, scoperta UDP 47899.

Installazione: se Android dice «origini sconosciute», è normale — è un APK, non Play Store.

---

## I 8 passaggi (uno alla volta, si scrive solo dove si rompe)

| # | Cosa fai | Cosa DEVE succedere |
|---|---|---|
| 1 | Menu → SFIDA UN AMICO su A, l'altro si collega | tutti e due sul campetto, vi vedete muovere |
| 2 | aspetti 2 secondi | compare **SFIDA 1V1** in alto al centro, su **tutti e due** |
| 3 | A: SFIDA 1V1 → **A 11** | su B si apre la card «... ti sfida — a 11» con ACCETTA / RIFIUTA |
| 4 | B: ACCETTA | countdown 3-2-1 su tutti e due, poi **CHECK** solo su chi attacca; l'altro legge «aspetta il check...» |
| 5 | chi attacca: CHECK | «VIA!», palla in mano |
| 6 | tiro sbagliato apposta | palla a terra: chi la prende attacca; se la prende in difesa deve **prima uscire dalla linea** |
| 7 | in difesa: DIFENDI (si aggancia da solo) e RUBATA sotto i 90 px | 30% di riuscita, popup «RUBATA!» / «PALLA PERSA!» |
| 8 | arriva a 11 | **HAI VINTO** / **HAI PERSO** coi punteggi; chi ha perso vede **RIVINCITA** (e riparte in attacco) |

Poi: **FINE PARTITA** → tutti e due tornano ai tiri liberi, senza uscire dal campo.

---

## Se si rompe, mi serve solo questo

1. **a che numero** si è fermato
2. **cosa vedevi tu** e **cosa vedeva l'altro** (anche solo «fermo lì»)
3. se il WiFi è saltato o è rimasto attaccato

Non serve registrare: due righe scritte bastano a trovare il punto.

---

## Cosa NON è un bug (già saputo)

- Il tasto SFIDA 1V1 appare solo quando l'altro è **sul campo** (circa 1 secondo).
- Se uno esce dalla stanza o dal WiFi, l'altro torna al menu con «Connessione persa».
- Il **vincitore** non ha il tasto RIVINCITA: la chiede chi ha perso (regola del 1v1).
