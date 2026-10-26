#!/usr/bin/env python3
"""
Genera i 5 modelli di CV in formato .docx (Word / Google Docs / LibreOffice).

Perche' esiste questo script: i modelli erano nati come HTML. In HTML si
aprono nel browser, ma chi cerca lavoro deve poter scrivere sopra i propri
dati e allegare il CV a una candidatura. Un .html non si apre in Word e non
si allega a un annuncio. Il .docx invece si modifica, si salva in PDF con
"Salva con nome" e viene letto dai sistemi di selezione.

Solo stdlib: un .docx e' uno zip con quattro file XML.

Uso:
    python3 tools/cv2docx.py cartella_output/
"""

import os
import sys
import zipfile

# ---------------------------------------------------------------- OOXML

CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>"""

RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>"""

DOC_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>"""

STYLES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults>
<w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
<w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr></w:rPrDefault>
<w:pPrDefault><w:pPr><w:spacing w:after="100" w:line="252" w:lineRule="auto"/></w:pPr></w:pPrDefault>
</w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal">
<w:name w:val="Normal"/><w:qFormat/>
<w:pPr><w:spacing w:after="100" w:line="252" w:lineRule="auto"/></w:pPr>
<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>
</w:style>
</w:styles>"""

# Dimensioni A4 in twips
PAGE_W = 11906
PAGE_H = 16838
MARGIN = 1134  # 2 cm
TEXT_W = PAGE_W - 2 * MARGIN  # 9638


