// MoviesPlayerExtension content script for GeckoView
// Lightweight, low-CPU content script designed for low-memory TV devices.

// Player Compatibility & Safari Fullscreen Polyfill
(() => {
    const injectStyles = () => {
        if (!document.getElementById('movies-tv-compat')) {
            const style = document.createElement('style');
            style.id = 'movies-tv-compat';
            style.textContent = `
                video, iframe {
                    transform: none !important;
                    max-width: 100% !important;
                    border: none !important;
                }
            `;
            (document.head || document.documentElement).appendChild(style);
        }
    };
    if (document.head || document.documentElement) injectStyles();
    else document.addEventListener('DOMContentLoaded', injectStyles);

    /* Polyfill Safari-specific fullscreen API for sites that call it */
    if (!HTMLVideoElement.prototype.webkitEnterFullScreen) {
        HTMLVideoElement.prototype.webkitEnterFullScreen = function() {
            if (this.requestFullscreen) {
                this.requestFullscreen().catch(() => {});
            } else if (this.webkitRequestFullScreen) {
                this.webkitRequestFullScreen();
            }
        };
        HTMLVideoElement.prototype.webkitEnterFullscreen = HTMLVideoElement.prototype.webkitEnterFullScreen;
    }
})();

// Viewport Unit Fallback Polyfill (only runs if broken)
(() => {
    if (window.__moviesViewportUnitPolyfill) return;
    window.__moviesViewportUnitPolyfill = true;

    const checkNeed = () => {
        const test = document.createElement('div');
        test.style.cssText = 'position:fixed;top:0;height:100vh;opacity:0;pointer-events:none;';
        (document.body || document.documentElement).appendChild(test);
        const height = test.getBoundingClientRect().height;
        test.remove();
        return height === 0 && window.innerHeight > 0;
    };

    const applyPolyfill = () => {
        if (!checkNeed()) return; // Engine handles vh correctly!

        console.warn("[MoviesPlayer] Engine has broken 100vh! Applying polyfill...");
        const updateVhVariable = () => {
            document.documentElement.style.setProperty('--movies-vh', (window.innerHeight / 100) + 'px');
        };
        const fixContainingBlock = () => {
            const body = document.body;
            if (!body) return;
            if (getComputedStyle(body).position === 'static') {
                body.style.setProperty('position', 'relative', 'important');
            }
            body.style.setProperty('height', window.innerHeight + 'px', 'important');
            body.style.setProperty('min-height', window.innerHeight + 'px', 'important');
        };

        updateVhVariable();
        fixContainingBlock();
        window.addEventListener('resize', () => {
            updateVhVariable();
            fixContainingBlock();
        });
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', applyPolyfill);
    } else {
        applyPolyfill();
    }
})();
