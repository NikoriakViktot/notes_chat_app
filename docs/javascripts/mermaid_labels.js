/* Колір тексту на Mermaid-схемах.
   Material малює кожну схему в закритому shadow DOM і додає туди правило
   `.nodeLabel p { color: var(--md-mermaid-label-fg-color) }`. Mermaid 11 кладе текст вузла в <p>,
   тому колір із `classDef … color:#fff` або `style X … color:#fff` до тексту не доходить:
   на темних вузлах текст лишається темним. Додаємо в кожен shadow root правило, за яким <p>
   успадковує колір від вузла. Скрипт має виконатися до рендеру схем (extra_javascript — так). */
(function () {
  var CSS = ".nodeLabel p { color: inherit !important; }";
  var original = Element.prototype.attachShadow;
  if (!original || typeof CSSStyleSheet === "undefined") return;
  Element.prototype.attachShadow = function (init) {
    var root = original.call(this, init);
    try {
      var sheet = new CSSStyleSheet();
      sheet.replaceSync(CSS);
      root.adoptedStyleSheets = root.adoptedStyleSheets.concat(sheet);
    } catch (e) { /* старий браузер — схема лишиться як була */ }
    return root;
  };
})();