def esc(text):
    return (text.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;"))


def run(text, bold=False, italic=False, size=None, color=None,
        caps=False, small_caps=False, font=None, char_spacing=None,
        underline=False):
    """Un frammento di testo con la sua formattazione."""
    rpr = ""
    if font:
        rpr += ('<w:rFonts w:ascii="%s" w:hAnsi="%s" w:cs="%s"/>'
                % (font, font, font))
    if bold:
        rpr += "<w:b/><w:bCs/>"
    if italic:
        rpr += "<w:i/><w:iCs/>"
    if caps:
        rpr += "<w:caps/>"
    if small_caps:
        rpr += "<w:smallCaps/>"
    if color:
        rpr += '<w:color w:val="%s"/>' % color
    if char_spacing is not None:
        rpr += '<w:spacing w:val="%d"/>' % char_spacing
    if size:
        rpr += '<w:sz w:val="%d"/><w:szCs w:val="%d"/>' % (size, size)
    if underline:
        rpr += '<w:u w:val="single"/>'
    rpr = "<w:rPr>%s</w:rPr>" % rpr if rpr else ""
    if text == "":
        return "<w:r>%s</w:r>" % rpr
    # una tabulazione dentro <w:t> resta un carattere qualsiasi: Word la
    # ignora e le date non si allineano a destra. serve l'elemento <w:tab/>.
    pezzi = []
    for i, parte in enumerate(text.split("\t")):
        if i:
            pezzi.append("<w:tab/>")
        if parte:
            pezzi.append('<w:t xml:space="preserve">%s</w:t>' % esc(parte))
    return "<w:r>%s%s</w:r>" % (rpr, "".join(pezzi))


def para(runs, before=0, after=100, line=252, align=None, border=None,
         shading=None, left=0, hanging=0, right=0, keep=False, tabs=None,
         page_break=False):
    """Un paragrafo. `runs` e' una stringa o una lista di stringhe."""
    if isinstance(runs, str):
        runs = [runs]
    ppr = ""
    if keep:
        ppr += "<w:keepNext/><w:keepLines/>"
    if page_break:
        ppr += "<w:pageBreakBefore/>"
    if border:
        ppr += "<w:pBdr>%s</w:pBdr>" % border
    if shading:
        ppr += '<w:shd w:val="clear" w:color="auto" w:fill="%s"/>' % shading
    if tabs:
        ppr += "<w:tabs>%s</w:tabs>" % "".join(
            '<w:tab w:val="%s" w:pos="%d"/>' % (kind, pos) for kind, pos in tabs)
    ppr += ('<w:spacing w:before="%d" w:after="%d" w:line="%d" '
            'w:lineRule="auto"/>' % (before, after, line))
    if left or right or hanging:
        ind = ""
        if left:
            ind += ' w:left="%d"' % left
        if right:
            ind += ' w:right="%d"' % right
        if hanging:
            ind += ' w:hanging="%d"' % hanging
        ppr += "<w:ind%s/>" % ind
    if align:
        ppr += '<w:jc w:val="%s"/>' % align
    return "<w:p><w:pPr>%s</w:pPr>%s</w:p>" % (ppr, "".join(runs))


def bullet(text, color=None, size=None, font=None, bullet_color=None,
           after=40, left=284):
    """Voce elenco con il punto scritto a mano.

    Non uso la numerazione automatica di Word: sono simboli letterali, cosi'
    il file resta leggibile anche nei convertitori e nei lettori ATS che
    scartano i CV con elenchi mal formattati.
    """
    # il tab stop e' dichiarato esplicitamente: senza, Word usa quello
    # implicito del rientro, Google Docs e LibreOffice no
    return para(
        [run("•\t", color=bullet_color or color, size=size, font=font),
         run(text, color=color, size=size, font=font)],
        after=after, left=left, hanging=left, line=252,
        tabs=[("left", left)])


def bullet_runs(runs, color=None, size=None, font=None, after=40, left=284):
    """Voce elenco con piu' frammenti (es. etichetta in grassetto)."""
    return para([run("•\t", color=color, size=size, font=font)] + runs,
                after=after, left=left, hanging=left, line=252,
                tabs=[("left", left)])


def brk():
    """Riga vuota sottile."""
    return para([], after=0, line=100)


def table(rows, widths, borders=None, cell_margins=None):
    """Tabella semplice: `rows` e' una lista di righe, ogni riga e' una
    lista di celle gia' pronte in XML."""
    tblpr = ('<w:tblPr><w:tblW w:w="%d" w:type="dxa"/>' % sum(widths))
    if borders:
        tblpr += "<w:tblBorders>%s</w:tblBorders>" % borders
    tblpr += '<w:tblLayout w:type="fixed"/>'
    if cell_margins:
        tblpr += "<w:tblCellMar>%s</w:tblCellMar>" % cell_margins
    tblpr += "</w:tblPr>"
    grid = "<w:tblGrid>%s</w:tblGrid>" % "".join(
        '<w:gridCol w:w="%d"/>' % w for w in widths)
    body = ""
    for row in rows:
        body += "<w:tr>" + "".join(row) + "</w:tr>"
    return "<w:tbl>%s%s%s</w:tbl>" % (tblpr, grid, body)


def cell(content, width, shading=None, margins=None, valign=None):
    tcpr = '<w:tcW w:w="%d" w:type="dxa"/>' % width
    if shading:
        tcpr += '<w:shd w:val="clear" w:color="auto" w:fill="%s"/>' % shading
    if margins:
        tcpr += "<w:tcMar>%s</w:tcMar>" % margins
    if valign:
        tcpr += '<w:vAlign w:val="%s"/>' % valign
    return "<w:tc><w:tcPr>%s</w:tcPr>%s</w:tc>" % (tcpr, content)


def borders(spec):
    """spec: dict lato -> (sz, color[, space])."""
    xml = ""
    for side in ("top", "left", "bottom", "right"):
        if side in spec:
            sz, color = spec[side][0], spec[side][1]
            space = spec[side][2] if len(spec[side]) > 2 else 1
            xml += ('<w:%s w:val="single" w:sz="%d" w:space="%d" '
                    'w:color="%s"/>' % (side, sz, space, color))
    return xml


def build_docx(body_xml, core_title, margins=None):
    core = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/'
            'package/2006/metadata/core-properties" '
            'xmlns:dc="http://purl.org/dc/elements/1.1/">'
            '<dc:title>%s</dc:title><dc:creator>LavoroFacile</dc:creator>'
            '</cp:coreProperties>' % esc(core_title))
    m = margins or (MARGIN, MARGIN, MARGIN, MARGIN)
    document = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/'
        'wordprocessingml/2006/main"><w:body>%s'
        '<w:sectPr><w:pgSz w:w="%d" w:h="%d"/>'
        '<w:pgMar w:top="%d" w:right="%d" w:bottom="%d" w:left="%d" '
        'w:header="709" w:footer="709" w:gutter="0"/></w:sectPr>'
        '</w:body></w:document>'
        % (body_xml, PAGE_W, PAGE_H, m[0], m[1], m[2], m[3]))
    return [("[Content_Types].xml", CONTENT_TYPES),
            ("_rels/.rels", RELS),
            ("docProps/core.xml", core),
            ("word/_rels/document.xml.rels", DOC_RELS),
            ("word/styles.xml", STYLES),
            ("word/document.xml", document)]


