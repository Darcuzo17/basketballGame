const topo = require('world-atlas/countries-50m.json');
const { feature } = require('topojson-client');
const fc = feature(topo, topo.objects.countries);
const rus = fc.features.find(f => f.properties.name === 'Russia');
require('fs').writeFileSync('rus50.geo.json', JSON.stringify(rus));
console.log(rus.geometry.type, rus.geometry.coordinates.length, 'polygons');
