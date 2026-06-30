import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

const grab = (md, lang) => {
  const re = new RegExp('```' + lang + '\\n([\\s\\S]*?)\\n```');
  const m = md.match(re);
  if (!m) throw new Error('Bloco "' + lang + '" não encontrado');
  return m[1];
};

const staticMd  = readFileSync(join(here, 'mapa-rede.businesstext.md'), 'utf8');
const dynamicMd = readFileSync(join(here, 'mapa-rede-dinamico.businesstext.md'), 'utf8');

// HTML é compartilhado: vem sempre da versão estática (fonte única).
// O Business Text sanitiza <style> inline, então extraímos o CSS para aplicá-lo
// via campo `styles` do plugin E via injeção por JS (NM_BASE_CSS) — dois caminhos.
const rawHtml = grab(staticMd, 'html');
const cssMatch = rawHtml.match(/<style>([\s\S]*?)<\/style>/);
const css = cssMatch ? cssMatch[1].trim() : '';
const content = rawHtml.replace(/<style>[\s\S]*?<\/style>\s*/, '');

function dashboard({ uid, title, afterRender }) {
  const afterRenderWithCss = 'const NM_BASE_CSS = ' + JSON.stringify(css) + ';\n' + afterRender;
  const panel = {
    id: 1,
    type: 'marcusolsson-dynamictext-panel',
    title,
    gridPos: { h: 26, w: 24, x: 0, y: 0 },
    pluginVersion: '5.5.0',
    options: {
      content,
      defaultContent: content,
      editor: { format: 'auto', language: 'html' },
      editors: ['afterRender'],
      helpers: '',
      afterRender: afterRenderWithCss,
      renderMode: 'allRows',
      styles: css,
      externalStyles: [],
      externalScripts: [],
      wrap: true,
      contentPartials: [],
      defaultParameters: [],
    },
  };
  return {
    annotations: { list: [] },
    editable: true,
    fiscalYearStartMonth: 0,
    graphTooltip: 0,
    links: [],
    panels: [panel],
    schemaVersion: 39,
    tags: ['rede', 'topologia', 'lognet'],
    templating: { list: [] },
    time: { from: 'now-6h', to: 'now' },
    timepicker: {},
    timezone: 'browser',
    title,
    uid,
    version: 1,
    weekStart: '',
  };
}

const targets = [
  {
    out: 'mapa-rede.json',
    dash: dashboard({
      uid: 'mapa-rede-lognet',
      title: 'Mapa de Rede LOGNET',
      afterRender: grab(staticMd, 'javascript'),
    }),
  },
  {
    out: 'mapa-rede-dinamico.json',
    dash: dashboard({
      uid: 'mapa-rede-lognet-dyn',
      title: 'Mapa de Rede LOGNET (Zabbix)',
      afterRender: grab(dynamicMd, 'javascript'),
    }),
  },
];

for (const t of targets) {
  const file = join(here, t.out);
  writeFileSync(file, JSON.stringify(t.dash, null, 2), 'utf8');
  console.log('OK ->', t.out, '(' + JSON.stringify(t.dash).length + ' bytes)');
}