def write_docx(path, body_xml, title, margins=None):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in build_docx(body_xml, title, margins):
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 26, 12, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data.encode("utf-8"))


GDPR = ("Autorizzo il trattamento dei miei dati personali ai sensi del "
        "D.Lgs. 196/2003 e del Regolamento UE 2016/679 (GDPR).")


def privacy(color, size=16, top_rule=None):
    b = "<w:top w:val=\"single\" w:sz=\"4\" w:space=\"6\" w:color=\"%s\"/>" % top_rule
    return para([run(GDPR, size=size, color=color)],
                before=240, after=0, border=b if top_rule else None)


# ---------------------------------------------------------------- MODELLO 1

def modello_1():
    F, NAVY = "Georgia", "1E3A8A"
    b = []
    b.append(para([run("[Nome e Cognome]", bold=True, size=44, color=NAVY,
                       caps=True, font=F, char_spacing=20)],
                  after=20, line=240))
    b.append(para([run("[Città (PR)] · [+39 340 0000000] · "
                       "[nome.cognome@email.it] · [linkedin.com/in/profilo]",
                       size=19, color="444444", font=F)],
                  after=200, border=borders({"bottom": (16, NAVY, 4)})))

    def h2(t):
        return para([run(t, bold=True, size=20, color=NAVY, caps=True,
                         font=F, char_spacing=16)],
                    before=200, after=100, keep=True,
                    border=borders({"bottom": (6, "CCCCCC", 3)}))

    b.append(h2("Profilo Professionale"))
    b.append(para([run(
        "[Sintesi di 3-4 righe sulle tue competenze principali, anni di "
        "esperienza e il valore aggiunto che puoi portare all'azienda. "
        "Es. Professionista preciso e organizzato con 5 anni di esperienza "
        "in...]", size=20, font=F)], after=120))

    b.append(h2("Esperienze Lavorative"))

    def job(date, title, company, items):
        out = para([run(title, bold=True, size=21, font=F),
                    run("\t", font=F),
                    run(date, italic=True, size=19, color="555555", font=F)],
                   after=10, keep=True, tabs=[("right", TEXT_W)])
        out += para([run(company, italic=True, size=19, color="333333", font=F)],
                    after=40, keep=True)
        for it in items:
            out += bullet(it, size=20, font=F, after=30)
        return out

    b.append(job("[Mese Anno – Presente]", "[Titolo della Posizione / Ruolo]",
                 "[Nome Azienda] · [Città]",
                 ["[Mansione principale svolta e responsabilità gestite "
                  "quotidianamente]",
                  "[Progetto rilevante portato a termine o miglioramento "
                  "introdotto]",
                  "[Strumenti o software specifici utilizzati]"]))
    b.append(para([], after=60, line=60))
    b.append(job("[Mese Anno – Mese Anno]", "[Titolo Posizione Precedente]",
                 "[Nome Azienda Precedente] · [Città]",
                 ["[Descrizione compiti e risultati raggiunti]",
                  "[Attività di coordinamento o gestione clienti/fornitori]"]))

    b.append(h2("Istruzione e Formazione"))
    b.append(para([run("[Diploma / Laurea in ...]", bold=True, size=21, font=F),
                   run("\t", font=F),
                   run("[Anno Conseguimento]", italic=True, size=19,
                       color="555555", font=F)],
                  after=10, keep=True, tabs=[("right", TEXT_W)]))
    b.append(para([run("[Istituto Scolastico / Università degli Studi di ...] · "
                       "[Votazione eventuale]", italic=True, size=19,
                       color="333333", font=F)], after=80))

    b.append(h2("Competenze e Certificazioni"))
    for label, text in [
        ("Competenze Tecniche:", "[Es. Pacchetto Office, Excel avanzato, "
                                 "Gestionale SAP/Zucchetti, ecc.]"),
        ("Lingue Straniere:", "[Italiano: Madrelingua · Inglese: B2 "
                              "Intermedio professionale]"),
        ("Certificazioni:", "[Patente B, Certificazione sicurezza, HACCP, ecc.]"),
    ]:
        b.append(bullet_runs([run(label + " ", bold=True, size=20, font=F),
                              run(text, size=20, font=F)], size=20, font=F,
                             after=40))

    b.append(privacy("777777", 15, "CCCCCC"))
    return "".join(b), "Curriculum Vitae - Modello Classico ATS"


