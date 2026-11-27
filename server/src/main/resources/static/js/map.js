const MAP_STYLE = 'https://tiles.openfreemap.org/styles/positron';
const VIRGINIA_CENTER = [-78.6, 37.55];

// Apply warm colors to the existing vector layers without changing their data.
function applyCoffeeStyle(style) {
    for (const layer of style.layers || []) {
        const id = layer.id.toLowerCase();
        const source = (layer['source-layer'] || '').toLowerCase();
        const paint = layer.paint || (layer.paint = {});

        if (layer.type === 'background') {
            paint['background-color'] = '#f5efe5';
        } else if (layer.type === 'fill') {
            if (source === 'water') {
                paint['fill-color'] = '#c7d9dc';
            } else if (source === 'building') {
                paint['fill-color'] = '#dfd0bf';
            } else if (id.includes('park') || id.includes('wood') || id.includes('grass')) {
                paint['fill-color'] = '#dce2ce';
            }
        } else if (layer.type === 'line' && source === 'transportation') {
            if (id.includes('rail') || id.includes('ferry')) continue;
            paint['line-color'] = id.includes('casing') ? '#cbb9a5' : '#fffaf3';
        }
    }
    return style;
}

export function initializeMap(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return null;

    if (!window.maplibregl || typeof window.maplibregl.Map !== 'function') {
        container.textContent = 'Map library failed to load. Check your internet connection.';
        return null;
    }

    let map;
    let loaded = false;
    let fallbackUsed = false;
    let timer;
    const status = document.createElement('div');
    status.className = 'map-status';
    status.setAttribute('role', 'status');
    status.textContent = 'Loading map…';

    try {
        map = new maplibregl.Map({
            container: containerId,
            style: MAP_STYLE,
            center: VIRGINIA_CENTER,
            zoom: 6.6,
            pitch: 0,
            bearing: 0,
            maxZoom: 19,
            attributionControl: true
        });

        container.append(status);
        map.addControl(new maplibregl.NavigationControl(), 'top-right');
        map.addControl(new maplibregl.ScaleControl({ unit: 'imperial' }), 'bottom-left');
        map.addControl(new maplibregl.FullscreenControl(), 'top-right');

        map.once('load', () => {
            loaded = true;
            // Recolor paint properties in place so tile sources and attribution remain intact.
            clearTimeout(timer);
            try {
            const style = applyCoffeeStyle(map.getStyle());
            for (const layer of style.layers) {
                for (const property of ['background-color', 'fill-color', 'line-color']) {
                    const value = layer.paint?.[property];
                    if (typeof value === 'string' && map.getPaintProperty(layer.id, property) !== value &&
                        ((layer.type === 'background' && property === 'background-color') ||
                         (layer.type === 'fill' && property === 'fill-color') ||
                         (layer.type === 'line' && property === 'line-color'))) {
                        map.setPaintProperty(layer.id, property, value);
                    }
                }
            }
            } catch (error) {
                console.warn('Map styling failed:', error);
            }
            status.remove();
        });

        function useFallback() {
            if (loaded || fallbackUsed) return;
            fallbackUsed = true;
            status.textContent = 'Loading alternative street map…';
            map.setStyle({
                version: 8,
                sources: {
                    osm: {
                        type: 'raster',
                        tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
                        tileSize: 256,
                        maxzoom: 19,
                        attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>'
                    }
                },
                layers: [{ id: 'osm', type: 'raster', source: 'osm' }]
            });
        }

        map.on('error', (event) => {
            console.error('MapLibre:', event.error || event);
            if (!loaded && !fallbackUsed) useFallback();
            else if (!loaded) status.textContent = 'Map data unavailable. Check your connection.';
        });

        map.on('idle', () => {
            loaded = true;
            clearTimeout(timer);
            status.remove();
        });

        timer = setTimeout(useFallback, 12000);
        map.on('remove', () => clearTimeout(timer));
        requestAnimationFrame(() => map.resize());

        // No property markers until the real catalog API provides coordinates.
        return map;
    } catch (error) {
        if (map) map.remove();
        console.error('Map initialization failed:', error);
        container.textContent = 'Map unavailable. Check WebGL support and the browser console.';
        return null;
    }
}
