# Come caricare i PDF su Payhip

Generato con `tools/txt2pdf.py`. Nessuna dipendenza esterna: i PDF sono scritti
a mano (Helvetica + Courier, base-14) partendo dai `.txt` del repository.

## File da scaricare (dal telefono, un tap)

| Prodotto | Bundle | Cosa contiene |
|---|---|---|
| **La Busta Paga Decodificata** | `Busta-Paga-4-PDF.zip` | 4 PDF |
| **Kit Carriera** | `Kit-Carriera-3-PDF.zip` | 3 PDF |
| **Kit Carriera** — modelli CV | `kit-carriera/4-Modelli-CV-modificabili.zip` | 5 HTML modificabili |

## Cosa caricare su Payhip

### La Busta Paga Decodificata — 2,90 €

Carica i **4 PDF singoli** dalla cartella `busta-paga/`:

1. `1-Guida-Completa.pdf`
2. `2-Cheat-Sheet-10-Minuti.pdf`
3. `3-Ti-Pagano-Meno-Del-CCNL.pdf`
4. `4-Checklist-Cambio-Contratto.pdf`

Rimuovi il vecchio `Busta-Paga-Decodificata-LavoroFacile.zip`.

### Kit Carriera — 4,90 €

Carica **3 PDF + 1 zip**:

1. `1-Come-Usare-il-Kit.pdf`
2. `2-Guida-20-Domande-Colloquio.pdf`
3. `3-Dieci-Lettere-di-Presentazione.pdf` (le 10 lettere in un solo PDF)
4. `4-Modelli-CV-modificabili.zip` — **resta uno zip perché sono HTML da
   modificare**, e un PDF non si compila. Nella descrizione va detto.

Rimuovi il vecchio `Kit-Colloquio-LavoroFacile.zip`.

## Perché i CV restano HTML

Sono modelli da personalizzare: in PDF sarebbero solo da guardare. In HTML si
aprono nel browser, si modificano con un editor di testo o si stampano in PDF.
Nella descrizione del prodotto va scritto chiaro, altrimenti chi compra si
aspetta 5 PDF e trova 5 file HTML.

## Come si rigenerano

```bash
python3 tools/txt2pdf.py OUT.pdf "Titolo" "Sottotitolo" "Tagline" sorgente1 [sorgente2 ...]
```

- supporta `.txt` e `.md` (ripulisce i marcatori markdown)
- le righe con cornici `┌─┐│` vengono rese in Courier, così le tabelle restano allineate
- le emoji vengono scartate: in un documento legale non servono
- piu' sorgenti = un solo PDF, separate da un salto pagina
