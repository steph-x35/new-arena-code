#!/usr/bin/env python3
"""
Mette le 10 lettere di presentazione in un unico .docx modificabile.

Un PDF con i segnaposto [Nome e Cognome] non si compila: chi compra deve
poterci scrivere sopra. Il .docx si modifica in Word o Google Docs e si
salva in PDF quando e' pronto.

Uso:
    python3 tools/lettere2docx.py sorgenti/ output.docx
"""

import os
import sys

from cv2docx import para, run, write_docx

LETTER_MARGIN = 1418  # 2,5 cm, come una lettera vera
BODY_FONT = "Georgia"
INK = "111111"
RULE = ('<w:bottom w:val="single" w:sz="6" w:space="6" '
        'w:color="D1D5DB"/>')


def leggi(path):
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    blocchi = [b.strip() for b in raw.replace("\r\n", "\n").split("\n\n")]
    return [b for b in blocchi if b]


def titolo_da_filename(name):
    base = os.path.splitext(os.path.basename(name))[0]
    if "-" in base and base.split("-", 1)[0].isdigit():
        base = base.split("-", 1)[1]
    return base.replace("-", " ").replace("_", " ")


def lettera(blocchi, numero, titolo, nuova_pagina=True):
    head = para([run("LAVOROFACILE", size=16, color="6B7280",
                     font=BODY_FONT, char_spacing=40)],
                after=160, keep=True, border=RULE,
                page_break=nuova_pagina)
    head += para([run("Lettera %d" % numero, bold=True, size=17,
                      color="9CA3AF", font=BODY_FONT, char_spacing=24)],
                 after=20, keep=True)
    head += para([run(titolo, bold=True, size=22, color="1F2937",
                      font=BODY_FONT)], after=280, keep=True)

    for blocco in blocchi:
        if blocco.startswith("Oggetto:"):
            head += para([run(blocco, bold=True, size=22, color=INK,
                              font=BODY_FONT)], after=280, keep=True)
            continue
        righe = blocco.split("\n")
        # blocco firma: tutte le righe sono segnaposto tra parentesi quadre
        if len(righe) >= 2 and all(r.strip().startswith("[") for r in righe):
            for r in righe:
                head += para([run(r.strip(), size=21, color=INK,
                                  font=BODY_FONT)], after=20)
            continue
        if blocco.startswith("Alla cortese attenzione"):
            head += para([run(blocco, size=21, color="374151",
                              font=BODY_FONT)], after=300)
            continue
        head += para([run(blocco, size=21, color=INK, font=BODY_FONT)],
                     after=200, line=276)
    return head


def main():
    src, dst = sys.argv[1], sys.argv[2]
    files = sorted(
        [f for f in os.listdir(src) if f.endswith(".txt")],
        key=lambda f: int(f.split("-", 1)[0]))
    body = ""
    for i, name in enumerate(files, 1):
        blocchi = leggi(os.path.join(src, name))
        body += lettera(blocchi, i, titolo_da_filename(name),
                        nuova_pagina=(i > 1))
    m = LETTER_MARGIN
    write_docx(dst, body, "10 lettere di presentazione - LavoroFacile",
               (m, m, m, m))
    print("%s  %d lettere  %d B" % (dst, len(files), os.path.getsize(dst)))


if __name__ == "__main__":
    main()
