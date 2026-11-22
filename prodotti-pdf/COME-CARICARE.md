# Cosa caricare su Payhip

I PDF si caricano **uno per uno**, non come zip: la pagina mostra così
«PDF (29KB)», «PDF (8KB)»… e il prodotto sembra quello che è. Con un solo zip
la pagina scrive «You will get a ZIP (17KB)», che è quello che avevamo prima e
che non ha venduto niente.

## La Busta Paga Decodificata — 2,90 €

Dalla cartella `busta-paga/`, quattro file:

1. `1-Guida-Completa.pdf`
2. `2-Cheat-Sheet-10-Minuti.pdf`
3. `3-Ti-Pagano-Meno-Del-CCNL.pdf`
4. `4-Checklist-Cambio-Contratto.pdf`

Togli il vecchio zip dalla pagina.

## Kit Carriera — 4,90 €

Nove file:

1. `1-Come-Usare-il-Kit.pdf`
2. `2-Guida-20-Domande-Colloquio.pdf`
3. `3-Dieci-Lettere-di-Presentazione.pdf`
4. `4-Dieci-Lettere-Modificabili.docx`
5. `cv-docx/1-Modello-Classico-ATS.docx`
6. `cv-docx/2-Modello-Moderno-Due-Colonne.docx`
7. `cv-docx/3-Modello-Minimal-Elegante.docx`
8. `cv-docx/4-Modello-Professionale-Senior.docx`
9. `cv-docx/5-Modello-Junior-Formativo.docx`

Togli il vecchio zip dalla pagina.

## Ferie, ROL e permessi — 3,90 €

Dalla cartella `ferie-permessi/`, quattro file:

1. `1-Guida-Completa-Ferie-ROL-Permessi.pdf`
2. `2-Cheat-Sheet-Ferie-ROL-10-Minuti.pdf`
3. `3-Ferie-Non-Godute-Quanto-Valgono.pdf`
4. `4-Tre-Lettere-Pronte-Ferie-ROL.pdf`

Le fonti stanno in `ferie-rol-permessi/` (stessa cartella della Busta Paga:
`.txt` impaginati, si rigenerano con `txt2pdf.py`).

## Perché i CV sono .docx e non PDF

Un PDF non si compila: chi compra deve scrivere il proprio nome sopra
`[Nome e Cognome]`. I .docx si aprono in Word, Google Docs e LibreOffice e si
salvano in PDF con un clic. In più i sistemi di selezione leggono molto meglio
un .docx di un CV impaginato come un poster.

Gli zip nella cartella (`Busta-Paga-4-PDF.zip`, `Kit-Carriera-3-PDF.zip`) sono
solo copie di comodo per scaricare tutto in un colpo: **non vanno caricati**.

## Come si rigenerano

```bash
python3 tools/txt2pdf.py OUT.pdf "Titolo" "Sottotitolo" "Tagline" sorgente1 [sorgente2 ...]
python3 tools/cv2docx.py prodotti-pdf/kit-carriera/cv-docx
PYTHONPATH=tools python3 tools/lettere2docx.py kit-colloquio/lettere-presentazione \
    prodotti-pdf/kit-carriera/4-Dieci-Lettere-Modificabili.docx
```

`txt2pdf.py` legge `.txt` e `.md`, rende in Courier le righe con le cornici
così le tabelle restano allineate, e scarta le emoji.