# ---------------------------------------------------------------- MODELLO 2

def modello_2():
    SIDE, MAIN = 3300, 8606
    DARK, WHITE, SKY = "0F172A", "F8FAFC", "38BDF8"
    F = "Segoe UI"
    side_m = ('<w:top w:w="0" w:type="dxa"/><w:left w:w="340" w:type="dxa"/>'
              '<w:bottom w:w="0" w:type="dxa"/><w:right w:w="340" w:type="dxa"/>')
    main_m = ('<w:top w:w="0" w:type="dxa"/><w:left w:w="340" w:type="dxa"/>'
              '<w:bottom w:w="0" w:type="dxa"/><w:right w:w="200" w:type="dxa"/>')

    def sh(t):
        return para([run(t, bold=True, size=20, color=SKY, caps=True,
                         font=F, char_spacing=24)],
                    before=280, after=90, keep=True,
                    border=borders({"bottom": (6, "334155", 3)}))

    s = para([run("Contatti", bold=True, size=20, color=SKY, caps=True,
                  font=F, char_spacing=24)],
             before=0, after=90, keep=True,
             border=borders({"bottom": (6, "334155", 3)}))
    for line in ["[Città (Provincia)]", "[+39 340 0000000]",
                 "[email@esempio.it]", "[linkedin.com/in/...]"]:
        s += para([run(line, size=19, color="CBD5E1", font=F)], after=40)

    s += sh("Competenze")
    for c in ["[Competenza 1]", "[Competenza 2]", "[Competenza 3]",
              "[Competenza 4]", "[Problem Solving]", "[Lavoro di Squadra]"]:
        s += bullet(c, size=19, color="CBD5E1", bullet_color=SKY, font=F,
                    after=30, left=284)

    s += sh("Lingue")
    s += para([run("Italiano: ", bold=True, size=19, color="CBD5E1", font=F),
               run("Madrelingua", size=19, color="CBD5E1", font=F)], after=30)
    s += para([run("Inglese: ", bold=True, size=19, color="CBD5E1", font=F),
               run("B2 Intermedio", size=19, color="CBD5E1", font=F)], after=30)

    s += sh("Software")
    s += para([run("[Excel / Word / Gestionale / Software specifico]",
                   size=19, color="CBD5E1", font=F)], after=60)

    def h2(t):
        return para([run(t, bold=True, size=20, color="0F172A", caps=True,
                         font=F, char_spacing=16)],
                    before=240, after=100, keep=True,
                    border=borders({"bottom": (12, "0284C7", 4)}))

    def item(role, date, company, desc):
        out = para([run(role, bold=True, size=21, color="0F172A", font=F),
                    run("\t", font=F),
                    run(date, bold=True, size=20, color="64748B", font=F)],
                   after=10, keep=True, tabs=[("right", MAIN - 540)])
        out += para([run(company, bold=True, size=19, color="64748B", font=F)],
                    after=40, keep=True)
        out += para([run(desc, size=20, color="1E293B", font=F)], after=120)
        return out

    m = para([run("[Nome e Cognome]", bold=True, size=48, color="0F172A",
                  caps=True, font=F, char_spacing=-10)], after=20, line=240)
    m += para([run("[Qualifica / Posizione Desiderata]", bold=True, size=26,
                   color="0284C7", font=F)], before=40, after=200)
    m += h2("Profilo")
    m += para([run("[Breve presentazione professionale di forte impatto che "
                   "descrive le tue motivazioni, l'esperienza pregressa e il "
                   "contributo operativo immediato che puoi portare.]",
                   size=20, color="1E293B", font=F)], after=120)
    m += h2("Esperienze Lavorative")
    m += item("[Ruolo Ricoperto]", "[Anno – Presente]", "[Azienda] · [Città]",
              "[Descrizione sintetica delle mansioni principali, obiettivi "
              "raggiunti o processi gestiti con successo.]")
    m += item("[Ruolo Precedente]", "[Anno – Anno]", "[Azienda Precedente] · [Città]",
              "[Descrizione delle attività svolte e delle responsabilità "
              "assegnate.]")
    m += h2("Istruzione")
    m += item("[Titolo di Studio]", "[Anno]", "[Istituto / Università]", "")
    m += privacy("94A3B8", 15, "E2E8F0")

    t = table([[
        cell(s, SIDE, shading=DARK, margins=side_m, valign="top"),
        cell(m, MAIN, margins=main_m, valign="top"),
    ]], [SIDE, MAIN])
    tail = para([], after=0, line=20)
    # margini sinistro e destro a zero: la fascia scura arriva al bordo del
    # foglio invece di lasciare una striscia bianca di 2 cm
    return (t + tail, "Curriculum Vitae - Modello Moderno Due Colonne",
            (MARGIN, 0, MARGIN, 0))


