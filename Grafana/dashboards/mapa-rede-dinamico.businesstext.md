# Mapa de Rede LOGNET — versão DINÂMICA (Zabbix)

Mesma topologia/visual do `mapa-rede.businesstext.md`, mas o painel lê uma **query Zabbix**
e reflete em tempo real:

- **Status (up/down)** → link/POP vermelho piscando quando down.
- **Tráfego** → o rótulo do link mostra o tráfego atual e a % de utilização; a cor da linha
  vai de verde → laranja → vermelho conforme a utilização.

O HTML/CSS é **idêntico** ao da versão estática (o gerador reaproveita). Aqui muda só o
JavaScript. O arquivo importável é **`mapa-rede-dinamico.json`**.

## Padrão real do Zabbix (LOGNET)

Calibrado a partir do ambiente real:

| O quê | Como aparece |
|---|---|
| Host | `SW07-POP-RJ2-RJ` (padrão `SW##-POP-<sigla>-<UF>`) |
| Tráfego entrada | item **Tráfego de entrada `<ifName>`**, chave `ifHCInOctets[<ifName>]`, unidade **bps** |
| Tráfego saída | item **Tráfego de saída `<ifName>`**, chave `ifHCOutOctets[<ifName>]`, unidade **bps** |
| ifName | `100GE0/0/1`, `XGigabitEthernet0/0/9` (no Zabbix é `XGigabitEthernet`, não `XGE`) |
| Status do POP | item **ICMP ping** (chave `icmpping`, 1 = up) |

> Como os itens já vêm em **bps**, `CONFIG.octetsToBits = 1`. Se algum dia adicionar um item
> em octets/s, troque para 8.

---

## 1. Importar e ligar a query

1. Importe `mapa-rede-dinamico.json` (**Dashboards → New → Import → Upload JSON file**).
2. Edite o painel → aba de **query** → datasource **Zabbix**, e monte uma query que traga,
   dos hosts dos POPs, os itens de tráfego e o ICMP ping. Sugestão de filtros (regex):
   - **Host:** `/SW.*POP.*/`
   - **Item:** `/Tráfego de (entrada|saída)|ICMP ping/`
3. **Importante p/ o match por host:** garanta que o nome da série inclua o host
   (no datasource Zabbix, a série costuma vir como `Host: Item`). O código também tenta a
   label `host`, mas o nome `Host: Item` é o mais garantido.

> O painel renderiza mesmo sem dados (cai no `defaultContent`); os links começam com o
> rótulo fixo e ganham vida assim que a query retorna séries.

## 2. Mapeamento (bloco `CONFIG` no JS)

No topo do `afterRender`:

- `CONFIG.patterns` — regex que classificam a série em entrada / saída / status / ping.
  Já ajustados aos nomes PT do seu ambiente.
- `LINK_IF` — para cada link, **host + interface(s)** que o representam. Aceita `iface` como
  string ou **lista** (os painéis de peer somam várias portas). `cap` (bps) opcional sobrepõe
  a capacidade nominal do tipo — útil para enlaces agregados. **RJ2 já vem preenchido como
  exemplo real.**
- `NODE_IF` — status do POP. `{ host, ping:true }` usa o ICMP ping; ou `{ host, iface }` usa
  o status operacional da interface.

Links sem entrada em `LINK_IF` mantêm o rótulo fixo e cor neutra.

## Mapeamento POP → host (Zabbix)

| Mapa | Host | Mapa | Host |
|---|---|---|---|
| RJ2 | `SW07-POP-RJ2-RJ` | NIG | `SW03-POP-NIG-RJ` |
| UFN | `SW06-POP-UFN-RJ` | MAG | `SW04-POP-MAG-RJ` |
| MCO | `SW02-POP-MCO-RJ` | SUM | `SW11-POP-SUM-RJ` |
| RNC | `SW01-POP-RAN-RJ` (Rancho Novo) | ASB | `SW12-POP-ASB-RJ` |
| STR | `SW05-POP-SRI-RJ` (Santa Rita) | | |

`SW08-POP-BDP-RJ` não tem nó no mapa atual.

## 3. O que ainda falta preencher

