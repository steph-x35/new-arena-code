#!/usr/bin/env python3
"""txt2pdf.py — converte i modelli LavoroFacile da .txt a PDF impaginati.

Solo libreria standard: nessuna dipendenza. Font Helvetica (base-14, WinAnsi).
Uso: python3 tools/txt2pdf.py sorgente.txt output.pdf "Titolo" "Sottotitolo"
"""
import sys, os, textwrap

W, H = 595.0, 842.0          # A4 in punti
ML, MR, MT, MB = 56.0, 56.0, 70.0, 66.0
CW = W - ML - MR             # larghezza utile

# larghezze Helvetica (frazione dell'em) per stimare il wrapping
_W = {}
for c in "iljtfr.,:;'|!()[]-":  _W[c] = 0.278
for c in "mw":                   _W[c] = 0.833
for c in "MW":                   _W[c] = 0.889
for c in "0123456789":           _W[c] = 0.556
for c in " ":                    _W[c] = 0.278
for c in "abcdefghknopqsuvxyz":   _W[c] = 0.556
for c in "ABCDEFGHIJKLMNOPQRSTUVXYZ": _W[c] = 0.667


def text_w(s, size, bold=False):
    k = 1.045 if bold else 1.0
    return sum(_W.get(ch, 0.556) for ch in s) * size * k


def wrap(s, size, bold=False, width=None):
    width = width or CW
    words, out, cur = s.split(" "), [], ""
    for w in words:
        cand = (cur + " " + w).strip()
        if text_w(cand, size, bold) <= width or not cur:
            cur = cand
        else:
            out.append(cur)
            cur = w
    if cur:
        out.append(cur)
    return out or [""]


# caratteri fuori Latin-1 che WinAnsiEncoding sa disegnare
_WIN = {"\u20ac": 0x80, "\u2013": 0x96, "\u2014": 0x97, "\u2018": 0x91,
        "\u2019": 0x92, "\u201c": 0x93, "\u201d": 0x94, "\u2026": 0x85,
        "\u2022": 0x95, "\u00b7": 0xB7}


def esc(s):
    s = "".join(chr(_WIN[c]) if c in _WIN else c for c in s)
    return s.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")


class Doc:
    def __init__(self):
        self.pages = []          # lista di liste di comandi di contenuto
        self.cur = []
        self.y = H - MT

    def new_page(self):
        if self.cur:
            self.pages.append(self.cur)
        self.cur = []
        self.y = H - MT

    def text(self, s, size=10.5, bold=False, dy=None, lead=None, indent=0, color=(0, 0, 0)):
        """scrive una riga (o più, wrappata) con controllo del salto pagina."""
        font = "F2" if bold else "F1"
        lead = lead or size * 1.42
        for line in wrap(s, size, bold, CW - indent):
            if self.y - lead < MB:
                self.new_page()
            self.y -= lead if dy is None else dy
            dy = None
            r, g, b = color
            self.cur.append(
                f"BT {r:.3f} {g:.3f} {b:.3f} rg /{font} {size} Tf "
                f"{ML+indent:.2f} {self.y:.2f} Td ({esc(line)}) Tj ET")

    def rule(self, pad=8, gray=0.78):
        if self.y - pad * 2 < MB:
            self.new_page()
        self.y -= pad
        self.cur.append(
            f"{gray} {gray} {gray} RG 0.7 w {ML:.2f} {self.y:.2f} m "
            f"{W-MR:.2f} {self.y:.2f} l S")
        self.y -= pad

    def space(self, pts=6):
        self.y -= pts

    def finish(self, footer=""):
        if self.cur:
            self.pages.append(self.cur)
        for i, page in enumerate(self.pages, 1):
            if footer:
                label = esc(f"{footer} \u00b7 pagina {i} di {len(self.pages)}")
                page.append(
                    f"BT 0.42 0.42 0.42 rg /F1 8 Tf "
                    f"{ML:.2f} 34 Td ({label}) Tj ET")

    def build(self, path):
        objs = []
        def add(s):
            objs.append(s)
            return len(objs)

        font1 = add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
                    "/Encoding /WinAnsiEncoding >>")
        font2 = add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold "
                    "/Encoding /WinAnsiEncoding >>")
        pages_id = add("PLACEHOLDER")
        kids = []
        for page in self.pages:
            stream = "\n".join(page).encode("latin-1", "replace")
            cid = add(b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream")
            pid = add("<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] "
                      "/Resources << /Font << /F1 %d 0 R /F2 %d 0 R >> >> "
                      "/Contents %d 0 R >>" % (pages_id, W, H, font1, font2, cid))
            kids.append(pid)
        objs[pages_id - 1] = ("<< /Type /Pages /Count %d /Kids [%s] >>"
                              % (len(kids), " ".join("%d 0 R" % k for k in kids)))
        cat = add("<< /Type /Catalog /Pages %d 0 R >>" % pages_id)

        out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        offs = []
        for i, o in enumerate(objs, 1):
            offs.append(len(out))
            body = o.encode("latin-1", "replace") if isinstance(o, str) else o
            out += b"%d 0 obj\n" % i + body + b"\nendobj\n"
        xref = len(out)
        out += b"xref\n0 %d\n" % (len(objs) + 1)
        out += b"0000000000 65535 f \n"
        for o in offs:
            out += b"%010d 00000 n \n" % o
        out += (b"trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n"
                % (len(objs) + 1, cat, xref))
        with open(path, "wb") as f:
            f.write(out)
        return len(out)


def cover(doc, title, subtitle, brand="LavoroFacile"):
    doc.y = H - 200
    doc.text(brand.upper(), 11, bold=True, color=(0.10, 0.35, 0.65), lead=26)
    doc.space(24)
    for line in wrap(title, 26, bold=True):
        doc.text(line, 26, bold=True, lead=34)
    doc.space(10)
    doc.rule(pad=10)
    doc.space(6)
    for line in wrap(subtitle, 12.5):
        doc.text(line, 12.5, color=(0.30, 0.30, 0.30), lead=19)
    doc.y = 150
    doc.text("Documento pronto da compilare — stampa, compila, invia.",
             9.5, color=(0.45, 0.45, 0.45))


def convert(src, dst, title, subtitle):
    raw = open(src, encoding="utf-8").read().splitlines()
    doc = Doc()
    cover(doc, title, subtitle)
    doc.new_page()

    for ln in raw:
        s = ln.rstrip()
        if not s.strip():
            doc.space(7)
            continue
        if set(s.strip()) <= set("=") and len(s.strip()) > 3:
            doc.rule()
            continue
        if set(s.strip()) <= set("-") and len(s.strip()) > 3:
            doc.rule(gray=0.86, pad=5)
            continue
        # sfondo blu dei titoli: riga tutta maiuscola e corta = intestazione
        core = s.strip()
        if core.isupper() and len(core) < 90 and any(c.isalpha() for c in core):
            doc.space(4)
            doc.text(core, 11.5, bold=True, color=(0.10, 0.20, 0.40))
            continue
        doc.text(s, 10.5)

    doc.finish("LavoroFacile \u00b7 lavorofacile")
    return doc.build(dst)


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    n = convert(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
    print("%s -> %s  (%d bytes, %d pagine)" % (sys.argv[1], sys.argv[2], n, 0))
