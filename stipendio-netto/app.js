/* ============ Calcolatore Stipendio Netto — app.js ============ */
(() => {
  'use strict';

  const $ = (s) => document.querySelector(s);

  // Parametri 2026 (indicativi, editabili dall'utente)
  const IRPEF_BRACKETS = [
    { upTo: 28000, rate: 0.23 },
    { upTo: 50000, rate: 0.35 },
    { upTo: Infinity, rate: 0.43 },
  ];

  // Aliquote base addizionale regionale 2026 (modificabili)
  const REGIONAL_RATES = {
    abruzzo: 1.73,
    basilicata: 1.23,
    calabria: 2.03,
    campania: 2.03,
    emilia: 1.33,
    friuli: 1.23,
    lazio: 1.73,
    liguria: 1.23,
    lombardia: 1.23,
    marche: 1.23,
    molise: 1.73,
    piemonte: 1.62,
    puglia: 1.33,
    sardegna: 1.23,
    sicilia: 1.23,
    toscana: 1.42,
    trentino: 1.23,
    umbria: 1.73,
    valle: 1.23,
    veneto: 1.23,
  };
  const REGION_NAMES = {
    abruzzo: 'Abruzzo', basilicata: 'Basilicata', calabria: 'Calabria',
    campania: 'Campania', emilia: 'Emilia-Romagna', friuli: 'Friuli-Venezia Giulia',
    lazio: 'Lazio', liguria: 'Liguria', lombardia: 'Lombardia', marche: 'Marche',
    molise: 'Molise', piemonte: 'Piemonte', puglia: 'Puglia', sardegna: 'Sardegna',
    sicilia: 'Sicilia', toscana: 'Toscana', trentino: 'Trentino-Alto Adige',
    umbria: 'Umbria', valle: "Valle d'Aosta", veneto: 'Veneto',
  };

  const FAM = { coniuge: 1220, sotto3: 950, f3_10: 840, f10_18: 695, oltre18: 540 };

  /* ---------- helpers ---------- */
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
    new Intl.NumberFormat('it-IT', { maximumFractionDigits: 2 }).format(n) + '%';

  function irpefGross(reddito) {
    let tax = 0, prev = 0;
    for (const b of IRPEF_BRACKETS) {
      const slice = Math.min(reddito, b.upTo) - prev;
      if (slice > 0) tax += slice * b.rate;
      prev = b.upTo;
      if (reddito <= b.upTo) break;
    }
    return tax;
  }

  function detrazioneLavoro(imponibile) {
    if (imponibile <= 0) return 0;
    if (imponibile <= 15000) return 1955; // comunque limitata all'IRPEF dovuta
    if (imponibile <= 28000) return 1955 * (28000 - imponibile) / 13000;
    return 0;
  }

  /* ---------- calcolo ---------- */
  function compute() {
    const lordo = parseNum($('#lordo').value);
    const mensilita = parseInt($('#mensilita').value, 10) || 13;
    const inpsRate = parseNum($('#inps').value) / 100;
    const regRate = parseNum($('#reg-rate').value) / 100;
    const comRate = parseNum($('#com-rate').value) / 100;
    const comExempt = parseNum($('#com-exempt').value);
    const comune = $('#comune').value.trim();
    const regione = $('#regione').value;

    const inps = lordo * inpsRate;
    const imponibile = Math.max(0, lordo - inps);

    const irpefBrutta = irpefGross(imponibile);

    // detrazioni
    let detLavoro = 0;
    if ($('#det-auto').checked) {
      detLavoro = detrazioneLavoro(imponibile);
    } else {
      const manual = $('#det-manual').value.trim();
      detLavoro = manual ? parseNum(manual) : 0;
    }
    const detFamiglia =
      parseInt($('#coniuge').value, 10) * FAM.coniuge +
      parseInt($('#figli-0-3').value, 10) * FAM.sotto3 +
      parseInt($('#figli-3-10').value, 10) * FAM.f3_10 +
      parseInt($('#figli-10-18').value, 10) * FAM.f10_18 +
      parseInt($('#figli-18').value, 10) * FAM.oltre18;

    const detrazioni = Math.min(irpefBrutta, Math.max(0, detLavoro + detFamiglia));
    const irpefNetta = Math.max(0, irpefBrutta - detrazioni);

    const addRegionale = imponibile * regRate;
    const addComunale = Math.max(0, imponibile - comExempt) * comRate;

    const nettoAnno = Math.max(0, lordo - inps - irpefNetta - addRegionale - addComunale);
    const nettoMese = nettoAnno / mensilita;
    const prelievo = lordo > 0 ? ((lordo - nettoAnno) / lordo) * 100 : 0;

    return { lordo, mensilita, inpsRate, inps, imponibile, irpefBrutta, detrazioni, irpefNetta, addRegionale, addComunale, nettoAnno, nettoMese, prelievo, regRate, comRate, comExempt, comune, regione };
  }

  /* ---------- render ---------- */
  function render() {
    const r = compute();
    const regName = REGION_NAMES[r.regione] || '';

    $('#out-monthly').textContent = fmt(r.nettoMese);
    $('#out-sub').textContent = `Netto annuale: ${fmt(r.nettoAnno)}`;

    $('#r-lordo').textContent = fmt(r.lordo);
    $('#r-inps-label').textContent = `INPS dipendenti (${fmtPct(r.inpsRate * 100)})`;
    $('#r-inps').textContent = '−' + fmt(r.inps);
    $('#r-imponibile').textContent = fmt(r.imponibile);
    $('#r-irpef').textContent = '−' + fmt(r.irpefBrutta);

    const nFigli =
      parseInt($('#figli-0-3').value, 10) + parseInt($('#figli-3-10').value, 10) +
      parseInt($('#figli-10-18').value, 10) + parseInt($('#figli-18').value, 10);
    $('#r-det-label').textContent =
      `Detrazioni (lavoro${nFigli || parseInt($('#coniuge').value, 10) ? ' + famiglia' : ''})`;
    $('#r-det').textContent = '−' + fmt(r.detrazioni);
    $('#r-irpef-netta').textContent = '−' + fmt(r.irpefNetta);

    $('#r-reg-label').textContent = `Addizionale regionale — ${regName} (${fmtPct(r.regRate * 100)})`;
    $('#r-reg').textContent = '−' + fmt(r.addRegionale);

    const comLabel = r.comune ? `Addizionale comunale — ${r.comune}` : 'Addizionale comunale';
    $('#r-com-label').textContent = `${comLabel} (${fmtPct(r.comRate * 100)})`;
    $('#r-com').textContent = '−' + fmt(r.addComunale);

    $('#r-netto-anno').textContent = fmt(r.nettoAnno);
    $('#r-netto-mese-label').textContent = `Netto mensile (÷ ${r.mensilita})`;
    $('#r-netto-mese').textContent = fmt(r.nettoMese);

    $('#out-rate').textContent =
      r.lordo > 0 ? `Prelievo fiscale effettivo: ${fmtPct(r.prelievo)}` : 'Prelievo fiscale effettivo: —';
  }

  /* ---------- init ---------- */
  function init() {
    // selezione regione → preimposta aliquota
    $('#regione').addEventListener('change', (e) => {
      const rate = REGIONAL_RATES[e.target.value];
      if (rate != null) $('#reg-rate').value = String(rate).replace('.', ',');
      render();
    });

    // toggle detrazione auto/manuale
    $('#det-auto').addEventListener('change', (e) => {
      $('#det-manual').disabled = e.target.checked;
      if (e.target.checked) $('#det-manual').value = '';
      render();
    });

    // tutti gli input aggiornano in tempo reale
    document
      .querySelectorAll('.calc-form input, .calc-form select')
      .forEach((el) => {
        el.addEventListener('input', render);
        el.addEventListener('change', render);
      });

    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