# ---------------------------------------------------------------- MODELLO 3

def modello_3():
    F, GREEN = "Calibri", "047857"
    b = []
    b.append(para([run("[Nome] ", size=52, color="111111", font=F),
                   run("[Cognome]", bold=True, size=52, color=GREEN, font=F)],
                  after=20, line=240))
    b.append(para([run("[Posizione / Titolo Professionale]", size=24,
                       color="555555", caps=True, font=F, char_spacing=16)],
                  after=60))
    b.append(para([run("[Città] · [+39 340 0000000] · [email@dominio.it] · "
                       "[linkedin.com/in/...]", size=18, color="777777",
                       font=F)], after=100))

    def h2(t):
        return para([run(t, size=18, color=GREEN, caps=True, font=F,
                         char_spacing=40)],
                    before=280, after=110, keep=True,
                    border=borders({"bottom": (4, "E5E7EB", 4)}))

    def entry(role, date, meta, desc=None):
        out = para([run(role, bold=True, size=20, color="222222", font=F),
                    run("\t", font=F),
                    run(date, size=19, color="6B7280", font=F)],
                   after=10, keep=True, tabs=[("right", TEXT_W)])
        out += para([run(meta, size=19, color="6B7280", font=F)], after=40,
                    keep=True)
        if desc:
            out += para([run(desc, size=20, color="222222", font=F)], after=140)
        return out

    b.append(h2("Profilo"))
    b.append(para([run("[Descrizione essenziale e focalizzata sui punti di "
                       "forza, l'esperienza operativa e le attitudini "
                       "principali al lavoro di squadra e alla gestione delle "
                       "priorità.]", size=20, color="222222", font=F)],
                  after=120))
    b.append(h2("Esperienza Professionale"))
    b.append(entry("[Ruolo Ricoperto]", "[2022 – Presente]", "[Nome Azienda] · [Città]",
                   "[Principali attività svolte, strumenti utilizzati e "
                   "risultati conseguiti.]"))
    b.append(entry("[Ruolo Precedente]", "[2019 – 2022]", "[Azienda Precedente] · [Città]",
                   "[Dettagli sulle mansioni e responsabilità affidate.]"))
    b.append(h2("Formazione"))
    b.append(entry("[Titolo di Studio / Qualifica]", "[Anno]",
                   "[Nome Istituto o Università]"))
    b.append(h2("Competenze"))
    for label, text in [
        ("Professionali:", "[Competenza 1, Competenza 2, Competenza 3, "
                           "Gestione priorità]"),
        ("Linguistiche:", "[Italiano madrelingua, Inglese B2]"),
        ("Digitali:", "[Excel, Software aziendali, Strumenti digitali]"),
    ]:
        b.append(para([run(label + " ", bold=True, size=20, color="222222", font=F),
                       run(text, size=20, color="222222", font=F)], after=60))
    b.append(privacy("9CA3AF", 14, "F3F4F6"))
    return "".join(b), "Curriculum Vitae - Modello Minimal Elegante"


# ---------------------------------------------------------------- MODELLO 4

