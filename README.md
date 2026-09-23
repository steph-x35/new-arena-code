# 🧾 FatturaFacile

**Generatore di fatture e preventivi PDF — gratis, online, senza account.**

Compili i campi, vedi l'anteprima A4 che si aggiorna in tempo reale e scarichi il PDF con un clic (stampa del browser).

## Funzionalità

- Fatture e preventivi (toggle)
- IVA italiana: 22%, 10%, 5%, Esente (0%) per singola voce + Reverse charge
- Totali automatici con dettaglio IVA per aliquota
- Anteprima A4 in tempo reale, export PDF con un clic
- Bozza salvata automaticamente nel browser (localStorage)
- Libreria di documenti salvati (apri/elimina)
- 100% client-side: nessun backend, nessun dato inviato a server
- SEO base: meta, FAQ, JSON-LD

## Avvio in locale

```bash
python3 -m http.server 8080
# oppure
npx serve .
```

Poi apri http://localhost:8080

## Struttura

- `index.html` — pagina (form + preview + FAQ)
- `styles.css` — stile app + foglio A4 + stili di stampa
- `app.js` — stato, calcoli IVA, render, persistenza localStorage

## Roadmap (hub di strumenti)

- [ ] Calcolatore stipendio netto (con addizionali regionali)
- [ ] Generatore CV
- [ ] Versione Pro (fatture illimitate, template, promemoria pagamenti) via Stripe
- [ ] Google Search Console + sitemap
