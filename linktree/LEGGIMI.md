# Icone dei link Linktree

Le prime quattro icone del profilo sono quadrati colorati con un simbolo
bianco, uno per link. I colori sono quelli già in uso:

| Link | Colore | Simbolo |
|---|---|---|
| Calcola il TFR (gratis) | verde `#2DA350` | euro |
| Dimissioni e TFR | rosso `#D62B27` | porta con freccia |
| Ferie, ROL e permessi | arancione `#F08A1C` | calendario |
| La Busta Paga Decodificata | blu `#3B63E6` | documento |
| Kit Carriera | viola `#803AE8` | stella |

L'arancione non era ancora usato, quindi il link nuovo si distingue dagli
altri quattro senza cambiare nessuno di quelli che funzionano.

## File

- `icona-ferie-rol.png` — 512×512, da caricare su Linktree
- `preview-64.png` e `preview-32.png` — come si vede in miniatura, per
  controllare a occhio prima di salvare

## Rigenerarla

```bash
convert -size 512x512 xc:none \
  -fill "#F08A1C" -draw "circle 256,256 256,8" \
  -fill white \
  -draw "roundrectangle 168,120 198,180 14,14" \
  -draw "roundrectangle 314,120 344,180 14,14" \
  -draw "roundrectangle 112,150 400,392 32,32" \
  -fill "#F08A1C" \
  -draw "rectangle 112,236 400,248" \
  -draw "roundrectangle 176,286 214,324 8,8" \
  -draw "roundrectangle 243,286 281,324 8,8" \
  -draw "roundrectangle 310,286 348,324 8,8" \
  icona-ferie-rol.png
