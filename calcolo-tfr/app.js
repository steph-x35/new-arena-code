/* ============ Calcolatore TFR Netto — app.js ============ */
(() => {
  'use strict';

  const $ = (s) => document.querySelector(s);

  /* ---------- Helpers ---------- */
  function parseNum(v) {
    if (typeof v === 'number') return v;
    let s = String(v ?? '').trim().replace(/[€\s]/g, '');
    if (!s) return 0;
    if (s.includes(',')) s = s.replace(/\./g, '').replace(',', '.');
    const n = parseFloat(s);
    return Number.isFinite(n) ? n : 0;
  }

  const fmt = (n) =>
    new Intl.NumberFormat('it-IT', { style: 'currency', currency: 'EUR' }).format(n);
  const fmtPct = (n) =>
    new Intl.NumberFormat('it-IT', { minimumFractionDigits: 1, maximumFractionDigits: 2 }).format(n) + '%';

  function irpefTeorica(reddito) {
    let tax = 0;
    if (reddito <= 0) return 0;
    if (reddito <= 28000) {
      tax = reddito * 0.23;
    } else if (reddito <= 50000) {
      tax = 28000 * 0.23 + (reddito - 28000) * 0.35;
    } else {
      tax = 28000 * 0.23 + 22000 * 0.35 + (reddito - 50000) * 0.43;
    }
    return tax;
  }

  /* ---------- Calcolo ---------- */
  function compute() {
    const ral = parseNum($('#tfr-ral').value);
    const anni = parseInt($('#tfr-anni').value, 10) || 0;
    const mesi = parseInt($('#tfr-mesi').value, 10) || 0;
    const anticipi = parseNum($('#tfr-anticipi').value);
    const dest = $('#tfr-dest').value;

    const anzianita = anni + (mesi / 12);

    if (ral <= 0 || anzianita <= 0) {
      return {
        hasData: false,
        ral: 0, anni, mesi, anzianita: 0,
        quotaAnnua: 0, tfrLordo: 0, anticipi: 0,
        redditoRif: 0, aliquotaEffettiva: 0, imposta: 0,
        tfrNetto: 0, dest,
      };
    }

    // Quota annua (Art. 2120 c.c.): RAL / 13.5 - contributo IVS 0.5%
    const quotaAnnua = (ral / 13.5) - (ral * 0.005);
    const tfrLordo = quotaAnnua * anzianita;
    const tfrBaseImponibile = Math.max(0, tfrLordo - anticipi);

    let aliquotaEffettiva = 0.23;
    let redditoRif = 0;

    if (dest === 'fondo') {
      // Fondo pensione complementare: ritenuta agevolata 15% - 9%
      aliquotaEffettiva = Math.max(0.09, 0.15 - Math.max(0, anni - 15) * 0.003);
    } else {
      // Mantenuto in azienda: Tassazione Separata IRPEF (art. 19 TUIR)
      redditoRif = anzianita > 0 ? (tfrLordo / anzianita) * 12 : 0;
      const irp = irpefTeorica(redditoRif);
      const alMedia = redditoRif > 0 ? (irp / redditoRif) : 0.23;
      // Per legge non può essere inferiore all'aliquota minima del 1° scaglione (23%)
      aliquotaEffettiva = Math.max(0.23, alMedia);
    }

    const imposta = tfrBaseImponibile * aliquotaEffettiva;
    const tfrNetto = Math.max(0, tfrBaseImponibile - imposta);

    return {
      hasData: true,
      ral, anni, mesi, anzianita,
      quotaAnnua, tfrLordo, anticipi,
      redditoRif, aliquotaEffettiva, imposta,
      tfrNetto, dest,
    };
  }

  /* ---------- Render ---------- */
  function render() {
    const r = compute();

    $('#out-tfr-netto').textContent = fmt(r.tfrNetto);
    $('#out-tfr-lordo-sub').textContent = `TFR Lordo totale: ${fmt(r.tfrLordo)}`;

    $('#r-ral').textContent = fmt(r.ral);
    $('#r-quota-annua').textContent = fmt(r.quotaAnnua);

    let anzStr = `${r.anni} anni`;
    if (r.mesi > 0) anzStr += ` e ${r.mesi} mesi`;
    $('#r-anzianita').textContent = r.hasData ? anzStr : '0 anni';

    $('#r-tfr-lordo').textContent = fmt(r.tfrLordo);
    $('#r-anticipi').textContent = '−' + fmt(r.anticipi);

    if (r.dest === 'fondo') {
      $('#r-reddito-rif').textContent = 'Non applicabile (Fondo pensione)';
      $('#r-imposta-label').textContent = 'Ritenuta agevolata Fondo Pensione';
      $('#out-aliquota-badge').textContent = r.hasData
        ? `Aliquota agevolata fondo: ${fmtPct(r.aliquotaEffettiva * 100)}`
        : 'Aliquota media applicata: —';
    } else {
      $('#r-reddito-rif').textContent = fmt(r.redditoRif);
      $('#r-imposta-label').textContent = 'Trattenuta IRPEF (tassazione separata)';
      $('#out-aliquota-badge').textContent = r.hasData
        ? `Aliquota media IRPEF: ${fmtPct(r.aliquotaEffettiva * 100)}`
        : 'Aliquota media applicata: —';
    }

    $('#r-imposta').textContent = '−' + fmt(r.imposta);
    $('#r-netto-finale').textContent = fmt(r.tfrNetto);
  }

  /* ---------- Inizializzazione ---------- */
  function init() {
    let syncing = false;

    // Sincronizzazione automatica RAL annua <-> Retribuzione mensile
    $('#tfr-ral').addEventListener('input', (e) => {
      if (syncing) return;
      syncing = true;
      const v = parseNum(e.target.value);
      if (v > 0) {
        $('#tfr-mensile').value = Math.round(v / 13).toLocaleString('it-IT');
      } else {
        $('#tfr-mensile').value = '';
      }
      syncing = false;
      render();
    });

    $('#tfr-mensile').addEventListener('input', (e) => {
      if (syncing) return;
      syncing = true;
      const v = parseNum(e.target.value);
      if (v > 0) {
        $('#tfr-ral').value = Math.round(v * 13).toLocaleString('it-IT');
      } else {
        $('#tfr-ral').value = '';
      }
      syncing = false;
      render();
    });

    // Tutti gli altri input aggiornano in tempo reale
    ['#tfr-anni', '#tfr-mesi', '#tfr-dest', '#tfr-anticipi'].forEach((sel) => {
      const el = $(sel);
      if (el) {
        el.addEventListener('input', render);
        el.addEventListener('change', render);
      }
    });

    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
