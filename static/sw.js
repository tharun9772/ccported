function isCacheableRequest(request) {
    const url = new URL(request.url);

    // Don't cache anything if running on localhost
    if (
        url.hostname === 'localhost' ||
        url.hostname === '127.0.0.1' ||
        url.hostname === '[::1]'
    ) {
        return false;
    }

    // Never cache txt files, change often
    if (url.pathname.endsWith('.txt')) {
        return false;
    }

    // Only cache GET requests
    if (request.method !== 'GET') {
        return false;
    }

    // Check if domain is allowed for cross-origin caching
    const isAllowedDomain = ALLOWED_DOMAINS.some(domain => url.hostname.includes(domain));
    const isBlacklisted = BLACKLIST.some(domain => url.hostname.includes(domain));
    if (isBlacklisted) {
        return false;
    }
    // Allow caching for origin domain or explicitly allowed domains
    const isSameOrigin = url.origin === self.location.origin;
    if (!isSameOrigin && !isAllowedDomain) {
        return false;
    }

    // Cache based on file extensions (website - non game- assets)
    const extensions = [
        '.html', '.js', '.css', '.json',
        '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg',
        '.woff', '.woff2', '.ttf', '.otf',
        '.mp3', '.ogg', '.wav',
        '.mp4', '.webm'
    ];

    if (extensions.some(ext => url.pathname.endsWith(ext))) {
        return true;
    }

    return false;
}
