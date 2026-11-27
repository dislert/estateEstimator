# EstateEstimator — frontend

Pure HTML, CSS and JavaScript ES modules. No npm or build step. MapLibre GL JS loads from a public CDN and uses OpenFreeMap Positron vector tiles with a warm palette. No API key is required. Internet access and WebGL are required for the map. Map initialization is in js/map.js. English UI. No mock data, fake responses or simulated persistence.

## Preview
From this directory run `python -m http.server 5500` and open http://localhost:5500. The visual interface and map can be inspected; authentication requires the actual backend and same-origin setup below. Do not open index.html with file:// because JS modules require HTTP.

## Integrate with Spring Boot
Copy index.html, css/, js/ and assets/ to `server/src/main/resources/static/` in the estateEstimator repository. In SecurityConfig.java allow public access to the static assets before `.anyRequest().authenticated()`:

```java
.requestMatchers(HttpMethod.GET, "/", "/index.html", "/css/**", "/js/**", "/assets/**").permitAll()
```

Keep protected API routes protected. Rebuild the Docker application and open http://localhost:8080/ (or configured APP_PORT). The existing API is used through relative URLs. No CORS configuration is necessary for same-origin deployment. If using a separate development origin, configure CORS and API_BASE explicitly.

## Current integration
POST /api/v1/auth/register, /login, /logout; GET /api/v1/users/me. JWT is held in sessionStorage for this MVP (accessible to JavaScript; avoid XSS and revisit token strategy for production). API errors are mapped into English. No credentials or tokens are fabricated.

## Future functionality
Catalog/filter controls, property details, comparison, listing form, requests, chat, admin, and recovery are visual scaffolds only. Unavailable operations are disabled and data is marked No data/unavailable. No fake listings, charts, messages, or successful actions. No local drafts. Property details route is #property; later connect it to a real listing ID and API. UI roles are not a security boundary; server-side authorization remains mandatory. Backend has not been executed or integration-tested in this environment.

## Map troubleshooting
Use HTTP, not file://. Enable browser hardware acceleration and check DevTools (F12) Console for MapLibre errors. The map falls back to OpenStreetMap raster tiles if the initial vector map fails; both require internet, and MapLibre requires WebGL.
