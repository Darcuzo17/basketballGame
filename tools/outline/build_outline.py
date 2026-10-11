import json, math
from shapely.geometry import Polygon

LON0, LAT1, LAT2, LAT0 = 100.0, 50.0, 70.0, 56.0
r = math.radians
n = (math.sin(r(LAT1)) + math.sin(r(LAT2))) / 2
C = math.cos(r(LAT1))**2 + 2*n*math.sin(r(LAT1))
RHO0 = math.sqrt(C - 2*n*math.sin(r(LAT0))) / n

def proj(lon, lat):
    dl = lon - LON0
    if dl < -180: dl += 360
    if dl >= 180: dl -= 360
    rho = math.sqrt(C - 2*n*math.sin(r(lat))) / n
    th = n * r(dl)
    x = rho * math.sin(th)
    y = rho * math.cos(th) - RHO0      # y вниз, как в SVG
    return x, y

geo = json.load(open('rus50.geo.json'))
polys = geo['geometry']['coordinates']
projected = []
for poly in polys:
    rings = [[proj(lon, lat) for lon, lat in ring] for ring in poly]
    projected.append(rings)

xs = [p[0] for poly in projected for ring in poly for p in ring]
ys = [p[1] for poly in projected for ring in poly for p in ring]
minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
W = 1000.0
scale = W / (maxx - minx)
H = (maxy - miny) * scale

def px(p): return ((p[0]-minx)*scale, (p[1]-miny)*scale)

parts = []
kept = 0
for poly in projected:
    rings = [[px(p) for p in ring] for ring in poly]
    shp = Polygon(rings[0], rings[1:]).buffer(0)
    if shp.is_empty or shp.area < 8: continue
    shp = shp.simplify(0.7, preserve_topology=True)
    geoms = [shp] if shp.geom_type == 'Polygon' else list(shp.geoms)
    for g in geoms:
        if g.area < 8: continue
        for ring in [g.exterior] + list(g.interiors):
            pts = list(ring.coords)
            d = 'M' + 'L'.join(f'{x:.1f},{y:.1f}' for x, y in pts[:-1]) + 'Z'
            parts.append(d)
        kept += 1
path = ''.join(parts)

js = f"""// Файл сгенерирован скриптом: контур России (Natural Earth 50m, общественное достояние),
// проекция Альберса (равновеликая коническая): стандартные параллели {LAT1:g} и {LAT2:g}, центр {LON0:g}° в.д.
export const VIEW_WIDTH = {W:g};
export const VIEW_HEIGHT = {H:.1f};
export const OUTLINE_PATH = "{path}";

const LON0 = {LON0}, N = {n!r}, C = {C!r}, RHO0 = {RHO0!r};
const SCALE = {scale!r}, MIN_X = {minx!r}, MIN_Y = {miny!r};

/** Переводит координаты (долгота, широта) в координаты SVG карты. */
export function project(lon, lat) {{
  let dl = lon - LON0;
  if (dl < -180) dl += 360;
  if (dl >= 180) dl -= 360;
  const rad = Math.PI / 180;
  const rho = Math.sqrt(C - 2 * N * Math.sin(lat * rad)) / N;
  const th = N * dl * rad;
  const x = rho * Math.sin(th);
  const y = rho * Math.cos(th) - RHO0;
  return [(x - MIN_X) * SCALE, (y - MIN_Y) * SCALE];
}}
"""
open('russia-outline.js', 'w', encoding='utf-8').write(js)
print('polygons kept', kept, 'path chars', len(path), 'H', round(H,1))

# проверка: рисуем контур и города
from PIL import Image, ImageDraw
img = Image.new('RGB', (int(W)+20, int(H)+20), 'white')
d = ImageDraw.Draw(img)
for poly in projected:
    ring = [px(p) for p in poly[0]]
    d.polygon([(x+10, y+10) for x, y in ring], fill=(235, 235, 235), outline=(120, 120, 120))
cities = {'Москва':(55.7558,37.6173),'СПб':(59.9343,30.3351),'Калининград':(54.7104,20.4522),'Пермь':(58.0105,56.2502),
 'Екатеринбург':(56.8389,60.6057),'Новосибирск':(55.0084,82.9357),'Красноярск':(56.0153,92.8932),'Якутск':(62.0355,129.6755),
 'Хабаровск':(48.4802,135.0719),'Владивосток':(43.1155,131.8855),'Магадан':(59.5638,150.8035),'Краснодар':(45.0355,38.9753),'Мурманск':(68.9585,33.0827)}
for name,(lat,lon) in cities.items():
    x,y = px(proj(lon,lat))
    d.ellipse((x+10-4,y+10-4,x+10+4,y+10+4), fill=(232,89,12))
img.save('check.png')
print({k: tuple(round(v) for v in px(proj(lo,la))) for k,(la,lo) in cities.items()})
