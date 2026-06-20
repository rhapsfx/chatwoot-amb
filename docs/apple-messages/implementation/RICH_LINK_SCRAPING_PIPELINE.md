# Rich Link Scraping Pipeline — Implementation Guide

## Problem Statement

Apple Messages rich links require a `title` and an embedded image (`assets.image`, max 200KB, JPEG or PNG). Sites with bot-detection (Akamai, Cloudflare) block plain HTTP clients, causing:

- **Booking.com**: title "Booking.com", assets `{}` (CDN image download silently failed)
- **Fnac.com**: title "fnac.com", image = Akamai tracking pixel (real page has JSON-LD Product schema)
- **"Access Denied" / "403 Forbidden"**: error-page titles sent verbatim to Apple MSP
- **apple.com/ipad**: correct title but 284KB PNG rejected → fell back to 3KB Google favicon

---

## Architecture — Four-Level Priority Chain

```
Level 1  Frontend OG data
         (frontend pre-scraped via appleMessagesRichLink.js)
         ↓ only if title is usable (not bare domain, not error page, image not tracking pixel)

Level 2  HTTParty + Nokogiri
         Safari UA, follows redirects, Nokogiri parses OG meta + JSON-LD
         ↓ only if og_result_usable? returns false (bot-challenge page, error page, bare domain)

Level 3  Playwright stealth scraper  (services/playwright-scraper/)
         Real Chromium + puppeteer-extra-plugin-stealth, bypasses Akamai/Cloudflare fingerprinting
         ↓ only if both Level 1 & 2 fail

Level 4  URL slug + brand derivation  (extract_title_from_url)
         Walks URL path segments in reverse to find a descriptive slug,
         humanises and appends brand name derived from og:site_name or domain
```

**Key rule**: Each level is only tried when the previous level fails `og_result_usable?`. A result is usable when:
- Title is present
- Title is not an error-page string (access denied, 403, not found, cloudflare, captcha, etc.)
- Title is not the bare domain (e.g. "fnac.com")
- At least one of image_url or description is present

---

## Files

### Backend — Ruby

| File | Role |
|---|---|
| `app/services/apple_messages_for_business/send_rich_link_service.rb` | Orchestrator: decides which OG data to trust, builds assets, sends to Apple MSP |
| `app/services/apple_messages_for_business/open_graph_parser_service.rb` | HTTParty + Nokogiri scraper with Playwright fallback |
| `app/services/apple_messages_for_business/playwright_scraper_client.rb` | HTTP client that calls the Node scraper microservice |

### Node.js Microservice

| File | Role |
|---|---|
| `services/playwright-scraper/server.js` | Express server, single warm Chromium instance, `/scrape` and `/health` endpoints |
| `services/playwright-scraper/package.json` | Dependencies: playwright, playwright-extra, puppeteer-extra-plugin-stealth, express |

### Infrastructure

| File | Change |
|---|---|
| `Procfile.dev` | `scraper: cd services/playwright-scraper && node server.js` |
| `docker-compose.production.yml` | `playwright-scraper` service (`mcr.microsoft.com/playwright:v1.51.0-jammy`) |
| `script/dev-server.sh` | `start_scraper` / `stop_scraper` wired into start/stop/restart |

### Specs

| File | Coverage |
|---|---|
| `spec/services/apple_messages_for_business/send_rich_link_service_spec.rb` | `frontend_og_data_usable?`, `error_page_title?`, `extract_title_from_url`, `build_assets` cascade, image compression, video, OG priority chain |
| `spec/services/apple_messages_for_business/open_graph_parser_service_spec.rb` | Happy path, bot-challenge → Playwright fallback, JSON-LD extraction, Apple Maps, `og_result_usable?` edge cases, favicon priority |

---

## Key Fixes Implemented

### 1. Cascading Image Asset Fallback (Booking.com fix)

