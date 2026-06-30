# Mapa de Rede LOGNET — Painel Business Text (versão estática)

Porte do `modelo.html` para um painel **Business Text** (`marcusolsson-dynamictext-panel`)
dentro do Grafana. Esta versão ainda usa dados **fixos** (mesma topologia do modelo) —
serve para validar o visual dentro do Grafana antes de ligar os dados reais do Zabbix.

## 1. Instalar o plugin

Já adicionado em `Grafana/docker-compose.yml` via `GF_INSTALL_PLUGINS`
(`marcusolsson-dynamictext-panel`). Faça **redeploy da stack do Grafana** no Portainer
para o container baixar o plugin no boot.

Conferir depois em: **Administration → Plugins → Business Text**.

## 2. Importar a dashboard (recomendado)

O arquivo **`mapa-rede.json`** (nesta mesma pasta) já é uma dashboard completa com o painel
Business Text configurado. No Grafana:

**Dashboards → New → Import → Upload JSON file** → selecione `mapa-rede.json`.

Não pede datasource (esta versão é estática). Pronto, o mapa aparece.

### Regerar o JSON

Os blocos **CONTENT** e **JAVASCRIPT** abaixo são a **fonte de verdade**. Se editar o visual,
regere o JSON e reimporte:

```bash
node Grafana/dashboards/_gen-mapa-rede.mjs
```

### Alternativa: criar o painel à mão

Se preferir não importar, crie um painel **Business Text** manualmente, cole o bloco
**CONTENT** em *Panel options → Content* (editor HTML) e o bloco **JAVASCRIPT** em
*JavaScript → After Content Ready*. Dê ao painel altura generosa (~24+ linhas de grid).

> O painel é escopado em `.nm-root` e usa IDs prefixados `nm-` para não colidir com o CSS do Grafana.
> Pan (arrastar fundo), zoom (scroll / botões) e drag dos nós funcionam igual ao modelo.

---

## CONTENT (HTML + CSS)