Já vivos: **status dos 9 POPs** (ICMP), os **4 painéis de peers** e **8 enlaces de backbone**.

Faltam 4 enlaces, comentados em `LINK_IF`, por não terem porta identificável nos dados:
`RJ2->UFN` (40G), `UFN->RNC` (CABO 02), `STR->SUM`, `MAG->SUM`, `MAG->ASB`. Quando tiver o
ifName (e o host de origem), descomente e preencha. Faltam também os switches **Morro Agudo
(SW04)** e **Summer (SW11)** na planilha de interfaces.

## 4. Regerar o JSON após editar

```bash
node Grafana/dashboards/_gen-mapa-rede.mjs
```

---

## JAVASCRIPT (After Content Ready)

```javascript
/* ===================== CONFIG — padrão LOGNET/Zabbix ===================== */
const CONFIG = {
  // Classifica a série PELO NOME. Ajustado aos nomes reais (PT) do ambiente.
  patterns: {
    in:     /tr[aá]fego de entrada|ifHCInOctets|in\s*octets|received|entrada/i,
    out:    /tr[aá]fego de sa[ií]da|ifHCOutOctets|out\s*octets|sent|sa[ií]da/i,
    status: /status operacional|oper.*status|ifOperStatus|operational/i,
    ping:   /icmp ping/i,
  },
  capacity: { '100g': 100e9, '40g': 40e9, '10g': 10e9 }, // bps p/ % utilização
  util: { warn: 0.60, crit: 0.80 },                       // limiares de cor
  statusUp: 1,        // ifOperStatus: 1 = up
  pingUp: 1,          // icmpping: 1 = respondendo
  octetsToBits: 1,    // itens já em bps; troque p/ 8 se vier em octets/s
};

// Cada link 'from->to' -> host + interface(s). iface pode ser string ou lista.
// cap (bps) opcional sobrepõe capacity[type] (útil p/ enlaces agregados).
const LINK_IF = {
  // --- Peers (preenchidos: host + interfaces do modelo) ---
  'PRIJ2_100->RJ2': { host: 'SW07-POP-RJ2-RJ',
    iface: ['100GE0/0/6', '100GE0/0/1', '100GE0/0/2'], cap: 300e9 },
  'PRIJ2_10->RJ2':  { host: 'SW07-POP-RJ2-RJ',
    iface: ['XGigabitEthernet0/0/2', 'XGigabitEthernet0/0/3', 'XGigabitEthernet0/0/7'], cap: 30e9 },
  'PUFN_100->UFN':  { host: 'SW06-POP-UFN-RJ',
    iface: ['100GE0/0/5'], cap: 100e9 },
  'PUFN_10->UFN':   { host: 'SW06-POP-UFN-RJ',
    iface: ['XGigabitEthernet0/0/8', 'XGigabitEthernet0/0/6'], cap: 20e9 },

  // --- Backbone (extraído das descrições das interfaces) ---
  'RJ2->MCO': { host: 'SW07-POP-RJ2-RJ', iface: '100GE0/0/5' },          // CABO-03_RJ2_X_MCO
  'MCO->STR': { host: 'SW02-POP-MCO-RJ', iface: '100GE0/0/3' },          // MCO_X_SRI
  'MCO->RNC': { host: 'SW02-POP-MCO-RJ', iface: '100GE0/0/1' },          // MCO_X_RAN
  'RNC->NIG': { host: 'SW03-POP-NIG-RJ', iface: '100GE0/0/3' },          // NIG_X_RAN (lado NIG)
  'UFN->NIG': { host: 'SW03-POP-NIG-RJ', iface: '100GE0/0/2' },          // NIG_X_UFN (CABO 01, lado NIG)
  'NIG->MAG': { host: 'SW03-POP-NIG-RJ', iface: '100GE0/0/1' },          // NIG_X_MAG
  'NIG->ASB': { host: 'SW03-POP-NIG-RJ', iface: 'XGigabitEthernet0/0/14' }, // MASTER-NIG-ANBEZERRA (10G)
  'STR->MAG': { host: 'SW05-POP-SRI-RJ', iface: '100GE0/0/1' },          // SRI_X_MAG

  // --- Sem porta clara nos dados fornecidos (preencher quando souber) ---
  // 'RJ2->UFN' 40G  — no SW RJ2 só há LAG_RJ2_X_NBSC_80G, sem RJ2_X_UFN
  // 'UFN->RNC' CABO 02 — SW Rancho Novo não tem 100GE; lista 100GE do UFN estava cortada
  // 'STR->SUM'      — sem SRI_X_SUM nas descrições
  // 'MAG->SUM'      — sem dados do SW Morro Agudo (SW04)
  // 'MAG->ASB' 10G  — sem dados do SW Morro Agudo (SW04)
};

// Status do POP via ICMP ping (1 = up). Todos os POPs mapeados.
const NODE_IF = {
  'RJ2': { host: 'SW07-POP-RJ2-RJ', ping: true },
  'UFN': { host: 'SW06-POP-UFN-RJ', ping: true },
  'MCO': { host: 'SW02-POP-MCO-RJ', ping: true },
  'RNC': { host: 'SW01-POP-RAN-RJ', ping: true }, // RAN = Rancho Novo
  'STR': { host: 'SW05-POP-SRI-RJ', ping: true }, // SRI = Santa Rita
  'SUM': { host: 'SW11-POP-SUM-RJ', ping: true },
  'NIG': { host: 'SW03-POP-NIG-RJ', ping: true },
  'MAG': { host: 'SW04-POP-MAG-RJ', ping: true },
  'ASB': { host: 'SW12-POP-ASB-RJ', ping: true },
};
/* ======================================================================== */

function getCtx() {
  if (typeof context !== 'undefined' && context) return context;
  if (typeof data !== 'undefined' && data) return { data: data };
  return null;
}

function readSeries(ctx) {
  const res = [];
  const series = (ctx && ctx.data && ctx.data.series) || [];
  series.forEach(fr => {
    const fields = fr.fields || [];
    const vf = fields.find(f => f.type === 'number') || fields[1];
    if (!vf) return;
    const raw = vf.values;
    const vals = raw && raw.toArray ? raw.toArray() : (raw || []);
    let last = null;
    for (let i = vals.length - 1; i >= 0; i--) { if (vals[i] != null) { last = vals[i]; break; } }
    const labels = vf.labels || {};
    const nm = fr.name || (vf.config && vf.config.displayName) ||
               Object.values(labels).join(' ') || vf.name || '';
    res.push({ name: String(nm), host: String(labels.host || labels.Host || ''), value: last });
  });
  return res;
}

function hostMatch(s, host) {
  return !host || s.host === host || s.name.indexOf(host) !== -1;
}
function ifaceRe(iface) {
  return new RegExp(iface.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(?![0-9])');
}

// Soma o último valor das interfaces que casam (host + iface + tipo).
function pickSum(series, host, ifaces, kind) {
  const pat = CONFIG.patterns[kind];
  let sum = null;
  ifaces.forEach(ifc => {
    const re = ifaceRe(ifc);
    const hit = series.find(s => hostMatch(s, host) && pat.test(s.name) && re.test(s.name));
    if (hit && hit.value != null) sum = (sum || 0) + Number(hit.value);
  });
  return sum;
}

// Status agregado das interfaces: known=havia item de status; down=alguma down.
function ifStatus(series, host, ifaces) {
  const pat = CONFIG.patterns.status;
  let known = false, down = false;
  ifaces.forEach(ifc => {
    const re = ifaceRe(ifc);
    const hit = series.find(s => hostMatch(s, host) && pat.test(s.name) && re.test(s.name));
    if (hit && hit.value != null) { known = true; if (Number(hit.value) !== CONFIG.statusUp) down = true; }
  });
  return { known, down };
}

function nodePingDown(series, host) {
  const hit = series.find(s => hostMatch(s, host) && CONFIG.patterns.ping.test(s.name));
  if (!hit || hit.value == null) return false;
  return Number(hit.value) !== CONFIG.pingUp;
}

function fmtbps(bps) {
  if (bps == null || isNaN(bps)) return null;
  const u = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
  let i = 0, v = Math.abs(bps);
  while (v >= 1000 && i < u.length - 1) { v /= 1000; i++; }
  return (v < 10 ? v.toFixed(1) : Math.round(v)) + ' ' + u[i];
}

function utilColor(u) {
  if (u == null) return null;
  if (u >= CONFIG.util.crit) return '#ef4444';
  if (u >= CONFIG.util.warn) return '#f59e0b';
  return '#22c55e';
}

function buildMap(root) {
  const canvas   = root.querySelector('#nm-canvas');
  const viewport = root.querySelector('#nm-viewport');
  const svg      = root.querySelector('#nm-links');
  // Espaço de design fixo — o auto-fit (fit()) escala/centraliza no tamanho real do painel.
  const W = 1400, H = 760;

  // NM_BASE_CSS é injetado pelo gerador (CSS do mapa) — o <style> inline é sanitizado pelo plugin.
  const st = document.createElement('style');
  st.textContent =
    (typeof NM_BASE_CSS !== 'undefined' ? NM_BASE_CSS : '') +
    '.nm-root .link-down{stroke:#ef4444 !important;animation:nm-blink 1s steps(2,start) infinite;}' +
    '.nm-root .node.down{border-color:#ef4444 !important;color:#ef4444 !important;animation:nm-blink 1s steps(2,start) infinite;}' +
    '@keyframes nm-blink{50%{opacity:.25;}}';
  root.appendChild(st);

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
    viewport.style.transform = 'translate(' + viewX + 'px,' + viewY + 'px) scale(' + viewScale + ')';
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
  // Ajusta a escala/posição para o mapa (W x H) caber na área real do painel.
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

  root.querySelector('#nm-legend-header').addEventListener('click', () => {
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
    viewX = panVX + (e.clientX - panSX); viewY = panVY + (e.clientY - panSY);
    applyTransform();
  });
  document.addEventListener('mouseup', () => { panning=false; canvas.classList.remove('panning'); });

  // Nós
  const nodeEls = {};
  nodes.forEach(n => {
    const el = document.createElement('div');
    el.className = 'node ' + (n.core ? 'pop-core' : n.type);
    if (n.type === 'ext-panel') {
      const rows = n.peers.map(p =>
        '<div class="panel-peer"><span class="peer-name">' + p.label +
        '</span><span class="peer-sub">' + p.sub + '</span></div>').join('');
      el.innerHTML = '<div class="panel-title">' + n.title + '</div><div class="panel-sep"></div>' + rows;
    } else {
      const badges = n.core ? '<div class="node-badges"><span class="badge core">Core</span></div>' : '';
      el.innerHTML = '<span class="node-label">' + n.label + '</span>' + badges;
    }
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

  const colorMap = { '100g':'#4f9cf9', '40g':'#a78bfa', '10g':'#f97316' };
  function arrow(id, color) {
    return '<marker id="' + id + '" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">' +
           '<polygon points="0 0,10 3.5,0 7" fill="' + color + '"/></marker>';
  }
  function labelSVG(x, y, text, color, cable) {
    const w = text.length * 7 + 10;
    let out = '<rect x="' + (x-w/2) + '" y="' + (y-10) + '" width="' + w + '" height="18" rx="4" fill="#0f1117" stroke="' + color + '" stroke-width="1" opacity="0.92"/>' +
      '<text x="' + x + '" y="' + (y+4) + '" text-anchor="middle" class="link-label" fill="' + color + '">' + text + '</text>';
    if (cable) {
      const cw = cable.length * 6.5 + 10;
      out += '<rect x="' + (x-cw/2) + '" y="' + (y-30) + '" width="' + cw + '" height="16" rx="3" fill="#1e2535" stroke="' + color + '" stroke-width="1" opacity="0.95"/>' +
        '<text x="' + x + '" y="' + (y-18) + '" text-anchor="middle" font-size="9" font-weight="700" font-family="\'Segoe UI\',sans-serif" fill="#4ade80" opacity="0.95">' + cable + '</text>';
    }
    return out;
  }

  function renderLinks() {
    let defs = '<defs>' + arrow('arr-100g',colorMap['100g']) + arrow('arr-40g',colorMap['40g']) + arrow('arr-10g',colorMap['10g']) + '</defs>';
    let lines = '';
    links.forEach(lk => {
      const a = pos[lk.from], b = pos[lk.to];
      const dx=b.x-a.x, dy=b.y-a.y, dist=Math.sqrt(dx*dx+dy*dy) || 1;
      const ux=dx/dist, uy=dy/dist;
      const baseColor = colorMap[lk.type];
      const color = lk._down ? '#ef4444' : (lk._color || baseColor);
      const cls = 'link-' + lk.type + (lk._down ? ' link-down' : '');
      const Ra=nodeRadius[lk.from]||43, Rb=nodeRadius[lk.to]||43;
      const x1=a.x+ux*Ra, y1=a.y+uy*Ra, x2=b.x-ux*Rb, y2=b.y-uy*Rb;
      const mx=x1+(x2-x1)*0.5, my=y1+(y2-y1)*0.5;
      const strokeStyle = (lk._color && !lk._down) ? ' style="stroke:' + lk._color + '"' : '';
      if (lk.dir==='dual') {
        const px=-uy*6, py=ux*6;
        lines += '<line x1="' + (x1+px) + '" y1="' + (y1+py) + '" x2="' + (x2+px) + '" y2="' + (y2+py) + '" class="' + cls + '"' + strokeStyle + ' marker-end="url(#arr-' + lk.type + ')"/>';
        lines += '<line x1="' + (x2-px) + '" y1="' + (y2-py) + '" x2="' + (x1-px) + '" y2="' + (y1-py) + '" class="' + cls + '"' + strokeStyle + ' marker-end="url(#arr-' + lk.type + ')"/>';
      } else if (lk.dir==='bi') {
        lines += '<line x1="' + x1 + '" y1="' + y1 + '" x2="' + x2 + '" y2="' + y2 + '" class="' + cls + '"' + strokeStyle + ' marker-end="url(#arr-' + lk.type + ')" marker-start="url(#arr-' + lk.type + ')"/>';
      } else {
        lines += '<line x1="' + x1 + '" y1="' + y1 + '" x2="' + x2 + '" y2="' + y2 + '" class="' + cls + '"' + strokeStyle + ' marker-end="url(#arr-' + lk.type + ')"/>';
      }
      lines += labelSVG(mx, my, lk._label || lk.bw, color, lk.cable);
    });
    svg.innerHTML = defs + lines;
  }

  function apply(series) {
    links.forEach(lk => {
      lk._down = false; lk._color = null; lk._label = null;
      const cfg = LINK_IF[lk.from + '->' + lk.to];
      if (!cfg) return;
      const ifaces = Array.isArray(cfg.iface) ? cfg.iface : [cfg.iface];
      const stt = ifStatus(series, cfg.host, ifaces);
      if (stt.known && stt.down) { lk._down = true; return; }
      let inb  = pickSum(series, cfg.host, ifaces, 'in');
      let outb = pickSum(series, cfg.host, ifaces, 'out');
      const k = CONFIG.octetsToBits;
      if (inb  != null) inb  *= k;
      if (outb != null) outb *= k;
      const cap = cfg.cap || CONFIG.capacity[lk.type];
      const tot = Math.max(inb || 0, outb || 0);
      if (tot > 0 && cap) {
        const u = tot / cap;
        lk._color = utilColor(u);
        lk._label = fmtbps(tot) + ' · ' + Math.round(u * 100) + '%';
      } else if (tot > 0) {
        lk._label = fmtbps(tot);
      }
    });
    nodes.forEach(n => {
      const el = nodeEls[n.id]; if (!el) return;
      el.classList.remove('down');
      const cfg = NODE_IF[n.id];
      if (!cfg) return;
      if (cfg.ping && nodePingDown(series, cfg.host)) el.classList.add('down');
      else if (cfg.iface) {
        const s = ifStatus(series, cfg.host, [].concat(cfg.iface));
        if (s.known && s.down) el.classList.add('down');
      }
    });
    renderLinks();
  }

  renderLinks();
  fit();
  requestAnimationFrame(fit);
  if (window.ResizeObserver) { new ResizeObserver(() => fit()).observe(canvas); }
  return { apply: apply };
}

const root = document.querySelector('.nm-root');
if (root) {
  if (!root.__nm) root.__nm = buildMap(root);
  root.__nm.apply(readSeries(getCtx()));
}
```
