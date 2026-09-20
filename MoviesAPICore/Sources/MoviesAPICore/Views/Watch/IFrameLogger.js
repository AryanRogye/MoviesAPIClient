//
//  IFrameLogger.js
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/20/26.
//

(() => {
    window.addEventListener("message", (event) => {
        let data;

        try {
            data = JSON.stringify(event.data);
        } catch {
            data = String(event.data);
        }

        window.webkit?.messageHandlers?.iframeLog?.postMessage({
            type: "MESSAGE",
            url: location.href,
            origin: event.origin,
            data: data
        });
    });
})();
