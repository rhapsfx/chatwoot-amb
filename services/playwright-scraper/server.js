'use strict';

const express = require('express');
const { chromium } = require('playwright-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

chromium.use(StealthPlugin());

const PORT = parseInt(process.env.PORT || '3001', 10);
const NAV_TIMEOUT_MS = 15_000;
const REQUEST_TIMEOUT_MS = 20_000;

const app = express();
app.use(express.json());

let browser = null;

const isLinux = process.platform === 'linux';

async function getBrowser() {
  if (browser && browser.isConnected()) return browser;

  console.log('[scraper] Launching Chromium with stealth...');
  const args = [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--disable-accelerated-2d-canvas',
    '--no-first-run',
    '--disable-gpu',
  ];
  // --no-zygote is Linux-only; causes immediate crash on macOS
  if (isLinux) args.push('--no-zygote');

  browser = await chromium.launch({ headless: true, args });

  browser.on('disconnected', () => {
    console.log('[scraper] Browser disconnected, will relaunch on next request');
    browser = null;
  });

  return browser;
}

// Extract all OG/Twitter meta + JSON-LD + favicon from the live DOM
async function extractMetadata(page) {
  return page.evaluate(() => {
    const meta = (prop, attr = 'content') => {
      const el =
        document.querySelector(`meta[property="${prop}"]`) ||
        document.querySelector(`meta[name="${prop}"]`);
      return el ? el.getAttribute(attr) : null;
    };

    // Favicon priority: apple-touch-icon > sized icon > shortcut icon > icon
    const faviconSelectors = [
      'link[rel="apple-touch-icon"]',
      'link[rel="apple-touch-icon-precomposed"]',
      'link[rel="icon"][sizes]',
      'link[rel="shortcut icon"]',
      'link[rel="icon"]',
    ];
    let faviconHref = null;
    for (const sel of faviconSelectors) {
      const el = document.querySelector(sel);
      if (el && el.href) { faviconHref = el.href; break; }
    }

    // JSON-LD image + title fallback
    let schemaImage = null;
    let schemaTitle = null;
    const schemaScripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (const script of schemaScripts) {
      try {
        const parsed = JSON.parse(script.textContent || '');
        const schemas = Array.isArray(parsed) ? parsed : [parsed];
        for (const schema of schemas) {
          if (!schemaImage) {
            const img = extractSchemaImage(schema);
            if (img) schemaImage = img;
          }
          if (!schemaTitle) {
            const name = extractSchemaTitle(schema);
            if (name) schemaTitle = name;
          }
        }
        if (schemaImage && schemaTitle) break;
      } catch (_) { /* ignore parse errors */ }
    }

    function extractSchemaImage(schema) {
      if (!schema || typeof schema !== 'object') return null;
      if (Array.isArray(schema['@graph'])) {
        for (const node of schema['@graph']) {
          const img = extractSchemaImage(node);
          if (img) return img;
        }
      }
      const raw = schema.image;
      if (typeof raw === 'string') return raw;
      if (raw && typeof raw === 'object' && !Array.isArray(raw)) return raw.url || raw.contentUrl || null;
      if (Array.isArray(raw)) {
        const first = raw[0];
        if (typeof first === 'string') return first;
        if (first) return first.url || first.contentUrl || null;
      }
      return null;
    }

    function extractSchemaTitle(schema) {
      if (!schema || typeof schema !== 'object') return null;
      if (Array.isArray(schema['@graph'])) {
        for (const node of schema['@graph']) {
          const name = extractSchemaTitle(node);
          if (name) return name;
        }
      }
      // Product, Article, Book, Movie, Event all use name/headline
      return schema.name || schema.headline || null;
    }

    // Determine the best title: prefer og:title, then JSON-LD name if document.title
    // looks like a bare domain or bot-challenge page, then document.title as last resort
    const ogTitle = meta('og:title');
    const pageTitle = document.title || null;
    const titleLooksGeneric = !ogTitle && pageTitle && (
      /^[\w-]+\.(com|fr|de|it|es|co\.uk|net|org|io)$/i.test(pageTitle.trim()) ||
      /\b(access denied|403|checking your browser|just a moment|ddos|please wait)\b/i.test(pageTitle)
    );
    const resolvedTitle = ogTitle || (titleLooksGeneric ? schemaTitle : null) || pageTitle;

    return {
      title: resolvedTitle || null,
      description:
        meta('og:description') ||
        meta('description') ||
        null,
      image_url:
        meta('og:image') ||
        meta('og:image:url') ||
        meta('twitter:image') ||
        schemaImage ||
        null,
      video_url:
        meta('og:video') ||
        meta('og:video:url') ||
        meta('og:video:secure_url') ||
        meta('twitter:player:stream') ||
        null,
      video_mime_type:
        meta('og:video:type') ||
        null,
      site_name:
        meta('og:site_name') ||
        null,
      favicon_url: faviconHref || null,
      canonical_url:
        document.querySelector('link[rel="canonical"]')?.href ||
        meta('og:url') ||
        null,
    };
  });
}

app.post('/scrape', async (req, res) => {
  const { url } = req.body || {};

  if (!url || typeof url !== 'string') {
    return res.status(400).json({ success: false, error: 'url is required' });
  }

  console.log(`[scraper] Scraping: ${url}`);
  const startedAt = Date.now();
  let page = null;

  const timeout = setTimeout(() => {
    if (page) page.close().catch(() => {});
    if (!res.headersSent) {
      res.status(504).json({ success: false, error: 'Request timed out' });
    }
  }, REQUEST_TIMEOUT_MS);

  try {
    const b = await getBrowser();
    page = await b.newPage();

    // Block images/fonts/media to speed up navigation — we only need HTML/JS
    await page.route('**/*', (route) => {
      const type = route.request().resourceType();
      if (['image', 'font', 'media', 'stylesheet'].includes(type)) {
        route.abort();
      } else {
        route.continue();
      }
    });

    // Set a realistic viewport and UA (stealth plugin also handles UA, but belt-and-suspenders)
    await page.setViewportSize({ width: 1280, height: 800 });

    let finalUrl = url;
    try {
      const response = await page.goto(url, {
        waitUntil: 'load',
        timeout: NAV_TIMEOUT_MS,
      });
      finalUrl = page.url();

      // If we got a non-200 status, log it but continue — page may still have OG tags
      if (response && !response.ok()) {
        console.warn(`[scraper] HTTP ${response.status()} for ${url}`);
      }
    } catch (navError) {
      // Navigation timeout or network error — try to extract whatever loaded
      console.warn(`[scraper] Navigation error for ${url}: ${navError.message}`);
      finalUrl = page.url() || url;
    }

    // Wait for either og:title OR JSON-LD structured data to appear.
    // Sites like Fnac omit og:title but have server-rendered JSON-LD Product schema.
    // Timeout is intentionally short — if neither appears we still extract whatever is there.
    await Promise.race([
      page.waitForSelector('meta[property="og:title"]', { timeout: 4000 }),
      page.waitForSelector('script[type="application/ld+json"]', { timeout: 4000 }),
    ]).catch(() => {});
    // Small pause for any remaining async meta updates
    await page.waitForTimeout(200).catch(() => {});

    const meta = await extractMetadata(page);

    // Fetch the og:image from within the browser's network context so CDN-protected
    // images (booking.com, etc.) are accessible — same cookies/session as the page load.
    let imageData = null;
    let imageMimeType = null;
    if (meta.image_url) {
      try {
        const imgRes = await page.request.get(meta.image_url, {
          timeout: 8000,
          headers: { Referer: url, Accept: 'image/webp,image/apng,image/*,*/*;q=0.8' },
        });
        if (imgRes.ok()) {
          const contentType = (imgRes.headers()['content-type'] || 'image/jpeg').split(';')[0].trim();
          if (contentType.startsWith('image/') && !contentType.includes('gif')) {
            const buffer = await imgRes.body();
            if (buffer.length > 0 && buffer.length <= 204800) { // 200KB cap
              imageData = buffer.toString('base64');
              imageMimeType = contentType;
            }
          }
        }
      } catch (e) {
        console.warn(`[scraper] Could not fetch image for ${url}: ${e.message}`);
      }
    }

    clearTimeout(timeout);

    if (res.headersSent) return;

    const elapsed = Date.now() - startedAt;
    console.log(`[scraper] Done in ${elapsed}ms — title: ${meta.title?.substring(0, 60)}`);

    res.json({
      success: true,
      url: meta.canonical_url || finalUrl,
      title: meta.title,
      description: meta.description,
      image_url: meta.image_url,
      image_data: imageData,
      image_mime_type: imageMimeType,
      video_url: meta.video_url,
      video_mime_type: meta.video_mime_type,
      favicon_url: meta.favicon_url,
      site_name: meta.site_name,
    });
  } catch (err) {
    clearTimeout(timeout);
    console.error(`[scraper] Error scraping ${url}: ${err.message}`);
    if (!res.headersSent) {
      res.status(500).json({ success: false, error: err.message });
    }
  } finally {
    if (page) {
      page.close().catch(() => {});
    }
  }
});

// Lightweight image fetch — uses browser network context to bypass CDN protection.
// Does NOT load the full page; creates a minimal context with the right Referer.
app.post('/fetch-image', async (req, res) => {
  const { image_url, referer } = req.body || {};
  if (!image_url || typeof image_url !== 'string') {
    return res.status(400).json({ success: false, error: 'image_url is required' });
  }

  let context = null;
  try {
    const b = await getBrowser();
    context = await b.newContext({
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15',
    });

    const imgRes = await context.request.get(image_url, {
      timeout: 10000,
      headers: {
        Referer: referer || image_url,
        Accept: 'image/webp,image/apng,image/*,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    });

    if (!imgRes.ok()) {
      return res.json({ success: false, error: `HTTP ${imgRes.status()}` });
    }

    const contentType = (imgRes.headers()['content-type'] || 'image/jpeg').split(';')[0].trim();
    if (!contentType.startsWith('image/') || contentType.includes('gif')) {
      return res.json({ success: false, error: `Unsupported type: ${contentType}` });
    }

    const buffer = await imgRes.body();
    if (buffer.length === 0 || buffer.length > 204800) {
      return res.json({ success: false, error: `Image size out of range: ${buffer.length}` });
    }

    console.log(`[scraper] fetch-image OK — ${buffer.length} bytes (${contentType})`);
    res.json({ success: true, image_data: buffer.toString('base64'), image_mime_type: contentType });
  } catch (err) {
    console.error(`[scraper] fetch-image error: ${err.message}`);
    res.status(500).json({ success: false, error: err.message });
  } finally {
    if (context) context.close().catch(() => {});
  }
});

app.get('/health', async (_req, res) => {
  try {
    const b = await getBrowser();
    res.json({ ok: true, browser_connected: b.isConnected() });
  } catch (e) {
    res.status(503).json({ ok: false, browser_connected: false, error: e.message });
  }
});

// Pre-warm browser on startup
getBrowser()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`[scraper] Listening on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error('[scraper] Failed to launch browser:', err.message);
    process.exit(1);
  });