def modello_4():
    F, RED, INK = "Segoe UI", "991B1B", "0F172A"

    def h2(t):
        return para([run(t, bold=True, size=20, color=INK, caps=True,
                         font=F, char_spacing=16)],
                    before=280, after=110, keep=True,
                    border=borders({"bottom": (6, "CBD5E1", 4)}))

    def exp(role, date, company, items):
        out = para([run(role, bold=True, size=21, color=INK, font=F),
                    run("\t", font=F),
                    run(date, bold=True, size=19, color="64748B", font=F)],
                   after=10, keep=True, tabs=[("right", TEXT_W)])
        out += para([run(company, bold=True, size=19, color="64748B", font=F)],
                    after=40, keep=True)
        for it in items:
            out += bullet(it, size=20, color="1E293B", font=F, after=30)
        return out

    head = para([run("[Nome e Cognome]", bold=True, size=46, color=INK, font=F)],
                after=20, line=240)
    head += para([run("[Qualifica Senior / Responsabile / Specialista]",
                      bold=True, size=26, color=RED, font=F)], before=40, after=80)
    head += para([run("[Città (PR)] · [+39 340 0000000] · [email@azienda.it] · "
                      "[linkedin.com/in/profilo]", size=19, color="475569",
                      font=F)], after=20)
    head_cell = cell(head, TEXT_W, shading="F8FAFC", valign="top",
                     margins=('<w:top w:w="220" w:type="dxa"/>'
                              '<w:left w:w="240" w:type="dxa"/>'
                              '<w:bottom w:w="220" w:type="dxa"/>'
                              '<w:right w:w="240" w:type="dxa"/>'))
    head_tbl = table([[head_cell]], [TEXT_W],
                     borders=borders({"left": (40, RED, 0),
                                      "top": (4, "E2E8F0", 0),
                                      "bottom": (4, "E2E8F0", 0),
                                      "right": (4, "E2E8F0", 0)}))

    b = head_tbl + para([], after=0, line=40)
    b += h2("Sintesi Professionale")
    b += para([run("[Professionista esperto con oltre [N] anni di attività "
                   "consolidata nel settore [Settore]. Comprovata capacità di "
                   "coordinamento risorse, ottimizzazione dei processi "
                   "operativi e raggiungimento degli obiettivi aziendali. "
                   "Forte orientamento alla risoluzione dei problemi complessi "
                   "e alla leadership collaborativa.]", size=20, color="1E293B",
                   font=F)], after=120)
    b += h2("Esperienze Lavorative Rilevanti")
    b += exp("[Ruolo di Responsabilità / Senior]", "[2020 – Presente]",
             "[Azienda Leader] · [Città]",
             ["[Responsabilità principale di gestione reparto / budget / clienti]",
              "[Risultato quantitativo: es. incremento fatturato +15% o "
              "riduzione tempi del 20%]",
              "[Coordinamento di un team composto da N persone]"])
    b += para([], after=60, line=60)
    b += exp("[Ruolo Precedente]", "[2015 – 2020]", "[Azienda Precedente] · [Città]",
             ["[Mansioni specialistiche gestite]",
              "[Progetti chiave sviluppati e conclusi con successo]"])
    b += h2("Istruzione e Certificazioni")
    b += exp("[Titolo Accademico / Master / Laurea]", "[Anno]",
             "[Università / Business School]", [])
    b += h2("Competenze Chiave")

    half = (TEXT_W - 400) // 2
    left_c = ""
    for x in ["Pianificazione strategica e budgeting",
              "Gestione e motivazione team",
              "Negoziazione fornitori e clienti chiave"]:
        left_c += bullet(x, size=20, color="1E293B", font=F, after=30)
    right_c = ""
    for x in ["Software gestionali ERP avanzati",
              "Inglese professionale fluente (C1)",
              "Analisi dati e reporting direzionale"]:
        right_c += bullet(x, size=20, color="1E293B", font=F, after=30)

    c1 = cell(para([run("Competenze Gestionali", bold=True, size=20,
                        color=INK, font=F)], after=60) + left_c,
              half, margins=None)
    c2 = cell(para([run("Competenze Tecniche & Lingue", bold=True, size=20,
                        color=INK, font=F)], after=60) + right_c,
              TEXT_W - half, margins=None)
    b += table([[c1, c2]], [half, TEXT_W - half],
               cell_margins=('<w:top w:w="0" w:type="dxa"/>'
                             '<w:left w:w="0" w:type="dxa"/>'
                             '<w:bottom w:w="0" w:type="dxa"/>'
                             '<w:right w:w="200" w:type="dxa"/>'))
    b += para([], after=0, line=40)
    b += privacy("94A3B8", 15, "E2E8F0")
    return b, "Curriculum Vitae - Modello Professionale Senior"


# ---------------------------------------------------------------- MODELLO 5

