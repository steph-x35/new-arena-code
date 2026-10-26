#!/usr/bin/env python3
"""txt2pdf.py — converte i materiali LavoroFacile in PDF impaginati.

Solo libreria standard: nessuna dipendenza. Font Helvetica (base-14, WinAnsi).
Supporta .txt e .md (ripulisce i marcatori markdown) e piu' sorgenti in un
unico PDF, separate da un salto pagina.

Uso:
  python3 tools/txt2pdf.py OUT.pdf "Titolo" "Sottotitolo" TAGLINE src1 [src2 ...]

Esempio (10 lettere in un solo PDF):
  python3 tools/txt2pdf.py lettere.pdf "10 Lettere" "..." "..." a.txt b.txt
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


def text_w(s, size, bold=False, mono=False):
    if mono:
        return len(s) * 0.6 * size          # Courier: tutti i glifi 0.6 em
    k = 1.045 if bold else 1.0
    return sum(_W.get(ch, 0.556) for ch in s) * size * k


def wrap(s, size, bold=False, width=None, mono=False):
    width = width or CW
    if mono:                                # a capo per numero di caratteri
        n = max(1, int(width / (0.6 * size)))
        return [s[i:i + n] for i in range(0, len(s), n)] or [""]
    words, out, cur = s.split(" "), [], ""
    for w in words:
        cand = (cur + " " + w).strip()
        if text_w(cand, size, bold, mono) <= width or not cur:
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

# caratteri "disegno" -> ASCII equivalente (le guide sono impaginate a mano)
_BOX = {
    "\u2550": "=", "\u2500": "-", "\u2551": "|", "\u2502": "|",
    "\u2554": "+", "\u2557": "+", "\u255A": "+", "\u255D": "+",
    "\u250C": "+", "\u2510": "+", "\u2514": "+", "\u2518": "+",
    "\u2560": "+", "\u2563": "+", "\u2566": "+", "\u2569": "+",
    "\u256C": "+", "\u251C": "+", "\u2524": "+", "\u252C": "+",
    "\u2534": "+", "\u253C": "+",
    "\u25BA": ">", "\u2192": "->", "\u2190": "<-",
    "\u2265": ">=", "\u2264": "<=", "\u00D7": "x", "\u00F7": "/",
    "\u2212": "-", "\u2610": "[ ]", "\u2717": "x", "\u2713": "v",
    "\u00A9": "(c)", "\u26A0": "!",
}
# caratteri che scriviamo per esteso
_SPELL = {"\u20ac": "EUR", "\u2018": "'", "\u2019": "'",
          "\u201C": '"', "\u201D": '"', "\u2026": "..."}

# solo i caratteri di cornice: le frecce sono testo normale
BOXCHARS = ("\u2500\u2502\u250C\u2510\u2514\u2518\u251C\u2524\u252C\u2534\u253C"
            "\u2550\u2551\u2554\u2557\u255A\u255D\u2560\u2563\u2566\u2569\u256C"
            "\u25BA")


def sanitize(s):
    """porta la stringa dentro Latin-1: mappa i simboli, elimina le emoji."""
    out = []
    for c in s:
        if c in _BOX:
            out.append(_BOX[c])
        elif c in _WIN:
            out.append(chr(_WIN[c]))
        elif c in _SPELL:
            out.append(_SPELL[c])
        elif ord(c) < 256:
            out.append(c)
        else:
            out.append("\uFFFD")   # verra' scartato sotto
    # le emoji sostituite dal segnaposto: via, insieme allo spazio doppio
    return "".join(ch for ch in "".join(out) if ch != "\uFFFD")


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

    def text(self, s, size=10.5, bold=False, dy=None, lead=None, indent=0,
             color=(0, 0, 0), mono=False):
        """scrive una riga (o più, wrappata) con controllo del salto pagina."""
        s = sanitize(s)
        font = "F3" if mono else ("F2" if bold else "F1")
        lead = lead or size * 1.42
        for line in wrap(s, size, bold, CW - indent, mono=mono):
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
                label = esc(sanitize(f"{footer} \u00b7 pagina {i} di {len(self.pages)}"))
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
        font3 = add("<< /Type /Font /Subtype /Type1 /BaseFont /Courier "
                    "/Encoding /WinAnsiEncoding >>")
        pages_id = add("PLACEHOLDER")
        kids = []
        for page in self.pages:
            stream = "\n".join(page).encode("latin-1", "replace")
            cid = add(b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream")
            pid = add("<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] "
                      "/Resources << /Font << /F1 %d 0 R /F2 %d 0 R /F3 %d 0 R >> >> "
                      "/Contents %d 0 R >>" % (pages_id, W, H, font1, font2, font3, cid))
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


def cover(doc, title, subtitle, brand="LavoroFacile",
          tagline="Documento pronto da compilare \u2014 stampa, compila, invia."):
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
    doc.text(tagline, 9.5, color=(0.45, 0.45, 0.45))


def clean_md(s):
    """toglie i marcatori markdown che non sappiamo disegnare."""
    s = s.replace("**", "").replace("__", "")
    s = s.replace("`", "")
    if s.startswith("> "):
        s = s[2:]
    elif s.startswith(">\t"):
        s = s[2:]
    # corsivo: *testo* -> testo (solo se le stelle sono appaiate)
    if s.count("*") >= 2 and s.count("*") % 2 == 0:
        s = s.replace("*", "")
    return s


def emit(doc, path):
    """scrive il contenuto di un file dentro il documento."""
    raw = open(path, encoding="utf-8").read().splitlines()
    for ln in raw:
        s = ln.rstrip()
        if not s.strip():
            doc.space(7)
            continue
        core = s.strip()

        # riga impaginata a mano (cornici, tabelle): la rendiamo monospaziata
        if any(c in BOXCHARS for c in core):
            doc.text(clean_md(core).replace("\t", "    "), 9, mono=True)
            continue

        # separatori
        if set(core) <= set("=") and len(core) > 3:
            doc.rule()
            continue
        if (set(core) <= set("-") and len(core) > 3) or core == "---":
            doc.rule(gray=0.86, pad=5)
            continue

        # titoli markdown
        if core.startswith("### "):
            doc.space(6)
            doc.text(clean_md(core[4:]), 11, bold=True, color=(0.25, 0.25, 0.25))
            continue
        if core.startswith("## "):
            doc.space(10)
            doc.text(clean_md(core[3:]), 12.5, bold=True, color=(0.10, 0.20, 0.40))
            continue
        if core.startswith("# "):
            doc.space(6)
            doc.text(clean_md(core[2:]), 15, bold=True, color=(0.10, 0.20, 0.40))
            continue

        # citazioni markdown -> rientrate
        if core.startswith("> "):
            doc.text(clean_md(core), 10.5, indent=18, color=(0.28, 0.28, 0.28))
            continue

        core = clean_md(core)

        # intestazione: riga tutta maiuscola e corta
        if core.isupper() and len(core) < 90 and any(c.isalpha() for c in core):
            doc.space(4)
            doc.text(core, 11.5, bold=True, color=(0.10, 0.20, 0.40))
            continue

        doc.text(core, 10.5)


def convert(dst, title, subtitle, sources, tagline=None):
    doc = Doc()
    cover(doc, title, subtitle,
          tagline=tagline or "Documento pronto da compilare \u2014 stampa, compila, invia.")
    for i, src in enumerate(sources):
        doc.new_page()
        if i > 0:
            # intestazione del singolo documento quando sono piu' d'uno
            name = os.path.basename(src).rsplit(".", 1)[0].replace("-", " ")
            doc.text(name, 11, bold=True, color=(0.10, 0.20, 0.40))
            doc.rule(gray=0.86, pad=6)
        emit(doc, src)
    doc.finish("LavoroFacile \u00b7 lavorofacile")
    return doc.build(dst)


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    out, title, subtitle, tagline = sys.argv[1:5]
    srcs = sys.argv[5:]
    if not srcs:
        print(__doc__)
        sys.exit(1)
    n = convert(out, title, subtitle, srcs, tagline=tagline)
    print("%s  <-  %d file  (%d bytes)" % (out, len(srcs), n))
