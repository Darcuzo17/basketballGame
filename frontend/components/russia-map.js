import { VIEW_WIDTH, VIEW_HEIGHT, OUTLINE_PATH, project } from './russia-outline.js';

/**
 * Веб-компонент <russia-map>: карта России с маркерами клубов.
 *
 * Свойства (задаются из Java):
 *   clubsJson  — JSON-массив клубов: [{id, name, city, lat, lon, tier, locked, ...}]
 *   selectedId — id выбранного клуба или -1
 *
 * События:
 *   club-select — detail: { id }       (клик по городу с одним клубом)
 *   city-select — detail: { ids }      (клик по городу с несколькими клубами, ids через запятую)
 *
 * Управление: колесо мыши, перетаскивание, щипок двумя пальцами, кнопки +, −, сброс.
 */

const SVG_NS = 'http://www.w3.org/2000/svg';
const TIER_COLORS = { 1: '#e8590c', 2: '#1971c2', 3: '#2f9e44' };
const DEFAULT_COLOR = '#7048e8';
const LOCKED_COLOR = '#868e96';
const MAX_ZOOM = 12;
const CLICK_MOVE_LIMIT = 6;

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

function el(name, attrs = {}, text) {
  const node = document.createElementNS(SVG_NS, name);
  for (const [key, value] of Object.entries(attrs)) {
    node.setAttribute(key, value);
  }
  if (text !== undefined) {
    node.textContent = text;
  }
  return node;
}

