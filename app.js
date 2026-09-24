/* ============ FatturaFacile — app.js ============ */
(() => {
  'use strict';

  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));

  const DRAFT_KEY = 'ff_draft_v2';
  const SAVED_KEY = 'ff_saved_v1';

  const emptyState = (type = 'fattura') => ({
    type,
    seller: { name: '', vat: '', address: '', pec: '' },
    client: { name: '', vat: '', address: '' },
    meta: { number: '', date: '', due: '', rc: false },
    items: [{ id: 1, desc: '', qty: 1, price: 0, vat: '22' }],
    pay: { method: 'Bonifico bancario', iban: '', notes: '' },
  });

  const sampleState = () => ({
    type: 'fattura',
    seller: {
      name: 'Mario Rossi — Consulente digitale',
      vat: 'IT01234567890',
      address: 'Via Roma 1, 37100 Verona (VR)',
      pec: 'mario.rossi@pec.it',
    },
    client: {
      name: 'Pasticceria Dolce Vita S.n.c.',
      vat: 'IT98765432109',
      address: 'Corso Porta Nuova 2, 25100 Brescia (BS)',
    },
    meta: {
      number: 'IT001/2026',
      date: todayISO(),
      due: plusDaysISO(30),
      rc: false,
    },
    items: [
      { id: 1, desc: 'Sito web vetrina — progettazione, sviluppo e pubblicazione', qty: 1, price: 1200, vat: '22' },
      { id: 2, desc: 'Manutenzione annuale (12 mesi)', qty: 1, price: 360, vat: '22' },
      { id: 3, desc: 'Hosting e dominio (12 mesi)', qty: 1, price: 119, vat: '22' },
    ],
    pay: {
      method: 'Bonifico bancario',
      iban: 'IT60 X054 2811 1010 0000 0123 456',
      notes: 'Pagamento entro 30 giorni dal ricevimento della fattura.',
    },
  });

  let state = emptyState();
  let nextId = 1;

  /* ---------- helpers ---------- */
  function parseNum(v) {
    if (typeof v === 'number') return v;
    let s = String(v).trim().replace(/[€\s]/g, '');
    if (!s) return 0;
    if (s.includes(',')) {
      s = s.replace(/\./g, '').replace(',', '.');
    }
    const n = parseFloat(s);
    return Number.isFinite(n) ? n : 0;
  }
  const fmtMoney = (n) =>
    new Intl.NumberFormat('it-IT', { style: 'currency', currency: 'EUR' }).format(n);
  const fmtQty = (n) =>
    new Intl.NumberFormat('it-IT', { maximumFractionDigits: 2 }).format(n);
  const fmtDate = (iso) => {
    if (!iso) return '—';
    const [y, m, d] = iso.split('-');
    return `${d}/${m}/${y}`;
  };
  const esc = (s) =>
    String(s ?? '')
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  const vatLabel = (v) => (v === '0' ? 'Esente (0%)' : v + '%');
  const typeLabel = (t) => (t === 'preventivo' ? 'Preventivo' : 'Fattura');

  function computeTotals() {
    const rc = !!state.meta.rc;
    let subtotal = 0;
    const perRate = {};
    for (const it of state.items) {
      const amt = parseNum(it.qty) * parseNum(it.price);
      subtotal += amt;
      if (!rc && it.vat !== '0') perRate[it.vat] = (perRate[it.vat] || 0) + amt;
    }
    const vatTotal = Object.values(perRate).reduce((a, b) => a + b, 0);
    const total = rc ? subtotal : subtotal + vatTotal;
    return { subtotal, perRate, vatTotal, total, rc };
  }

  /* ---------- preview render ---------- */
  function renderPreview() {
    const { subtotal, perRate, total, rc } = computeTotals();
    const t = state.type;
    const s = state.seller, c = state.client, m = state.meta;

    const itemRows = state.items
      .map((it) => {
        const amt = parseNum(it.qty) * parseNum(it.price);
        return `<tr>
          <td>${esc(it.desc) || '<span class="muted">—</span>'}</td>
          <td class="num">${fmtQty(parseNum(it.qty))}</td>
          <td class="num">${fmtMoney(parseNum(it.price))}</td>
          <td class="vatcol">${rc ? 'RC' : vatLabel(it.vat)}</td>
          <td class="num">${fmtMoney(amt)}</td>
        </tr>`;
      })
      .join('');

    const isPrev = t === 'preventivo';
    const dueLabel = isPrev ? 'Valido fino al' : 'Scadenza';
    const payBlock = isPrev
      ? ''
      : `<div class="pay-box">
          <div><strong>Pagamento:</strong> ${esc(state.pay.method)}</div>
          ${state.pay.iban ? `<div class="pay-line">IBAN / coordinate: ${esc(state.pay.iban)}</div>` : ''}
          <div class="pay-line"><strong>${dueLabel}:</strong> ${fmtDate(m.due)}</div>
        </div>`;

    const notesBlock = state.pay.notes
      ? `<div class="notes-block"><strong>Note:</strong> ${esc(state.pay.notes)}</div>`
      : '';

    const isEmptyDoc = !s.name && !c.name && !state.items.some((i) => i.desc);

    const partyLines = (p, showPec, ph) => {
      let h = `<div class="party-name">${esc(p.name) || `<span class="muted">${ph}</span>`}</div>`;
      if (p.vat) h += `<div class="party-line">P.IVA / C.F.: ${esc(p.vat)}</div>`;
      if (p.address) h += `<div class="party-line">${esc(p.address)}</div>`;
      if (showPec && p.pec) h += `<div class="party-line">PEC: ${esc(p.pec)}</div>`;
      return h;
    };

    const footerLine = [s.name, s.vat, s.address, s.pec].filter(Boolean).map(esc).join(' · ');

    $('#sheet').innerHTML = `
      <div class="sheet-top">
        <div class="sheet-title">${typeLabel(t)}<small>${isPrev ? 'Documento non valido ai fini IVA' : 'Documento fiscale'}</small></div>
        <div class="sheet-numeral">
          <strong>${m.number ? esc(m.number) : '<span class="muted">—</span>'}</strong>
          <span>${m.date ? 'del ' + fmtDate(m.date) : '—'}</span>
        </div>
      </div>

      <div class="parties">
        <div><div class="party-label">${isPrev ? 'Fornitore' : 'Emittente'}</div>${partyLines(s, true, 'La tua azienda')}</div>
        <div><div class="party-label">Cliente</div>${partyLines(c, false, 'Nome cliente')}</div>
      </div>

      ${isEmptyDoc ? '<div class="empty-hint no-print">✍️ Compila i campi a sinistra: il documento si costruisce qui in tempo reale.</div>' : ''}

      <table class="items-table">
        <thead><tr>
          <th>Descrizione</th><th class="num">Q.tà</th><th class="num">Prezzo unit.</th><th>IVA</th><th class="num">Importo</th>
        </tr></thead>
        <tbody>${itemRows}</tbody>
      </table>

      <div class="totals-wrap">
        <div class="totals">
          <div class="totals-row"><span>Subtotale</span><span>${fmtMoney(subtotal)}</span></div>
          ${rc
            ? `<div class="totals-row"><span>IVA — reverse charge</span><span>${fmtMoney(0)}</span></div>
               <div class="totals-row rc-note"><span>art. 17 c.2 DPR 633/72</span><span></span></div>`
            : (['22', '10', '5', '0']
                .filter((r) => perRate[r] != null)
                .map((r) => `<div class="totals-row"><span>${r === '0' ? 'Esente (0%)' : 'IVA ' + r + '%'}</span><span>${r === '0' ? fmtMoney(perRate[r]) : fmtMoney(perRate[r])}</span></div>`)
                .join(''))}
          <div class="totals-row total"><span>${isPrev ? 'Totale' : 'Totale fattura'}</span><span class="amount">${fmtMoney(total)}</span></div>
        </div>
      </div>

      ${payBlock}
      ${notesBlock}

      <div class="sheet-footer">${footerLine || '&nbsp;'}</div>
    `;
  }

  /* ---------- items rows ---------- */
  function renderItems() {
    const body = $('#items-body');
    body.innerHTML = '';
    for (const it of state.items) {
      const row = document.createElement('div');
      row.className = 'item-row';
      row.dataset.id = it.id;
      row.innerHTML = `
        <input class="i-desc" type="text" placeholder="Descrizione del servizio o prodotto" value="${esc(it.desc)}" aria-label="Descrizione" />
        <input class="i-qty" type="text" inputmode="decimal" value="${fmtQty(parseNum(it.qty))}" aria-label="Quantità" />
        <input class="i-price" type="text" inputmode="decimal" placeholder="0,00" value="${it.price ? parseNum(it.price).toFixed(2).replace('.', ',') : ''}" aria-label="Prezzo unitario" />
        <select class="i-vat" aria-label="Aliquota IVA">
          ${['22', '10', '5', '0'].map((r) => `<option value="${r}" ${it.vat === r ? 'selected' : ''}>${vatLabel(r)}</option>`).join('')}
        </select>
        <div class="row-total">${fmtMoney(parseNum(it.qty) * parseNum(it.price))}</div>
        <button type="button" class="item-del" title="Rimuovi voce" aria-label="Rimuovi voce">✕</button>
      `;
      row.querySelector('.i-desc').addEventListener('input', (e) => { it.desc = e.target.value; update(); });
      row.querySelector('.i-qty').addEventListener('input', (e) => { it.qty = parseNum(e.target.value); update(); });
      row.querySelector('.i-price').addEventListener('input', (e) => { it.price = parseNum(e.target.value); update(); });
      row.querySelector('.i-vat').addEventListener('change', (e) => { it.vat = e.target.value; update(); });
      row.querySelector('.item-del').addEventListener('click', () => {
        if (state.items.length === 1) {
          Object.assign(it, { desc: '', qty: 1, price: 0, vat: '22' });
        } else {
          state.items = state.items.filter((x) => x.id !== it.id);
        }
        renderItems();
        update();
      });
      body.appendChild(row);
    }
    nextId = Math.max(0, ...state.items.map((i) => i.id)) + 1;
  }

  /* ---------- state sync ---------- */
  function syncForm() {
    $$('[data-bind]').forEach((el) => {
      const [sec, field] = el.dataset.bind.split('.');
      const v = state[sec][field];
      if (el.type === 'checkbox') el.checked = !!v;
      else el.value = v ?? '';
    });
    $$('#pay-section input, #pay-section select, #pay-section textarea')
      .forEach((el) => (el.disabled = state.type === 'preventivo'));
    $('#label-due').firstChild.textContent = state.type === 'preventivo' ? 'Validità ' : 'Scadenza ';
    $('#type-fattura').classList.toggle('is-active', state.type === 'fattura');
    $('#type-fattura').setAttribute('aria-pressed', state.type === 'fattura');
    $('#type-preventivo').classList.toggle('is-active', state.type === 'preventivo');
    $('#type-preventivo').setAttribute('aria-pressed', state.type === 'preventivo');
  }

  function update() {
    renderPreview();
    saveDraft();
  }

  /* ---------- persistence ---------- */
  function saveDraft() {
    try { localStorage.setItem(DRAFT_KEY, JSON.stringify(state)); } catch { /* noop */ }
  }
  function loadDraft() {
    try {
      const raw = localStorage.getItem(DRAFT_KEY);
      if (!raw) return null;
      const d = JSON.parse(raw);
      if (!d || !Array.isArray(d.items) || d.items.length === 0) return null;
      return d;
    } catch { return null; }
  }
  function loadSaved() {
    try {
      const raw = localStorage.getItem(SAVED_KEY);
      const d = raw ? JSON.parse(raw) : [];
      return Array.isArray(d) ? d : [];
    } catch { return []; }
  }
  function saveSaved(list) {
    try { localStorage.setItem(SAVED_KEY, JSON.stringify(list)); } catch { /* noop */ }
  }

  function renderSavedList() {
    const list = loadSaved();
    const ul = $('#saved-list');
    $('#saved-count').textContent = list.length;
    if (!list.length) {
      ul.innerHTML = '<li class="saved-empty">Nessun documento salvato: compila e premi “Salva”.</li>';
      return;
    }
    ul.innerHTML = '';
    for (const doc of list) {
      const li = document.createElement('li');
      li.className = 'saved-item';
      const when = doc.savedAt
        ? new Date(doc.savedAt).toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit', year: 'numeric' })
        : '';
      li.innerHTML = `
        <span class="saved-name">${esc(doc.name)}</span>
        <span class="saved-when">${when}</span>
        <button type="button" class="icon-btn" data-act="open" title="Apri">📂</button>
        <button type="button" class="icon-btn" data-act="del" title="Elimina">🗑️</button>
      `;
      li.querySelector('[data-act="open"]').addEventListener('click', () => {
        state = { ...emptyState(doc.doc.type), ...doc.doc };
        renderItems(); syncForm(); update();
        toast('Documento caricato ✓');
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });
      li.querySelector('[data-act="del"]').addEventListener('click', () => {
        const next = loadSaved().filter((x) => x.id !== doc.id);
        saveSaved(next);
        renderSavedList();
        toast('Documento eliminato');
      });
      ul.appendChild(li);
    }
  }

  /* ---------- toast ---------- */
  let toastTimer;
  function toast(msg) {
    const t = $('#toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove('show'), 2200);
  }

  /* ---------- init ---------- */
  function init() {
    const draft = loadDraft();
    state = draft || emptyState();

    // bind form inputs
    $$('[data-bind]').forEach((el) => {
      const [sec, field] = el.dataset.bind.split('.');
      const ev = el.tagName === 'SELECT' || el.type === 'checkbox' || el.type === 'date' ? 'change' : 'input';
      el.addEventListener(ev, (e) => {
        state[sec][field] = el.type === 'checkbox' ? el.checked : e.target.value;
        update();
      });
    });

    // type toggle
    $('#type-fattura').addEventListener('click', () => setType('fattura'));
    $('#type-preventivo').addEventListener('click', () => setType('preventivo'));

    // add item
    $('#btn-add-item').addEventListener('click', () => {
      state.items.push({ id: nextId++, desc: '', qty: 1, price: 0, vat: '22' });
      renderItems();
      update();
      const rows = $$('#items-body .i-desc');
      rows[rows.length - 1]?.focus();
    });

    // actions
    $('#btn-pdf').addEventListener('click', () => window.print());
    $('#btn-save').addEventListener('click', () => {
      const list = loadSaved();
      const name = `${typeLabel(state.type)} ${state.meta.number || 'senza numero'} — ${state.client.name || 'cliente'}`;
      const existing = list.find((d) => d.name === name);
      if (existing) {
        existing.doc = structuredClone(state);
        existing.savedAt = new Date().toISOString();
      } else {
        list.unshift({ id: Date.now(), name, doc: structuredClone(state), savedAt: new Date().toISOString() });
      }
      saveSaved(list.slice(0, 50));
      renderSavedList();
      toast('Documento salvato ✓');
    });
    $('#btn-new').addEventListener('click', () => {
      if (state.items.some((i) => i.desc) || state.seller.name || state.client.name) {
        if (!confirm('Iniziare un documento vuoto? I campi attuali verranno cancellati (quelli salvati restano).')) return;
      }
      state = emptyState(state.type);
      renderItems(); syncForm(); update();
      toast('Documento nuovo ✓');
    });

    // Gestione schede Mobile (Compila / Anteprima)
    const ws = $('#ff-workspace');
    const tabForm = $('#tab-ff-form');
    const tabPreview = $('#tab-ff-preview');
    if (tabForm && tabPreview && ws) {
      tabForm.addEventListener('click', () => {
        ws.setAttribute('data-mobile-view', 'form');
        tabForm.classList.add('is-active');
        tabPreview.classList.remove('is-active');
      });
      tabPreview.addEventListener('click', () => {
        ws.setAttribute('data-mobile-view', 'preview');
        tabPreview.classList.add('is-active');
        tabForm.classList.remove('is-active');
        window.scrollTo({ top: ws.offsetTop - 20, behavior: 'smooth' });
      });
    }

    renderItems();
    syncForm();
    renderSavedList();
    renderPreview();
  }

  function setType(t) {
    if (state.type === t) return;
    state.type = t;
    syncForm();
    update();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