```html
<div class="nm-root">
<style>
  .nm-root { position: relative; display: flex; width: 100%; height: 100%;
             background: #0f1117; font-family: 'Segoe UI', sans-serif;
             overflow: hidden; user-select: none; color: #e2e8f0; }

  /* Sidebar */
  .nm-root #nm-sidebar { position: relative; width: 240px; flex: 0 0 240px;
             background: rgba(12,14,20,0.98); border-right: 1px solid #2d3748;
             display: flex; flex-direction: column; padding: 16px 14px;
             overflow-y: auto; z-index: 2; }
  .nm-root #nm-title { margin-bottom: 16px; }
  .nm-root #nm-title h1 { font-size: 20px; font-weight: 700; color: #f97316; margin: 0; }
  .nm-root #nm-title p { font-size: 12px; color: #64748b; margin-top: 2px; }

  /* Canvas */
  .nm-root #nm-canvas { position: relative; flex: 1; overflow: hidden;
             cursor: grab; background: #0f1117; }
  .nm-root #nm-canvas.panning { cursor: grabbing; }
  .nm-root #nm-viewport { position: absolute; top: 0; left: 0; width: 100%; height: 100%;
             transform-origin: 0 0; }
  .nm-root svg#nm-links { position: absolute; top: 0; left: 0; width: 100%; height: 100%;
             pointer-events: none; overflow: visible; z-index: 1; }

  /* Nós */
  .nm-root .node { position: absolute; display: flex; flex-direction: column;
             align-items: center; justify-content: center; width: 86px; height: 86px;
             border-radius: 50%; cursor: grab; z-index: 10;
             transform: translate(-50%, -50%); transition: box-shadow 0.2s; border: 3px solid; }
  .nm-root .node:active { cursor: grabbing; }
  .nm-root .node:hover  { box-shadow: 0 0 22px currentColor; }
  .nm-root .node-label { font-size: 15px; font-weight: 700; letter-spacing: 1px; pointer-events: none; }
  .nm-root .node-type { font-size: 9px; opacity: 0.7; margin-top: 2px; pointer-events: none; }

  .nm-root .node.pop { background: #1a1f35; border-color: #4f9cf9; color: #4f9cf9;
             box-shadow: 0 0 12px rgba(79,156,249,0.35); }
  .nm-root .node.pop-ix { background: #1c1a30; border-color: #a78bfa; color: #a78bfa;
             box-shadow: 0 0 16px rgba(167,139,250,0.5); }
  .nm-root .node.pop-core { background: #0a1628; border-color: #60a5fa; border-width: 4px;
             color: #bfdbfe;
             box-shadow: 0 0 0 4px rgba(96,165,250,0.18), 0 0 28px rgba(96,165,250,0.7), 0 0 60px rgba(96,165,250,0.3);
             animation: nm-core-pulse 2.4s ease-in-out infinite; }
  @keyframes nm-core-pulse {
    0%,100% { box-shadow: 0 0 0 4px rgba(96,165,250,0.18), 0 0 28px rgba(96,165,250,0.7), 0 0 60px rgba(96,165,250,0.3); }
    50%     { box-shadow: 0 0 0 7px rgba(96,165,250,0.10), 0 0 42px rgba(96,165,250,0.9), 0 0 80px rgba(96,165,250,0.45); }
  }
  .nm-root .node.pop-core .badge.core { background: #1e40af; color: #bfdbfe;
             border-color: #60a5fa; font-size: 8px; letter-spacing: 1px; }

  /* Painel de peers */
  .nm-root .node.ext-panel { transform: translate(-50%, -50%); border-radius: 10px;
             width: 152px; height: auto; padding: 8px 10px 6px; background: #0d1221;
             border-color: #a78bfa; color: #e2e8f0; flex-direction: column;
             align-items: flex-start; justify-content: flex-start;
             box-shadow: 0 0 14px rgba(167,139,250,0.22); }
  .nm-root .node.ext-panel:hover { box-shadow: 0 0 22px rgba(167,139,250,0.5); }
  .nm-root .panel-title { font-size: 8px; font-weight: 700; letter-spacing: 1.2px;
             text-transform: uppercase; color: #a78bfa; margin-bottom: 5px;
             pointer-events: none; width: 100%; }
  .nm-root .panel-sep { width: 100%; height: 1px; background: #2d3748; margin-bottom: 5px;
             pointer-events: none; }
  .nm-root .panel-peer { display: flex; align-items: center; gap: 5px; margin-bottom: 4px;
             pointer-events: none; width: 100%; }
  .nm-root .peer-name { font-size: 11px; font-weight: 700; color: #e2e8f0; }
  .nm-root .peer-sub  { font-size: 9px; color: #64748b; margin-left: auto; }

  .nm-root .node-badges { display: flex; gap: 3px; margin-top: 4px; pointer-events: none;
             flex-wrap: wrap; justify-content: center; }
  .nm-root .badge { font-size: 7px; font-weight: 700; padding: 1px 4px; border-radius: 3px;
             letter-spacing: 0.5px; pointer-events: none; }
  .nm-root .badge.core { background: #1e3a5f; color: #93c5fd; border: 1px solid #3b82f6; }
  .nm-root .badge.edge { background: #92400e; color: #fef3c7; }

  /* Links */
  .nm-root .link-100g { stroke: #4f9cf9; stroke-width: 3; }
  .nm-root .link-40g  { stroke: #a78bfa; stroke-width: 2.5; }
  .nm-root .link-10g  { stroke: #f97316; stroke-width: 2; stroke-dasharray: 8 4; }
  .nm-root .link-label { fill: #e2e8f0; font-size: 11px; font-weight: 600;
             font-family: 'Segoe UI', sans-serif; }

  /* Legenda */
  .nm-root #nm-legend { color: #e2e8f0; flex: 1; }
  .nm-root #nm-legend-header { display: flex; align-items: center; justify-content: space-between;
             cursor: pointer; padding-bottom: 8px; border-bottom: 1px solid #2d3748; margin-bottom: 10px; }
  .nm-root #nm-legend-header h3 { font-size: 11px; text-transform: uppercase;
             letter-spacing: 1px; color: #94a3b8; margin: 0; }
  .nm-root #nm-legend-toggle { font-size: 13px; color: #94a3b8; }
  .nm-root #nm-legend-body { overflow: hidden; max-height: 2000px; opacity: 1;
             transition: max-height 0.3s ease, opacity 0.25s ease; }
  .nm-root #nm-legend-body.collapsed { max-height: 0; opacity: 0; }
  .nm-root .legend-section { font-size: 9px; font-weight: 700; text-transform: uppercase;
             letter-spacing: 1.4px; color: #475569; background: #161b2a;
             border-left: 2px solid #2d3748; padding: 3px 6px; margin: 10px -4px 6px;
             border-radius: 0 3px 3px 0; }
  .nm-root .legend-item { display: flex; align-items: center; gap: 8px; margin-bottom: 5px;
             font-size: 11px; color: #cbd5e1; }
  .nm-root .legend-line { width: 28px; height: 3px; border-radius: 2px; flex-shrink: 0; }

  /* Info bar + zoom */
  .nm-root #nm-info { position: absolute; top: 12px; left: 50%; transform: translateX(-50%);
             background: rgba(15,17,23,0.85); border: 1px solid #2d3748; border-radius: 8px;
             padding: 6px 16px; color: #64748b; font-size: 11px; z-index: 30;
             pointer-events: none; white-space: nowrap; }
  .nm-root #nm-zoom { position: absolute; bottom: 20px; right: 20px; z-index: 30;
             display: flex; flex-direction: column; gap: 4px; }
  .nm-root #nm-zoom button { width: 34px; height: 34px; background: rgba(15,17,23,0.92);
             border: 1px solid #2d3748; border-radius: 7px; color: #94a3b8; font-size: 18px;
             cursor: pointer; display: flex; align-items: center; justify-content: center;
             transition: background 0.15s, color 0.15s; }
  .nm-root #nm-zoom button:hover { background: #1e2535; color: #e2e8f0; }
</style>

  <div id="nm-sidebar">
    <div id="nm-title"><h1>LOGNET</h1><p>Topologia de Rede</p></div>
    <div id="nm-legend">
      <div id="nm-legend-header"><h3>Legenda</h3><span id="nm-legend-toggle">▲</span></div>
      <div id="nm-legend-body">
        <div class="legend-section">Capacidade</div>
        <div class="legend-item"><div class="legend-line" style="background:#4f9cf9"></div><span>100G - Backbone</span></div>
        <div class="legend-item"><div class="legend-line" style="background:#a78bfa"></div><span>40G - Uplink</span></div>
        <div class="legend-item"><div class="legend-line" style="background:#f97316;border-top:2px dashed #f97316;height:0"></div><span>10G - Acesso</span></div>
        <div class="legend-section">Siglas - POPs</div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#a78bfa">RJ2</span><span>Equinix RJ2</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#a78bfa">UFN</span><span>Ufinet</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#4f9cf9">MCO</span><span>Miguel Couto</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#93c5fd">RNC</span><span>Rancho Novo</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#4f9cf9">STR</span><span>Santa Rita</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#4f9cf9">SUM</span><span>Summer</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#4f9cf9">MAG</span><span>Morro Agudo</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#4f9cf9">NIG</span><span>Nova Iguaçu</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#4f9cf9">ASB</span><span>AN Bezerra</span></div>
        <div class="legend-section">Siglas - Peers</div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#a78bfa">NGT</span><span>NGT Trânsito</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#22c55e">Google</span><span>Google PNI</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#a78bfa">SEA</span><span>Seaborn (Cabo)</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#a78bfa">WIX</span><span>WIX Net</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#a78bfa">OI</span><span>OI (STFC)</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#a78bfa">IX-RJ</span><span>IX Rio de Janeiro</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#22c55e">Globo</span><span>GloboPlay CDN</span></div>
        <div class="legend-item" style="display:grid;grid-template-columns:44px 1fr;gap:4px"><span style="font-weight:700;color:#a78bfa">ITX</span><span>ITX Teleporto</span></div>
      </div>
    </div>
  </div>

  <div id="nm-canvas">
    <div id="nm-viewport"><svg id="nm-links"></svg></div>
    <div id="nm-info">Arraste os nós • scroll = zoom • arraste o fundo = pan</div>
    <div id="nm-zoom">
      <button data-z="in" title="Zoom in">+</button>
      <button data-z="out" title="Zoom out">−</button>
      <button data-z="reset" title="Resetar view" style="font-size:13px">⌂</button>
    </div>
  </div>
</div>
```

