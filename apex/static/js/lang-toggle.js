/* =============================================================================
   KrishiMitra :: Hindi/English language toggle
   Upload as a static application file (#APP_IMAGES#lang-toggle.js).
   Applies a body class (km-lang-hi / km-lang-en) that the CSS uses to show the
   correct [lang] spans, and persists the choice in APEX session state via an
   Application Item P_LANG (set through an Ajax callback or apex.server.process).
   ========================================================================== */
(function (w, d) {
  'use strict';

  var KEY = 'km_lang';

  function apply(lang) {
    var body = d.body;
    body.classList.remove('km-lang-hi', 'km-lang-en');
    body.classList.add(lang === 'en' ? 'km-lang-en' : 'km-lang-hi');
  }

  function persist(lang) {
    try { w.localStorage.setItem(KEY, lang); } catch (e) { /* ignore */ }
    // Persist into APEX session state so server-side rendering honours it.
    if (w.apex && apex.server && apex.items && apex.item('P_LANG').node) {
      apex.item('P_LANG').setValue(lang);
      apex.server.process('SET_LANG', { x01: lang }, { dataType: 'text' });
    }
  }

  w.krishimitra = w.krishimitra || {};
  w.krishimitra.setLang = function (lang) {
    apply(lang);
    persist(lang);
  };

  d.addEventListener('DOMContentLoaded', function () {
    var stored = 'hi';
    try { stored = w.localStorage.getItem(KEY) || 'hi'; } catch (e) { /* ignore */ }
    apply(stored);

    var toggle = d.getElementById('km-lang-toggle');
    if (toggle) {
      toggle.addEventListener('click', function () {
        var current = d.body.classList.contains('km-lang-en') ? 'en' : 'hi';
        w.krishimitra.setLang(current === 'en' ? 'hi' : 'en');
      });
    }
  });
})(window, document);
