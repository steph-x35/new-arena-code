/* ============ Generatore Curriculum Vitae — app.js ============ */
(() => {
  'use strict';

  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));

  const DRAFT_KEY = 'cv_draft_v1';

  let currentPhotoData = null;
  let currentColor = '#1d4ed8';
  let currentTemplate = 'modern';

  /* ---------- Helpers ---------- */
  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function showToast(msg) {
    const t = $('#toast');
    if (!t) return;
    t.textContent = msg;
    t.classList.add('show');
    setTimeout(() => t.classList.remove('show'), 2600);
  }

  /* ---------- Dynamic Repeaters ---------- */
  function addExperience(data = {}) {
    const container = $('#exp-container');
    const div = document.createElement('div');
    div.className = 'repeater-item';
    div.innerHTML = `
      <button type="button" class="repeater-del" title="Rimuovi voce">✕</button>
      <div class="grid2">
        <label>Posizione / Ruolo
          <input type="text" class="exp-role" placeholder="Es. Responsabile Commerciale" value="${escapeHtml(data.role || '')}" />
        </label>
        <label>Azienda / Datore di lavoro
          <input type="text" class="exp-company" placeholder="Es. Rossi & Co. Srl" value="${escapeHtml(data.company || '')}" />
        </label>
      </div>
      <div class="grid2">
        <label>Periodo
          <input type="text" class="exp-period" placeholder="Es. 2021 – Presente" value="${escapeHtml(data.period || '')}" />
        </label>
        <label>Città
          <input type="text" class="exp-city" placeholder="Es. Milano (MI)" value="${escapeHtml(data.city || '')}" />
        </label>
      </div>
      <label style="margin-top:8px;">Descrizione e mansioni principali
        <textarea rows="2" class="exp-desc" placeholder="Descrivi brevemente i compiti svolti, progetti gestiti o risultati ottenuti...">${escapeHtml(data.desc || '')}</textarea>
      </label>
    `;
    div.querySelector('.repeater-del').addEventListener('click', () => {
      div.remove();
      render();
    });
    container.appendChild(div);
  }

  function addEducation(data = {}) {
    const container = $('#edu-container');
    const div = document.createElement('div');
    div.className = 'repeater-item';
    div.innerHTML = `
      <button type="button" class="repeater-del" title="Rimuovi voce">✕</button>
      <div class="grid2">
        <label>Titolo di studio / Corso
          <input type="text" class="edu-degree" placeholder="Es. Laurea in Economia Aziendale" value="${escapeHtml(data.degree || '')}" />
        </label>
        <label>Istituto / Università
          <input type="text" class="edu-school" placeholder="Es. Università degli Studi di Verona" value="${escapeHtml(data.school || '')}" />
        </label>
      </div>
      <div class="grid2">
        <label>Periodo / Anno conseguimento
          <input type="text" class="edu-period" placeholder="Es. 2017 – 2021" value="${escapeHtml(data.period || '')}" />
        </label>
        <label>Voto / Dettagli (facoltativo)
          <input type="text" class="edu-details" placeholder="Es. 110/110 con lode" value="${escapeHtml(data.details || '')}" />
        </label>
      </div>
    `;
    div.querySelector('.repeater-del').addEventListener('click', () => {
      div.remove();
      render();
    });
    container.appendChild(div);
  }

  function addLanguage(data = {}) {
    const container = $('#lang-container');
    const div = document.createElement('div');
    div.className = 'repeater-item';
    div.innerHTML = `
      <button type="button" class="repeater-del" title="Rimuovi voce">✕</button>
      <div class="grid2">
        <label>Lingua
          <input type="text" class="lang-name" placeholder="Es. Inglese" value="${escapeHtml(data.name || '')}" />
        </label>
        <label>Livello
          <select class="lang-level">
            <option value="Madrelingua" ${data.level === 'Madrelingua' ? 'selected' : ''}>Madrelingua</option>
            <option value="C2 Avanzato" ${data.level === 'C2 Avanzato' ? 'selected' : ''}>C2 — Avanzato / Bilingue</option>
            <option value="C1 Avanzato" ${data.level === 'C1 Avanzato' ? 'selected' : ''}>C1 — Avanzato</option>
            <option value="B2 Intermedio" ${data.level === 'B2 Intermedio' ? 'selected' : ''}>B2 — Intermedio superiore</option>
            <option value="B1 Intermedio" ${data.level === 'B1 Intermedio' ? 'selected' : ''}>B1 — Intermedio</option>
            <option value="A2 Elementare" ${data.level === 'A2 Elementare' ? 'selected' : ''}>A2 — Base</option>
            <option value="A1 Base" ${data.level === 'A1 Base' ? 'selected' : ''}>A1 — Principiante</option>
          </select>
        </label>
      </div>
    `;
    div.querySelector('.repeater-del').addEventListener('click', () => {
      div.remove();
      render();
    });
    container.appendChild(div);
  }

  /* ---------- Raccogli Dati Modulo ---------- */
  function getFormData() {
    const name = $('#cv-name').value.trim();
    const role = $('#cv-role').value.trim();
    const email = $('#cv-email').value.trim();
    const phone = $('#cv-phone').value.trim();
    const city = $('#cv-city').value.trim();
    const link = $('#cv-link').value.trim();
    const summary = $('#cv-summary').value.trim();
    const skillsRaw = $('#cv-skills').value.trim();
    const privacy = $('#cv-privacy-check').checked;

    const experiences = $$('#exp-container .repeater-item').map((el) => ({
      role: $('.exp-role', el).value.trim(),
      company: $('.exp-company', el).value.trim(),
      period: $('.exp-period', el).value.trim(),
      city: $('.exp-city', el).value.trim(),
      desc: $('.exp-desc', el).value.trim(),
    })).filter((e) => e.role || e.company || e.desc);

    const education = $$('#edu-container .repeater-item').map((el) => ({
      degree: $('.edu-degree', el).value.trim(),
      school: $('.edu-school', el).value.trim(),
      period: $('.edu-period', el).value.trim(),
      details: $('.edu-details', el).value.trim(),
    })).filter((e) => e.degree || e.school);

    const languages = $$('#lang-container .repeater-item').map((el) => ({
      name: $('.lang-name', el).value.trim(),
      level: $('.lang-level', el).value,
    })).filter((l) => l.name);

    const skills = skillsRaw
      ? skillsRaw.split(',').map((s) => s.trim()).filter(Boolean)
      : [];

    return {
      name, role, email, phone, city, link,
      summary, skills, privacy,
      experiences, education, languages,
      photo: currentPhotoData,
      color: currentColor,
      template: currentTemplate,
    };
  }

  /* ---------- Render Sheet ---------- */
  function render() {
    const d = getFormData();
    const sheet = $('#cv-sheet');
    sheet.style.setProperty('--cv-accent', d.color);

    // Controlla se il CV è completamente vuoto
    const hasContent = d.name || d.role || d.email || d.phone || d.summary ||
      d.experiences.length > 0 || d.education.length > 0 || d.skills.length > 0;

    if (!hasContent) {
      sheet.className = 'sheet-cv';
      sheet.innerHTML = `
        <div class="empty-cv-placeholder">
          <span>✍️</span>
          <p><strong>Il tuo Curriculum è vuoto</strong><br>Compila i campi a sinistra: il documento professionale si comporrà qui in tempo reale.</p>
        </div>
      `;
      return;
    }

    if (d.template === 'classic') {
      renderClassic(sheet, d);
    } else {
      renderModern(sheet, d);
    }
  }

  /* ---------- Template 1: Moderno a 2 Colonne ---------- */
  function renderModern(sheet, d) {
    sheet.className = 'sheet-cv cv-modern';

    // Sidebar
    let sidebarHtml = '<aside class="cv-sidebar">';

    if (d.photo) {
      sidebarHtml += `
        <div class="cv-photo-box">
          <img src="${escapeHtml(d.photo)}" alt="Foto profilo" />
        </div>
      `;
    }

    // Contatti
    const contacts = [];
    if (d.email) contacts.push(`<div class="cv-contact-item"><span class="icon">✉️</span><span>${escapeHtml(d.email)}</span></div>`);
    if (d.phone) contacts.push(`<div class="cv-contact-item"><span class="icon">📞</span><span>${escapeHtml(d.phone)}</span></div>`);
    if (d.city) contacts.push(`<div class="cv-contact-item"><span class="icon">📍</span><span>${escapeHtml(d.city)}</span></div>`);
    if (d.link) contacts.push(`<div class="cv-contact-item"><span class="icon">🔗</span><span>${escapeHtml(d.link)}</span></div>`);

    if (contacts.length) {
      sidebarHtml += `
        <div>
          <div class="cv-section-title">Contatti</div>
          ${contacts.join('')}
        </div>
      `;
    }

    // Competenze
    if (d.skills.length) {
      sidebarHtml += `
        <div>
          <div class="cv-section-title">Competenze</div>
          <div class="cv-skills-list">
            ${d.skills.map((s) => `<span class="cv-skill-pill">${escapeHtml(s)}</span>`).join('')}
          </div>
        </div>
      `;
    }

    // Lingue
    if (d.languages.length) {
      sidebarHtml += `
        <div>
          <div class="cv-section-title">Lingue</div>
          ${d.languages.map((l) => `
            <div class="cv-lang-row">
              <strong>${escapeHtml(l.name)}</strong>
              <span class="cv-lang-level">${escapeHtml(l.level)}</span>
            </div>
          `).join('')}
        </div>
      `;
    }

    sidebarHtml += '</aside>';

    // Colonna principale
    let mainHtml = '<section class="cv-maincol">';

    // Intestazione
    mainHtml += `
      <div>
        <div class="cv-name">${escapeHtml(d.name || 'Nome Cognome')}</div>
        ${d.role ? `<div class="cv-role">${escapeHtml(d.role)}</div>` : ''}
      </div>
    `;

    // Profilo
    if (d.summary) {
      mainHtml += `
        <div>
          <div class="cv-section-title">Profilo Professionale</div>
          <div class="cv-entry-desc">${escapeHtml(d.summary)}</div>
        </div>
      `;
    }

    // Esperienze
    if (d.experiences.length) {
      mainHtml += `
        <div>
          <div class="cv-section-title">Esperienze Lavorative</div>
          ${d.experiences.map((e) => `
            <article class="cv-entry">
              <div class="cv-entry-head">
                <span class="cv-entry-title">${escapeHtml(e.role)}</span>
                <span class="cv-entry-period">${escapeHtml(e.period)}</span>
              </div>
              <div class="cv-entry-sub">${escapeHtml(e.company)}${e.city ? ' · ' + escapeHtml(e.city) : ''}</div>
              ${e.desc ? `<div class="cv-entry-desc">${escapeHtml(e.desc)}</div>` : ''}
            </article>
          `).join('')}
        </div>
      `;
    }

    // Istruzione
    if (d.education.length) {
      mainHtml += `
        <div>
          <div class="cv-section-title">Istruzione e Formazione</div>
          ${d.education.map((e) => `
            <article class="cv-entry">
              <div class="cv-entry-head">
                <span class="cv-entry-title">${escapeHtml(e.degree)}</span>
                <span class="cv-entry-period">${escapeHtml(e.period)}</span>
              </div>
              <div class="cv-entry-sub">${escapeHtml(e.school)}${e.details ? ' — ' + escapeHtml(e.details) : ''}</div>
            </article>
          `).join('')}
        </div>
      `;
    }

    // Privacy GDPR
    if (d.privacy) {
      mainHtml += `
        <div class="cv-privacy-text">
          Autorizzo il trattamento dei miei dati personali presenti nel curriculum vitae ai sensi del D.Lgs. 196/2003 e del Regolamento UE 2016/679 (GDPR).
        </div>
      `;
    }

    mainHtml += '</section>';

    sheet.innerHTML = sidebarHtml + mainHtml;
  }

  /* ---------- Template 2: Classico ATS ---------- */
  function renderClassic(sheet, d) {
    sheet.className = 'sheet-cv cv-classic';

    let html = '';

    // Intestazione classica monocolonna
    const contactsList = [];
    if (d.email) contactsList.push(`✉️ ${escapeHtml(d.email)}`);
    if (d.phone) contactsList.push(`📞 ${escapeHtml(d.phone)}`);
    if (d.city) contactsList.push(`📍 ${escapeHtml(d.city)}`);
    if (d.link) contactsList.push(`🔗 ${escapeHtml(d.link)}`);

    html += `
      <header class="cv-head-classic">
        <div>
          <div class="cv-name">${escapeHtml(d.name || 'Nome Cognome')}</div>
          ${d.role ? `<div class="cv-role">${escapeHtml(d.role)}</div>` : ''}
          ${contactsList.length ? `<div class="cv-contact-row">${contactsList.map((c) => `<span>${c}</span>`).join(' · ')}</div>` : ''}
        </div>
        ${d.photo ? `<div class="cv-photo-box" style="margin:0;"><img src="${escapeHtml(d.photo)}" alt="Foto profilo" style="width:28mm;height:28mm;" /></div>` : ''}
      </header>
    `;

    // Profilo
    if (d.summary) {
      html += `
        <div>
          <div class="cv-section-title">Profilo Professionale</div>
          <div class="cv-entry-desc">${escapeHtml(d.summary)}</div>
        </div>
      `;
    }

    // Esperienze
    if (d.experiences.length) {
      html += `
        <div>
          <div class="cv-section-title">Esperienze Lavorative</div>
          ${d.experiences.map((e) => `
            <article class="cv-entry">
              <div class="cv-entry-head">
                <span class="cv-entry-title">${escapeHtml(e.role)} — ${escapeHtml(e.company)}</span>
                <span class="cv-entry-period">${escapeHtml(e.period)}${e.city ? ' · ' + escapeHtml(e.city) : ''}</span>
              </div>
              ${e.desc ? `<div class="cv-entry-desc">${escapeHtml(e.desc)}</div>` : ''}
            </article>
          `).join('')}
        </div>
      `;
    }

    // Istruzione
    if (d.education.length) {
      html += `
        <div>
          <div class="cv-section-title">Istruzione e Formazione</div>
          ${d.education.map((e) => `
            <article class="cv-entry">
              <div class="cv-entry-head">
                <span class="cv-entry-title">${escapeHtml(e.degree)}</span>
                <span class="cv-entry-period">${escapeHtml(e.period)}</span>
              </div>
              <div class="cv-entry-sub">${escapeHtml(e.school)}${e.details ? ' — ' + escapeHtml(e.details) : ''}</div>
            </article>
          `).join('')}
        </div>
      `;
    }

    // Competenze e Lingue
    if (d.skills.length || d.languages.length) {
      html += `
        <div>
          <div class="cv-section-title">Competenze e Lingue</div>
          ${d.skills.length ? `
            <div style="margin-bottom:8px;">
              <strong style="font-size:10px; color:#475569;">Competenze chiave: </strong>
              <span style="font-size:10.5px; color:#1e293b;">${d.skills.map(escapeHtml).join(' · ')}</span>
            </div>
          ` : ''}
          ${d.languages.length ? `
            <div>
              <strong style="font-size:10px; color:#475569;">Lingue: </strong>
              <span style="font-size:10.5px; color:#1e293b;">${d.languages.map((l) => `${escapeHtml(l.name)} (${escapeHtml(l.level)})`).join(' · ')}</span>
            </div>
          ` : ''}
        </div>
      `;
    }

    // Privacy GDPR
    if (d.privacy) {
      html += `
        <div class="cv-privacy-text" style="margin-top:auto;">
          Autorizzo il trattamento dei miei dati personali presenti nel curriculum vitae ai sensi del D.Lgs. 196/2003 e del Regolamento UE 2016/679 (GDPR).
        </div>
      `;
    }

    sheet.innerHTML = html;
  }

  /* ---------- Salva / Carica / Cancella ---------- */
  function saveDraft() {
    const data = getFormData();
    try {
      localStorage.setItem(DRAFT_KEY, JSON.stringify(data));
      showToast('Bozza salvata nel browser!');
    } catch (e) {
      console.warn('Errore salvataggio:', e);
      showToast('Impossibile salvare la bozza (memoria piena)');
    }
  }

  function loadDraft() {
    try {
      const raw = localStorage.getItem(DRAFT_KEY);
      if (!raw) return false;
      const d = JSON.parse(raw);
      if (!d) return false;

      $('#cv-name').value = d.name || '';
      $('#cv-role').value = d.role || '';
      $('#cv-email').value = d.email || '';
      $('#cv-phone').value = d.phone || '';
      $('#cv-city').value = d.city || '';
      $('#cv-link').value = d.link || '';
      $('#cv-summary').value = d.summary || '';
      $('#cv-skills').value = (d.skills || []).join(', ');
      $('#cv-privacy-check').checked = d.privacy !== false;

      if (d.template) {
        currentTemplate = d.template;
        $('#cv-template-select').value = d.template;
      }
      if (d.color) {
        currentColor = d.color;
        $$('.color-dot').forEach((btn) => {
          btn.classList.toggle('active', btn.dataset.color === d.color);
        });
      }

      if (d.photo) {
        currentPhotoData = d.photo;
        $('#photo-thumb').innerHTML = `<img src="${d.photo}" alt="Anteprima foto" />`;
        $('#btn-remove-photo').style.display = 'inline-block';
      }

      $('#exp-container').innerHTML = '';
      (d.experiences || []).forEach(addExperience);

      $('#edu-container').innerHTML = '';
      (d.education || []).forEach(addEducation);

      $('#lang-container').innerHTML = '';
      (d.languages || []).forEach(addLanguage);

      return true;
    } catch (e) {
      console.warn('Errore lettura bozza:', e);
      return false;
    }
  }

  function clearAll() {
    if (!confirm('Vuoi davvero cancellare tutti i dati inseriti nel CV?')) return;
    localStorage.removeItem(DRAFT_KEY);
    $('#cv-form').reset();
    $('#exp-container').innerHTML = '';
    $('#edu-container').innerHTML = '';
    $('#lang-container').innerHTML = '';
    currentPhotoData = null;
    $('#photo-thumb').innerHTML = '<span>👤</span>';
    $('#btn-remove-photo').style.display = 'none';
    render();
    showToast('Tutti i campi sono stati azzerati.');
  }

  /* ---------- Inizializzazione ---------- */
  function init() {
    // Foto profilo upload
    const photoInput = $('#cv-photo-input');
    photoInput.addEventListener('change', (e) => {
      const file = e.target.files && e.target.files[0];
      if (!file) return;
      if (!file.type.startsWith('image/')) {
        alert('Seleziona un file immagine valido (JPG, PNG, WebP).');
        return;
      }
      const reader = new FileReader();
      reader.onload = (ev) => {
        currentPhotoData = ev.target.result;
        $('#photo-thumb').innerHTML = `<img src="${currentPhotoData}" alt="Foto" />`;
        $('#btn-remove-photo').style.display = 'inline-block';
        render();
      };
      reader.readAsDataURL(file);
    });

    $('#btn-remove-photo').addEventListener('click', () => {
      currentPhotoData = null;
      photoInput.value = '';
      $('#photo-thumb').innerHTML = '<span>👤</span>';
      $('#btn-remove-photo').style.display = 'none';
      render();
    });

    // Selettore Template
    $('#cv-template-select').addEventListener('change', (e) => {
      currentTemplate = e.target.value;
      render();
    });

    // Color picker
    $$('.color-dot').forEach((btn) => {
      btn.addEventListener('click', () => {
        $$('.color-dot').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        currentColor = btn.dataset.color;
        render();
      });
    });

    // Pulsanti aggiungi
    $('#btn-add-exp').addEventListener('click', () => {
      addExperience();
      render();
    });
    $('#btn-add-edu').addEventListener('click', () => {
      addEducation();
      render();
    });
    $('#btn-add-lang').addEventListener('click', () => {
      addLanguage();
      render();
    });

    // Azioni
    $('#btn-save').addEventListener('click', saveDraft);
    $('#btn-clear').addEventListener('click', clearAll);

    const doPrint = () => {
      window.print();
    };
    $('#btn-print').addEventListener('click', doPrint);
    $('#btn-print-top').addEventListener('click', doPrint);

    // Event delegation per aggiornare in tempo reale la preview
    const form = $('#cv-form');
    form.addEventListener('input', render);
    form.addEventListener('change', render);

    // Carica eventuale bozza esistente oppure parte VUOTO come richiesto
    const hasDraft = loadDraft();
    if (!hasDraft) {
      // Inizia completamente vuoto, nessun dato demo precompilato
    }
    render();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