`build_assets` in `send_rich_link_service.rb` now tries candidates in order:
```
image_data → image_url → favicon (upgraded) → Google favicon (128px)
```
Tracking pixels are filtered before the candidate list is built:
```ruby
.reject { |s| s.match?(%r{/akam/|/pixel_|/beacon\.|1x1|tracking}) }
```
First candidate that downloads successfully wins. Previously the service would stop at the first failure.

### 2. Error-Page Title Detection + URL Slug Fallback

`error_page_title?` matches:
```
/\b(error|404|403|not found|access denied|forbidden|blocked|page not found|something went wrong)\b/i
```

`extract_title_from_url(url, site_name)` derives title from URL path when page title is blank, a bare domain, or an error page:
- Walks path segments in reverse (deepest first)
- Requires segment to have a letter, a hyphen/underscore, and be >4 chars (skips numeric IDs and locale codes)
- Strips extension and locale suffixes (`.html`, `.en-gb`)
- Humanises slug and appends brand

Examples:
```
/hotel/hu/7seasons-apartments-budapest.en-gb.html → "7seasons Apartments Budapest – Booking"
/Drone-Dji-Avata-360-Gris-RC-2/a22742407/w-4      → "Drone Dji Avata 360 Gris Rc 2 – Fnac"
/fr_fr/bague-josephine-aigrette-083590             → "Bague Josephine Aigrette – Chaumet"
```

`extract_brand_name` strips TLD suffixes from `og:site_name` ("Fnac.com" → "Fnac") and falls back to first domain label.

### 3. Image Compression Instead of Rejection (apple.com fix)

`compress_image_to_limit` uses ImageProcessing::MiniMagick to progressively lower JPEG quality (85 → 70 → 55 → 40) until under the 200KB Apple limit, instead of silently discarding the image:
```ruby
[85, 70, 55, 40].each do |quality|
  processed = ImageProcessing::MiniMagick.source(tempfile).convert('jpeg').saver(quality: quality).call
  return File.binread(processed.path) if result.bytesize <= APPLE_IMAGE_SIZE_LIMIT
end
```

### 4. Favicon Quality Upgrade

`fetch_best_domain_icon` is now called in `build_assets` before using the raw favicon:
```ruby
raw_favicon = content_attrs['favicon_url']
best_favicon = raw_favicon.present? ? fetch_best_domain_icon(raw_favicon) : google_favicon
```
`fetch_best_domain_icon` probes standard apple-touch-icon paths (`/apple-touch-icon-180x180.png`, `/apple-touch-icon.png`, etc.) before falling back to Google's 128px favicon service. This replaces pixelated 16px `.ico` files with 180px PNGs.

### 5. Playwright Microservice Design

**Single warm Chromium instance** reused across requests (not relaunched per request).

**Stealth**: `playwright-extra` + `puppeteer-extra-plugin-stealth` patches WebGL, `navigator.webdriver`, Chrome runtime, UA consistency.

**Platform-aware flags**: `--no-zygote` is Linux-only (causes crash on macOS).

**Resource blocking**: images, fonts, media, stylesheets are aborted to speed up navigation. Only HTML and JS load (sufficient for OG meta + JSON-LD extraction).

**Wait strategy**: waits for either `meta[property="og:title"]` OR `script[type="application/ld+json"]` with a 4s timeout, then a 200ms settle pause. This handles both sites that inject OG meta via JS and sites that only have server-rendered JSON-LD (like Fnac).

**Health endpoint**: `/health` calls `getBrowser()` (not stale `browser` var) to show real connection state.

### 6. JSON-LD Name Extraction in Playwright (Fnac fix)

Fnac omits `og:title` and their product page's initial `<title>` is the bare domain "fnac.com" (updated by JS after load). The real product data is in a server-rendered JSON-LD Product schema.

