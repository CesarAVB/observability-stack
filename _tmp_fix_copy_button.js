const fs = require('fs');

const path = 'Grafana/dashboards/syslog-switches.json';
const dashboard = JSON.parse(fs.readFileSync(path, 'utf8'));
const panel = Object.values(dashboard.elements || {}).find((element) => element?.spec?.id === 5);

if (!panel) {
  throw new Error('Panel 5 not found');
}

const options = panel.spec.vizConfig.spec.options;
let render = options.onRender;

if (!render.includes('var COPY_ICON=')) {
  render = render.replace(
    'var CSV_ICON="<svg viewBox=',
    'var COPY_ICON="<svg viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'2.1\' stroke-linecap=\'round\' stroke-linejoin=\'round\'><rect x=\'9\' y=\'9\' width=\'13\' height=\'13\' rx=\'2\'/><path d=\'M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1\'/></svg>";\nvar CSV_ICON="<svg viewBox='
  );
}

render = render.replace(
  'pageItems.forEach(function(r){',
  'pageItems.forEach(function(r,rowIdx){'
);

render = render.replace(
  '<button class=\\\'copy-log-btn\\\' type=\\\'button\\\' title=\\\'Copiar mensagem\\\' data-copy=\\\'"+escapeHtml(r.mensagem)+"\\\'>"+CSV_ICON+"</button>',
  '<button class=\\\'copy-log-btn\\\' type=\\\'button\\\' title=\\\'Copiar mensagem\\\' data-copy-idx=\\\'"+rowIdx+"\\\'>"+COPY_ICON+"</button>'
);

render = render.replace(
  "var copyButtons=rightContainer.querySelectorAll('.copy-log-btn');\nfor(var ci=0;ci<copyButtons.length;ci++){\n(function(btn){btn.onclick=function(){var text=btn.getAttribute('data-copy')||'';if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(text);}btn.classList.add('copied');setTimeout(function(){btn.classList.remove('copied');},900);};})(copyButtons[ci]);\n}",
  "var copyButtons=rightContainer.querySelectorAll('.copy-log-btn');\nfor(var ci=0;ci<copyButtons.length;ci++){\n(function(btn){btn.onclick=function(){var idx=Number(btn.getAttribute('data-copy-idx'));var row=pageItems[idx];var text=row?row.mensagem:'';if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(text);}btn.classList.add('copied');setTimeout(function(){btn.classList.remove('copied');},900);};})(copyButtons[ci]);\n}"
);

options.onRender = render;
fs.writeFileSync(path, JSON.stringify(dashboard, null, 2) + '\n');
console.log('Copy button made safer.');
