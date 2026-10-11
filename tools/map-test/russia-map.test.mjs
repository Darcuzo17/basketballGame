import { JSDOM } from 'jsdom';
const dom = new JSDOM('<!doctype html><body></body>', { pretendToBeVisual: true });
for (const k of ['window','document','customElements','HTMLElement','CustomEvent','Event','MouseEvent']) {
  globalThis[k] = k === 'window' ? dom.window : dom.window[k];
}
globalThis.document = dom.window.document;
const { project } = await import('./russia-outline.mjs');
await import('./russia-map.mjs');

let fails = 0;
const ok = (cond, msg) => { console.log((cond ? 'OK   ' : 'FAIL ') + msg); if (!cond) fails++; };

// проекция даёт те же координаты, что и скрипт генерации
const [mx, my] = project(37.6173, 55.7558);
ok(Math.round(mx) === 146 && Math.round(my) === 222, `Москва в (${Math.round(mx)}, ${Math.round(my)})`);

const map = document.createElement('russia-map');
document.body.append(map);
const clubs = [
  { id: 1, name: 'Демо Москва-1', city: 'Москва', lat: 55.7558, lon: 37.6173, tier: 1, locked: false },
  { id: 2, name: 'Демо Москва-2', city: 'Москва', lat: 55.7558, lon: 37.6173, tier: 1, locked: true },
  { id: 3, name: 'Демо Пермь', city: 'Пермь', lat: 58.0105, lon: 56.2502, tier: 2, locked: false },
  { id: 4, name: 'Демо Закрытый', city: 'Казань', lat: 55.7961, lon: 49.1064, tier: 1, locked: true },
];
map.clubsJson = JSON.stringify(clubs);
const markers = map.shadowRoot.querySelectorAll('.marker');
ok(markers.length === 3, `маркеров 3 (города), получено ${markers.length}: Москва сгруппирована`);
ok(map.shadowRoot.querySelectorAll('.count').length === 1, 'у сгруппированного города есть счётчик');
const fills = [...markers].map(m => m.querySelector('.dot').getAttribute('fill'));
ok(fills[0] === '#e8590c' && fills[1] === '#1971c2' && fills[2] === '#868e96', `цвета по лигам и замок: ${fills}`);
ok(map.shadowRoot.querySelectorAll('path[d^="M-2"]').length === 1, 'у закрытого одиночного клуба нарисован замок');

const events = [];
map.addEventListener('club-select', e => events.push(['club', e.detail.id]));
map.addEventListener('city-select', e => events.push(['city', e.detail.ids]));
markers[1].dispatchEvent(new dom.window.Event('click'));
markers[0].dispatchEvent(new dom.window.Event('click'));
ok(JSON.stringify(events) === '[["club",3],["city","1,2"]]', `события: ${JSON.stringify(events)}`);

map.selectedId = 3;
const shown = [...map.shadowRoot.querySelectorAll('.ring')].filter(r => r.getAttribute('display') === 'inline').length;
ok(shown === 1, 'выбран ровно один маркер');
map.selectedId = -1;
ok([...map.shadowRoot.querySelectorAll('.ring')].every(r => r.getAttribute('display') === 'none'), 'выбор снимается значением -1');

// масштаб колесом и ограничение сдвига
const svg = map.shadowRoot.querySelector('svg');
const wheel = new dom.window.Event('wheel', { cancelable: true });
Object.assign(wheel, { deltaY: -1000, clientX: 0, clientY: 0 });
svg.dispatchEvent(wheel);
ok(map._t.k > 1 && map._t.k <= 12, `масштаб вырос до ${map._t.k.toFixed(2)}`);
for (let i = 0; i < 30; i++) svg.dispatchEvent(Object.assign(new dom.window.Event('wheel', { cancelable: true }), { deltaY: -1000, clientX: 0, clientY: 0 }));
ok(map._t.k === 12, 'масштаб ограничен максимумом 12');
ok(map._t.x <= 0 && map._t.y <= 0, 'карту нельзя утащить за пределы');
map.shadowRoot.querySelector('[data-act="reset"]').dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true }));
ok(map._t.k === 1 && map._t.x === 0, 'кнопка сброса возвращает масштаб');

// перетаскивание не должно считаться кликом по маркеру
events.length = 0;
const down = Object.assign(new dom.window.Event('pointerdown'), { pointerId: 1, clientX: 10, clientY: 10 });
const move = Object.assign(new dom.window.Event('pointermove'), { pointerId: 1, clientX: 80, clientY: 80 });
svg.dispatchEvent(down); svg.dispatchEvent(move);
markers[1].dispatchEvent(new dom.window.Event('click'));
ok(events.length === 0, 'после перетаскивания клик по маркеру игнорируется');

// пустой и сломанный JSON не ломают компонент
map.clubsJson = '';
ok(map.shadowRoot.querySelectorAll('.marker').length === 0, 'пустой список очищает карту');
map.clubsJson = '{oops';
ok(map.shadowRoot.querySelectorAll('.marker').length === 0, 'некорректный JSON не вызывает ошибку');

console.log(fails === 0 ? '\nвсе проверки прошли' : `\nпровалено: ${fails}`);
process.exit(fails ? 1 : 0);
