import * as geoip from 'geoip-country';

function isPrivateOrLocalIp(ip: string): boolean {
  const trimmed = ip.trim();
  if (trimmed === '127.0.0.1' || trimmed === '::1' || trimmed === 'localhost') return true;
  // 10.0.0.0/8
  if (/^10\./.test(trimmed)) return true;
  // 172.16.0.0/12
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(trimmed)) return true;
  // 192.168.0.0/16
  if (/^192\.168\./.test(trimmed)) return true;
  // Carrier-grade NAT 100.64.0.0/10
  if (/^100\.(6[4-9]|[7-9]\d|1[0-1]\d|12[0-7])\./.test(trimmed)) return true;
  // Link-local
  if (/^169\.254\./.test(trimmed)) return true;
  // IPv6 unique local fc00::/7 or fe80::/10
  if (/^f[cd][0-9a-f]{2}:/i.test(trimmed) || /^fe80:/i.test(trimmed)) return true;
  return false;
}

/**
 * Extracts the real client IP address from a Firebase Callable/HTTP request.
 * Prioritizes standard proxy headers (x-forwarded-for, etc.) set by Google Cloud / reverse proxies.
 */
export function extractClientIp(req: any): string | null {
  if (!req) return null;
  const headers = req.headers ?? {};

  // Standard reverse proxy / Cloud Run header
  const xForwardedFor = headers['x-forwarded-for'];
  if (typeof xForwardedFor === 'string') {
    const parts = xForwardedFor.split(',').map((s: string) => s.trim()).filter(Boolean);
    for (const part of parts) {
      if (!isPrivateOrLocalIp(part)) {
        return part;
      }
    }
    if (parts.length > 0) return parts[0];
  } else if (Array.isArray(xForwardedFor) && xForwardedFor.length > 0) {
    const parts = String(xForwardedFor[0]).split(',').map((s: string) => s.trim()).filter(Boolean);
    for (const part of parts) {
      if (!isPrivateOrLocalIp(part)) {
        return part;
      }
    }
    if (parts.length > 0) return parts[0];
  }

  // Cloudflare or GCP specific
  const cfIp = headers['cf-connecting-ip'];
  if (typeof cfIp === 'string' && cfIp.trim() && !isPrivateOrLocalIp(cfIp.trim())) {
    return cfIp.trim();
  }

  // Direct socket / Express IP
  const directIp = req.ip || req.connection?.remoteAddress || req.socket?.remoteAddress;
  if (typeof directIp === 'string' && directIp.trim()) {
    // Strip IPv6-mapped IPv4 prefix if present (e.g. ::ffff:103.106.240.71)
    const cleaned = directIp.replace(/^::ffff:/, '').trim();
    return cleaned;
  }

  return null;
}

/**
 * Resolves the 2-letter ISO country code (e.g. 'BD', 'TR', 'US') from request headers and IP.
 * Checks edge headers first (0 ms), then falls back to fast offline GeoLite lookup.
 */
export function resolveClientCountry(req: any): { country: string | null; ip: string | null } {
  if (!req) return { country: null, ip: null };
  const headers = req.headers ?? {};

  // 1. Edge headers (Google App Engine, Cloudflare, etc.)
  const edgeCountry = headers['x-appengine-country'] || headers['cf-ipcountry'] || headers['x-country-code'];
  if (typeof edgeCountry === 'string') {
    const trimmed = edgeCountry.trim().toUpperCase();
    if (trimmed.length === 2 && trimmed !== 'XX' && trimmed !== 'T1') {
      const ip = extractClientIp(req);
      return { country: trimmed, ip };
    }
  }

  // 2. Offline GeoIP lookup from IP
  const rawIp = extractClientIp(req);
  if (!rawIp) return { country: null, ip: null };
  const ip = rawIp.replace(/^::ffff:/, '').trim();

  try {
    const lookup = geoip.lookup(ip);
    const country = lookup?.country ? lookup.country.toUpperCase() : null;
    return { country, ip };
  } catch (_) {
    return { country: null, ip };
  }
}

const regionNames = new Intl.DisplayNames(['en'], { type: 'region' });

/**
 * Converts a 2-letter ISO country code (e.g. 'LA', 'KR', 'BR') to its full English country name (e.g. 'Laos', 'South Korea', 'Brazil').
 * If the input is already a full name or invalid, returns the input as-is.
 */
export function resolveCountryFullName(countryCodeOrName: string | null | undefined): string | null {
  if (!countryCodeOrName || typeof countryCodeOrName !== 'string') return null;
  const trimmed = countryCodeOrName.trim();
  if (trimmed.length === 2) {
    try {
      const name = regionNames.of(trimmed.toUpperCase());
      if (name) return name;
    } catch (_) {
      // Fallback
    }
  }
  return trimmed;
}

