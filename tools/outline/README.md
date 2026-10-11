# Как собран контур России

Контур: Natural Earth 50m (общественное достояние) из npm-пакета world-atlas.
Проекция: Альберса, стандартные параллели 50 и 70, центральный меридиан 100° в.д.

```
npm init -y && npm install world-atlas topojson-client
node extract.js                  # даёт rus50.geo.json
pip install shapely pillow
python3 build_outline.py         # даёт russia-outline.js и check.png (проверочная картинка)
cp russia-outline.js ../../frontend/components/
```

Координаты городов на карте считаются тем же кодом проекции (функция `project` в russia-outline.js),
поэтому маркеры всегда совпадают с контуром.