def modello_5():
    F, BLUE = "Segoe UI", "0284C7"
    b = []
    b.append(para([run("[Nome e Cognome]", bold=True, size=46, color=BLUE,
                       font=F)], after=20, line=240))
    b.append(para([run("[Neodiplomato / Neolaureato in ... / Candidato Junior]",
                       bold=True, size=24, color="475569", font=F)], after=40))
    b.append(para([run("[Città] · [+39 340 0000000] · [email@esempio.it] · "
                       "[linkedin.com/in/...]", size=19, color="64748B",
                       font=F)],
                  after=200, border=borders({"bottom": (12, "E2E8F0", 6)})))

    def h2(t):
        return para([run(t, bold=True, size=20, color=BLUE, caps=True,
                         font=F, char_spacing=16)],
                    before=260, after=100, keep=True,
                    border=borders({"bottom": (4, "BAE6FD", 3)}))

    def item(title, period, meta, bullets_):
        out = para([run(title, bold=True, size=20, color="1E293B", font=F),
                    run("\t", font=F),
                    run(period, size=19, color="64748B", font=F)],
                   after=10, keep=True, tabs=[("right", TEXT_W)])
        out += para([run(meta, size=19, color="64748B", font=F)], after=40,
                    keep=True)
        for x in bullets_:
            out += bullet(x, size=20, color="1E293B", font=F, after=30)
        return out

    b.append(h2("Obiettivo Professionale"))
    b.append(para([run("[Neodiplomato/Neolaureato con forte motivazione, "
                       "rapidità nell'apprendimento e ottime capacità "
                       "relazionali. Desidero intraprendere un percorso di "
                       "crescita all'interno di una realtà dinamica, offrendo "
                       "massima serietà, puntualità e determinazione "
                       "nell'acquisire competenze operative sul campo.]",
                       size=20, color="1E293B", font=F)], after=120))
    b.append(h2("Istruzione e Formazione"))
    b.append(item("[Diploma di Maturità / Laurea Triennale in ...]", "[Anno]",
                  "[Nome Istituto o Università] · Votazione: [Es. 90/100 o 105/110]",
                  ["[Tesi o progetto principale sviluppato]",
                   "[Materie di maggior interesse o laboratori svolti]"]))
    b.append(h2("Esperienze Formative, Stage o Lavori Saltuari"))
    b.append(item("[Tirocinio Formativo / Stage / Lavoro Estivo]", "[Periodo]",
                  "[Nome Azienda o Ente] · [Città]",
                  ["[Attività pratiche svolte e strumenti utilizzati]",
                   "[Capacità di lavorare a contatto con il pubblico o con il "
                   "team]"]))
    b.append(h2("Competenze e Soft Skills"))
    for label, text in [
        ("Competenze Digitali:", "Buona padronanza pacchetto Office (Word, "
                                 "Excel, PowerPoint), navigazione web e "
                                 "strumenti digitali."),
        ("Lingue Straniere:", "Italiano madrelingua · Inglese: [livello B1/B2]."),
        ("Punti di Forza Personali:", "Puntualità, spirito di iniziativa, "
                                      "entusiasmo nell'imparare e "
                                      "predisposizione al lavoro di gruppo."),
        ("Altro:", "Automunito / Patente B · Disponibilità immediata anche a "
                   "turni o trasferte."),
    ]:
        b.append(bullet_runs(
            [run(label + " ", bold=True, size=20, color="1E293B", font=F),
             run(text, size=20, color="1E293B", font=F)],
            color="1E293B", size=20, font=F, after=60))
    b.append(privacy("94A3B8", 15, "E2E8F0"))
    return "".join(b), "Curriculum Vitae - Modello Junior e Primo Impiego"


# ---------------------------------------------------------------- MAIN

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    files = [
        ("1-Modello-Classico-ATS.docx", modello_1),
        ("2-Modello-Moderno-Due-Colonne.docx", modello_2),
        ("3-Modello-Minimal-Elegante.docx", modello_3),
        ("4-Modello-Professionale-Senior.docx", modello_4),
        ("5-Modello-Junior-Formativo.docx", modello_5),
    ]
    for name, fn in files:
        result = fn()
        body, title = result[0], result[1]
        margins = result[2] if len(result) > 2 else None
        path = os.path.join(out, name)
        write_docx(path, body, title, margins)
        print("%-42s %6d B" % (name, os.path.getsize(path)))


if __name__ == "__main__":
    main()