---

## JAVASCRIPT (After Content Ready)

```javascript
const root = document.querySelector('.nm-root');
if (root && !root.dataset.nmInit) {
  root.dataset.nmInit = '1';

  // NM_BASE_CSS é injetado pelo gerador (CSS do mapa) — o <style> inline é sanitizado pelo plugin.
  if (typeof NM_BASE_CSS !== 'undefined') {
    const nmStyle = document.createElement('style');
    nmStyle.textContent = NM_BASE_CSS;
    root.appendChild(nmStyle);
  }

  const canvas   = root.querySelector('#nm-canvas');
  const viewport = root.querySelector('#nm-viewport');
  const svg      = root.querySelector('#nm-links');
  // Espaço de design fixo — o auto-fit (fit()) escala/centraliza no tamanho real do painel.
  const W = 1400, H = 760;

  const nodes = [
    { id:'RJ2', label:'RJ2', type:'pop-ix', x:W*0.26, y:H*0.18, r:43 },
    { id:'UFN', label:'UFN', type:'pop-ix', x:W*0.26, y:H*0.82, r:43 },
    { id:'MCO', label:'MCO', type:'pop',    x:W*0.45, y:H*0.18, r:43 },
    { id:'RNC', label:'RNC', type:'pop', core:true, x:W*0.45, y:H*0.52, r:43 },
    { id:'STR', label:'STR', type:'pop',    x:W*0.65, y:H*0.18, r:43 },
    { id:'SUM', label:'SUM', type:'pop',    x:W*0.65, y:H*0.52, r:43 },
    { id:'NIG', label:'NIG', type:'pop',    x:W*0.65, y:H*0.82, r:43 },
    { id:'MAG', label:'MAG', type:'pop',    x:W*0.88, y:H*0.18, r:43 },
    { id:'ASB', label:'ASB', type:'pop',    x:W*0.88, y:H*0.82, r:43 },
    { id:'PRIJ2_100', type:'ext-panel', title:'Peers RJ2 · 100G',
      peers:[{label:'Google',sub:'100GE0/0/6'},{label:'WIX Net',sub:'100GE0/0/1'},{label:'Seaborn',sub:'100GE0/0/2'}],
      x:W*0.06, y:H*0.10, r:76 },
    { id:'PRIJ2_10', type:'ext-panel', title:'Peers RJ2 · 10G',
      peers:[{label:'Google',sub:'XGE0/0/2'},{label:'NGT',sub:'XGE0/0/3'},{label:'OI',sub:'XGE0/0/7'}],
      x:W*0.06, y:H*0.30, r:76 },
    { id:'PUFN_100', type:'ext-panel', title:'Peers UFN · 100G',
      peers:[{label:'IX-RJ',sub:'100GE0/0/5'}], x:W*0.06, y:H*0.74, r:76 },
    { id:'PUFN_10', type:'ext-panel', title:'Peers UFN · 10G',
      peers:[{label:'GloboPlay',sub:'XGE0/0/8'},{label:'ITX Teleporto',sub:'XGE0/0/6'}],
      x:W*0.06, y:H*0.90, r:76 },
  ];

  const links = [
    { from:'MCO', to:'STR', bw:'100G', type:'100g', dir:'uni' },
    { from:'MCO', to:'RNC', bw:'100G', type:'100g', dir:'uni' },
    { from:'RJ2', to:'MCO', bw:'100G', type:'100g', dir:'uni', cable:'CABO 03' },
    { from:'RJ2', to:'UFN', bw:'40G',  type:'40g',  dir:'dual' },
    { from:'UFN', to:'RNC', bw:'100G', type:'100g', dir:'uni', cable:'CABO 02' },
    { from:'RNC', to:'NIG', bw:'100G', type:'100g', dir:'uni' },
    { from:'UFN', to:'NIG', bw:'100G', type:'100g', dir:'uni', cable:'CABO 01' },
    { from:'NIG', to:'MAG', bw:'100G', type:'100g', dir:'uni' },
    { from:'NIG', to:'ASB', bw:'10G',  type:'10g',  dir:'uni' },
    { from:'STR', to:'MAG', bw:'100G', type:'100g', dir:'uni' },
    { from:'STR', to:'SUM', bw:'100G', type:'100g', dir:'uni' },
    { from:'MAG', to:'SUM', bw:'100G', type:'100g', dir:'bi' },
    { from:'MAG', to:'ASB', bw:'10G',  type:'10g',  dir:'uni' },
    { from:'PRIJ2_100', to:'RJ2', bw:'100G', type:'100g', dir:'bi' },
    { from:'PRIJ2_10',  to:'RJ2', bw:'10G',  type:'10g',  dir:'bi' },
    { from:'PUFN_100', to:'UFN', bw:'100G', type:'100g', dir:'bi' },
    { from:'PUFN_10',  to:'UFN', bw:'10G',  type:'10g',  dir:'bi' },
  ];

  const pos = {}; nodes.forEach(n => pos[n.id] = { x:n.x, y:n.y });
  const nodeRadius = {}; nodes.forEach(n => nodeRadius[n.id] = n.r || 43);
  let viewX = 0, viewY = 0, viewScale = 1;

  function applyTransform() {
    viewport.style.transform = `translate(${viewX}px,${viewY}px) scale(${viewScale})`;
  }

  canvas.addEventListener('wheel', e => {
    e.preventDefault();
    const factor = e.deltaY < 0 ? 1.12 : 1/1.12;
    const rect = canvas.getBoundingClientRect();
    const mx = e.clientX - rect.left, my = e.clientY - rect.top;
    viewX = mx - (mx - viewX) * factor;
    viewY = my - (my - viewY) * factor;
    viewScale = Math.min(Math.max(viewScale * factor, 0.12), 5);
    applyTransform();
  }, { passive:false });

  function zoomBy(factor) {
    const cx = canvas.offsetWidth/2, cy = canvas.offsetHeight/2;
    viewX = cx - (cx - viewX) * factor;
    viewY = cy - (cy - viewY) * factor;
    viewScale = Math.min(Math.max(viewScale * factor, 0.12), 5);
    applyTransform();
  }
  function fit() {
    const cw = canvas.clientWidth, ch = canvas.clientHeight;
    if (!cw || !ch) return;
    viewScale = Math.min(cw / W, ch / H) * 0.95;
    viewX = (cw - W * viewScale) / 2;
    viewY = (ch - H * viewScale) / 2;
    applyTransform();
  }
  function resetView() { fit(); }

  root.querySelector('#nm-zoom').addEventListener('click', e => {
    const z = e.target.dataset.z;
    if (z === 'in') zoomBy(1.2);
    else if (z === 'out') zoomBy(0.83);
    else if (z === 'reset') resetView();
  });

  const lh = root.querySelector('#nm-legend-header');
  lh.addEventListener('click', () => {
    const body = root.querySelector('#nm-legend-body');
    const tog  = root.querySelector('#nm-legend-toggle');
    tog.textContent = body.classList.toggle('collapsed') ? '▼' : '▲';
  });

  // Pan do fundo
  let panning=false, panSX=0, panSY=0, panVX=0, panVY=0;
  canvas.addEventListener('mousedown', e => {
    const t = e.target;
    if (t===canvas || t===viewport || t===svg || t.tagName==='line' || t.tagName==='rect' || t.tagName==='text') {
      panning=true; panSX=e.clientX; panSY=e.clientY; panVX=viewX; panVY=viewY;
      canvas.classList.add('panning'); e.preventDefault();
    }
  });
  document.addEventListener('mousemove', e => {
    if (!panning) return;
    viewX = panVX + (e.clientX - panSX);
    viewY = panVY + (e.clientY - panSY);
    applyTransform();
  });
  document.addEventListener('mouseup', () => { panning=false; canvas.classList.remove('panning'); });

  // Nós
  const nodeEls = {};
  nodes.forEach(n => {
    const el = document.createElement('div');
    el.className = `node ${n.core ? 'pop-core' : n.type}`;
    const isPanel = n.type === 'ext-panel';
    let html = '';
    if (isPanel) {
      const rows = n.peers.map(p =>
        `<div class="panel-peer"><span class="peer-name">${p.label}</span><span class="peer-sub">${p.sub}</span></div>`).join('');
      html = `<div class="panel-title">${n.title}</div><div class="panel-sep"></div>${rows}`;
    } else {
      let badges = n.core ? `<div class="node-badges"><span class="badge core">Core</span></div>` : '';
      html = `<span class="node-label">${n.label}</span>${badges}`;
    }
    el.innerHTML = html;
    el.style.left = n.x + 'px'; el.style.top = n.y + 'px';
    viewport.appendChild(el);
    nodeEls[n.id] = el;

    let dragging=false, ox=0, oy=0;
    el.addEventListener('mousedown', e => {
      dragging = true;
      const rect = canvas.getBoundingClientRect();
      ox = (e.clientX - rect.left - viewX)/viewScale - pos[n.id].x;
      oy = (e.clientY - rect.top  - viewY)/viewScale - pos[n.id].y;
      el.style.zIndex = 20; e.stopPropagation(); e.preventDefault();
    });
    document.addEventListener('mousemove', e => {
      if (!dragging) return;
      const rect = canvas.getBoundingClientRect();
      pos[n.id].x = (e.clientX - rect.left - viewX)/viewScale - ox;
      pos[n.id].y = (e.clientY - rect.top  - viewY)/viewScale - oy;
      el.style.left = pos[n.id].x + 'px'; el.style.top = pos[n.id].y + 'px';
      renderLinks();
    });
    document.addEventListener('mouseup', () => { if (dragging){ dragging=false; el.style.zIndex=10; } });
  });

  // Links
  const colorMap = { '100g':'#4f9cf9', '40g':'#a78bfa', '10g':'#f97316' };
  function arrow(id, color) {
    return `<marker id="${id}" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
      <polygon points="0 0,10 3.5,0 7" fill="${color}"/></marker>`;
  }
  function labelSVG(x, y, text, color, cable) {
    const w = text.length * 7 + 10;
    let out = `<rect x="${x-w/2}" y="${y-10}" width="${w}" height="18" rx="4" fill="#0f1117" stroke="${color}" stroke-width="1" opacity="0.92"/>
      <text x="${x}" y="${y+4}" text-anchor="middle" class="link-label" fill="${color}">${text}</text>`;
    if (cable) {
      const cw = cable.length * 6.5 + 10;
      out += `<rect x="${x-cw/2}" y="${y-30}" width="${cw}" height="16" rx="3" fill="#1e2535" stroke="${color}" stroke-width="1" opacity="0.95"/>
        <text x="${x}" y="${y-18}" text-anchor="middle" font-size="9" font-weight="700" font-family="'Segoe UI',sans-serif" fill="#4ade80" opacity="0.95">${cable}</text>`;
    }
    return out;
  }
  function renderLinks() {
    let defs = `<defs>${arrow('arr-100g',colorMap['100g'])}${arrow('arr-40g',colorMap['40g'])}${arrow('arr-10g',colorMap['10g'])}</defs>`;
    let lines = '';
    links.forEach(lk => {
      const a = pos[lk.from], b = pos[lk.to];
      const dx=b.x-a.x, dy=b.y-a.y, dist=Math.sqrt(dx*dx+dy*dy);
      const ux=dx/dist, uy=dy/dist;
      const color=colorMap[lk.type], cls=`link-${lk.type}`;
      const Ra=nodeRadius[lk.from]||43, Rb=nodeRadius[lk.to]||43;
      const x1=a.x+ux*Ra, y1=a.y+uy*Ra, x2=b.x-ux*Rb, y2=b.y-uy*Rb;
      const mx=x1+(x2-x1)*0.5, my=y1+(y2-y1)*0.5;
      if (lk.dir==='dual') {
        const px=-uy*6, py=ux*6;
        lines += `<line x1="${x1+px}" y1="${y1+py}" x2="${x2+px}" y2="${y2+py}" class="${cls}" marker-end="url(#arr-${lk.type})"/>`;
        lines += `<line x1="${x2-px}" y1="${y2-py}" x2="${x1-px}" y2="${y1-py}" class="${cls}" marker-end="url(#arr-${lk.type})"/>`;
      } else if (lk.dir==='bi') {
        lines += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" class="${cls}" marker-end="url(#arr-${lk.type})" marker-start="url(#arr-${lk.type})"/>`;
      } else {
        lines += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" class="${cls}" marker-end="url(#arr-${lk.type})"/>`;
      }
      lines += labelSVG(mx, my, lk.bw, color, lk.cable);
    });
    svg.innerHTML = defs + lines;
  }
  renderLinks();
  fit();
  requestAnimationFrame(fit);
  if (window.ResizeObserver) { new ResizeObserver(() => fit()).observe(canvas); }
}
```

---

## 3. Próximo passo (deixar "vivo" com Zabbix)

Quando o estático estiver validado, ligamos os dados reais:

- Adicionar uma **query Zabbix** ao painel trazendo, por interface dos POPs:
  - status operacional (`ifOperStatus` / item de status no Zabbix) → cor da borda do nó e da linha (verde/vermelho).
  - tráfego in/out (`ifHCInOctets`/`ifHCOutOctets` → bps) → substitui o rótulo fixo (`bw`) por valor atual e/ou % de utilização.
- No bloco JavaScript, trocar os arrays fixos `nodes`/`links` por leitura do `context.data`
  (o Business Text expõe as séries do datasource em `context.data` / `data`), casando cada
  link a um item do Zabbix por um campo-chave (ex.: nome da interface `100GE0/0/6`).
- Definir limiares de cor (ex.: > 80% utilização = laranja, link down = vermelho piscando).

Para isso eu vou precisar saber **como os itens estão nomeados no seu Zabbix** (padrão de host
e de item/interface), pra mapear cada link do mapa ao item certo.