`extractMetadata` in `server.js` now:
1. Extracts `schemaTitle` from JSON-LD (`schema.name || schema.headline`, recursing into `@graph`)
2. Detects bare-domain titles: `/^[\w-]+\.(com|fr|de|it|es|co\.uk|net|org|io)$/i`
3. Resolves title as: `ogTitle || (titleLooksGeneric ? schemaTitle : null) || pageTitle`

```javascript
function extractSchemaTitle(schema) {
  if (!schema || typeof schema !== 'object') return null;
  if (Array.isArray(schema['@graph'])) {
    for (const node of schema['@graph']) {
      const name = extractSchemaTitle(node);
      if (name) return name;
    }
  }
  return schema.name || schema.headline || null;
}
```

---

## Data Flow — Fnac Example

```
1. Frontend scrapes fnac.com → gets bot-challenge page
   title: "fnac.com", image: /akam/13/pixel_... (Akamai tracking pixel)
   → frontend_og_data_usable? → false (title = bare domain, image = tracking pixel)

2. HTTParty + Nokogiri → bot-challenge page
   "Found 0 JSON-LD scripts" (expected — bot-challenge has no JSON-LD)
   → og_result_usable? → false (title = bare domain)

3. Playwright stealth scraper → real product page
   document.title = "fnac.com" (SPA before JS update), og:title absent
   JSON-LD: {"@type":"Product","name":"Drone Dji Avata 360 Gris + RC 2","image":[...]}
   → schemaTitle = "Drone Dji Avata 360 Gris + RC 2"
   → titleLooksGeneric = true (matches bare-domain pattern)
   → resolvedTitle = schemaTitle ✓
   → schemaImage = "https://static.fnac-static.com/drone.jpg" ✓
   → og_result_usable? → true

4. build_rich_link_data assembles:
   title: "Drone Dji Avata 360 Gris + RC 2"
   image: downloaded from Fnac CDN, compressed if >200KB
```

---

## Known Limitations

- **Fnac / Akamai**: Playwright stealth bypasses most bot detection. However, Akamai's JA3 TLS fingerprinting can still detect Playwright's TLS stack (not patchable by stealth plugin). If Playwright also gets the bot-challenge page, the URL slug fallback (`extract_title_from_url`) provides a reasonable title but no product image.

- **Image blocking caveat**: Blocking image resources during navigation may occasionally interfere with bot-detection verification flows that use image requests as proof-of-work. If a site consistently fails Playwright scraping, consider whether its Akamai challenge requires same-domain image/beacon requests.

- **200KB Apple limit**: Compression targets JPEG quality 40 as minimum. Very high-resolution images that cannot be compressed below 200KB at quality 40 are skipped and the next candidate is tried.

- **Playwright on macOS dev**: `--no-zygote` flag is excluded on macOS (Linux-only). The stealth effectiveness may differ between local macOS and production Linux (Docker).

---

## Dev Server Integration

```bash
./script/dev-server.sh start          # starts Rails + Sidekiq + Playwright scraper
./script/dev-server.sh restart        # restarts all + verifies connectivity
./script/dev-server.sh restart --quick  # restarts all, skips connectivity check
```

Scraper PID: `tmp/pids/scraper.pid`  
Scraper log: `log/playwright-scraper.log`  
Health check: `curl http://localhost:3001/health`  
Environment variable: `PLAYWRIGHT_SCRAPER_URL` (default: `http://localhost:3001`)

---

## Production Deployment

```yaml
# docker-compose.production.yml
playwright-scraper:
  image: mcr.microsoft.com/playwright:v1.51.0-jammy
  command: sh -c "npm install --omit=dev && node server.js"
  environment:
    - PORT=3001
  networks:
    - backend_net
  mem_limit: 512m
```

Web and worker containers receive `PLAYWRIGHT_SCRAPER_URL: http://playwright-scraper:3001`.

The `PlaywrightScraperClient` returns `nil` gracefully when the service is unavailable, allowing the pipeline to fall through to the URL slug fallback without raising errors.
