# Copertine dei prodotti

Immagini da usare sulla pagina Payhip e su Linktree.

| File | Dove | Dimensione |
|---|---|---|
| `ferie-permessi-cover.jpg` | immagine principale del prodotto Payhip | 1200×1200 |
| `ferie-linktree.jpg` | icona del link su Linktree | 500×500 |
| `ferie-permessi-cover.png` | sorgente in alta risoluzione | 1024×1024 |

## Perché due versioni

Payhip mostra l'immagine grande: serve la copertina intera, con il tavolo e
i fogli, perché dà l'idea del prodotto finito.

Linktree la mostra a 64 pixel di lato. A quella misura il tavolo diventa
rumore e il titolo non si legge: il ritaglio quadrato tiene solo il libro e
le due righe di testo.

## Rigenerare il ritaglio

```bash
convert ferie-permessi-cover.png -crop 560x560+215+120 +repage \
        -resize 500x500 -strip -quality 90 ferie-linktree.jpg
```