class RussiaMap extends HTMLElement {
  constructor() {
    super();
    this._clubs = [];
    this._selectedId = null;
    this._groups = [];
    this._t = { k: 1, x: 0, y: 0 };
    this._pointers = new Map();
    this._moved = 0;

    this.attachShadow({ mode: 'open' });
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: block; position: relative; }
        .wrap { position: relative; width: 100%; background: var(--lumo-contrast-5pct, #f1f3f5);
                border-radius: var(--lumo-border-radius-l, 8px); overflow: hidden; }
        svg { display: block; width: 100%; height: auto; touch-action: none; user-select: none; cursor: grab; }
        svg:active { cursor: grabbing; }
        .land { fill: var(--lumo-base-color, #ffffff); stroke: var(--lumo-contrast-40pct, #adb5bd);
                stroke-width: 1; vector-effect: non-scaling-stroke; stroke-linejoin: round; }
        .marker { cursor: pointer; outline: none; }
        .marker .dot { stroke: #ffffff; stroke-width: 2; }
        .marker:focus .dot, .marker:hover .dot { stroke: var(--lumo-body-text-color, #212529); }
        .ring { fill: none; stroke: var(--lumo-primary-color, #e8590c); stroke-width: 3; }
        .count { fill: #ffffff; font: 700 10px sans-serif; text-anchor: middle; dominant-baseline: central; pointer-events: none; }
        .label { fill: var(--lumo-body-text-color, #212529); font: 600 13px sans-serif; text-anchor: middle;
                 paint-order: stroke; stroke: var(--lumo-base-color, #ffffff); stroke-width: 4px; pointer-events: none; }
        .controls { position: absolute; right: 8px; top: 8px; display: flex; flex-direction: column; gap: 6px; }
        .controls button { width: 36px; height: 36px; border: 0; border-radius: 8px; cursor: pointer;
                           font: 600 18px sans-serif; background: var(--lumo-base-color, #ffffff);
                           color: var(--lumo-body-text-color, #212529); box-shadow: 0 1px 3px rgba(0, 0, 0, .3); }
      </style>
      <div class="wrap">
        <svg viewBox="0 0 ${VIEW_WIDTH} ${VIEW_HEIGHT}" role="img" aria-label="Карта России с клубами">
          <g class="world"><path class="land" d="${OUTLINE_PATH}"></path></g>
          <g class="markers"></g>
        </svg>
        <div class="controls">
          <button type="button" data-act="in" aria-label="Приблизить">+</button>
          <button type="button" data-act="out" aria-label="Отдалить">−</button>
          <button type="button" data-act="reset" aria-label="Сбросить масштаб">⌂</button>
        </div>
      </div>`;

    this._svg = this.shadowRoot.querySelector('svg');
    this._world = this.shadowRoot.querySelector('.world');
    this._markers = this.shadowRoot.querySelector('.markers');
    this._bindGestures();
    this._bindControls();
  }

  // ---- свойства ----

  get clubsJson() {
    return JSON.stringify(this._clubs);
  }

  set clubsJson(value) {
    try {
      this._clubs = value ? JSON.parse(value) : [];
    } catch (e) {
      this._clubs = [];
    }
    this._rebuildMarkers();
  }

  get selectedId() {
    return this._selectedId;
  }

  set selectedId(value) {
    const id = Number(value);
    this._selectedId = value === null || value === undefined || Number.isNaN(id) || id < 0 ? null : id;
    this._updateSelection();
  }

  // ---- маркеры ----

  _rebuildMarkers() {
    this._markers.replaceChildren();
    this._groups = [];

    const byCity = new Map();
    for (const club of this._clubs) {
      const key = `${Number(club.lat).toFixed(2)},${Number(club.lon).toFixed(2)}`;
      if (!byCity.has(key)) {
        byCity.set(key, []);
      }
      byCity.get(key).push(club);
    }

    for (const clubs of byCity.values()) {
      const [bx, by] = project(Number(clubs[0].lon), Number(clubs[0].lat));
      const open = clubs.filter(c => !c.locked);
      const color = open.length === 0
        ? LOCKED_COLOR
        : (TIER_COLORS[Math.min(...open.map(c => c.tier))] || DEFAULT_COLOR);

      const g = el('g', { class: 'marker', tabindex: '0', role: 'button',
        'aria-label': clubs.length === 1 ? clubs[0].name : `${clubs[0].city}: клубов ${clubs.length}` });
      const ring = el('circle', { class: 'ring', r: '14', display: 'none' });
      const dot = el('circle', { class: 'dot', r: '9', fill: color });
      const title = el('title', {}, clubs.map(c => c.name).join(', '));
      g.append(ring, dot, title);

      if (clubs.length > 1) {
        g.append(el('text', { class: 'count' }, String(clubs.length)));
      } else if (clubs[0].locked) {
        g.append(
          el('rect', { x: '-3', y: '-1', width: '6', height: '5', fill: '#ffffff', 'pointer-events': 'none' }),
          el('path', { d: 'M-2,-1 V-2.5 a2,2 0 0 1 4,0 V-1', fill: 'none', stroke: '#ffffff',
            'stroke-width': '1.2', 'pointer-events': 'none' }));
      }
      const label = el('text', { class: 'label', y: '-18', display: 'none' }, clubs[0].city);
      g.append(label);

      const group = { clubs, bx, by, el: g, ring, label };
      g.addEventListener('click', () => this._activate(group));
      g.addEventListener('keydown', e => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          this._activate(group, true);
        }
      });
      this._markers.append(g);
      this._groups.push(group);
    }
    this._applyTransform();
    this._updateSelection();
  }

  _activate(group, fromKeyboard = false) {
    if (!fromKeyboard && this._moved > CLICK_MOVE_LIMIT) {
      return; // это было перетаскивание, а не клик
    }
    if (group.clubs.length === 1) {
      this._emit('club-select', { id: group.clubs[0].id });
    } else {
      this._emit('city-select', { ids: group.clubs.map(c => c.id).join(',') });
    }
  }

  _emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true }));
  }

  _updateSelection() {
    for (const group of this._groups) {
      const selected = this._selectedId !== null && group.clubs.some(c => c.id === this._selectedId);
      group.ring.setAttribute('display', selected ? 'inline' : 'none');
      group.label.setAttribute('display', selected ? 'inline' : 'none');
      if (selected) {
        this._markers.append(group.el); // поднять выбранный маркер над остальными
      }
    }
  }

  // ---- масштаб и перемещение ----

  _applyTransform() {
    const { k, x, y } = this._t;
    this._world.setAttribute('transform', `translate(${x} ${y}) scale(${k})`);
    for (const group of this._groups) {
      group.el.setAttribute('transform', `translate(${group.bx * k + x} ${group.by * k + y})`);
    }
  }

  _clampAndApply() {
    const t = this._t;
    t.x = clamp(t.x, VIEW_WIDTH - VIEW_WIDTH * t.k, 0);
    t.y = clamp(t.y, VIEW_HEIGHT - VIEW_HEIGHT * t.k, 0);
    this._applyTransform();
  }

  /** Сколько единиц SVG приходится на один пиксель экрана. */
  _unitsPerPixel() {
    const rect = this._svg.getBoundingClientRect();
    return rect.width > 0 ? VIEW_WIDTH / rect.width : 1;
  }

  _zoomAt(clientX, clientY, factor) {
    const rect = this._svg.getBoundingClientRect();
    const s = this._unitsPerPixel();
    const px = (clientX - rect.left) * s;
    const py = (clientY - rect.top) * s;
    const t = this._t;
    const k = clamp(t.k * factor, 1, MAX_ZOOM);
    const f = k / t.k;
    t.x = px - (px - t.x) * f;
    t.y = py - (py - t.y) * f;
    t.k = k;
    this._clampAndApply();
  }

  _bindGestures() {
    const svg = this._svg;

    /*svg.addEventListener('wheel', e => {
      e.preventDefault();
      this._zoomAt(e.clientX, e.clientY, Math.exp(-e.deltaY * 0.0015));
    }, { passive: false });*/

    svg.addEventListener('pointerdown', e => {
      this._pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (this._pointers.size === 1) {
        this._moved = 0;
      }
    });

    svg.addEventListener('pointermove', e => {
      const prev = this._pointers.get(e.pointerId);
      if (!prev) {
        return;
      }
      const current = { x: e.clientX, y: e.clientY };
      if (this._pointers.size === 1) {
        const s = this._unitsPerPixel();
        this._t.x += (current.x - prev.x) * s;
        this._t.y += (current.y - prev.y) * s;
        this._moved += Math.abs(current.x - prev.x) + Math.abs(current.y - prev.y);
        this._pointers.set(e.pointerId, current);
        this._clampAndApply();
      } else if (this._pointers.size === 2) {
        const other = [...this._pointers.entries()].find(([id]) => id !== e.pointerId)[1];
        const oldDistance = Math.hypot(prev.x - other.x, prev.y - other.y);
        const newDistance = Math.hypot(current.x - other.x, current.y - other.y);
        this._pointers.set(e.pointerId, current);
        this._moved += CLICK_MOVE_LIMIT + 1;
        if (oldDistance > 0) {
          this._zoomAt((current.x + other.x) / 2, (current.y + other.y) / 2, newDistance / oldDistance);
        }
      }
    });

    const end = e => this._pointers.delete(e.pointerId);
    svg.addEventListener('pointerup', end);
    svg.addEventListener('pointercancel', end);
    svg.addEventListener('pointerleave', end);
  }

  _bindControls() {
    this.shadowRoot.querySelector('.controls').addEventListener('click', e => {
      const action = e.target.closest('button')?.dataset.act;
      if (!action) {
        return;
      }
      const rect = this._svg.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      if (action === 'in') {
        this._zoomAt(cx, cy, 1.6);
      } else if (action === 'out') {
        this._zoomAt(cx, cy, 1 / 1.6);
      } else {
        this._t = { k: 1, x: 0, y: 0 };
        this._applyTransform();
      }
    });
  }
}

if (!customElements.get('russia-map')) {
  customElements.define('russia-map', RussiaMap);
}
