//
//  monitorIFrame.js
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/20/26.
//

(() => {
    window.addEventListener("message", (event) => {
        let message;

        try {
            message =
            typeof event.data === "string"
            ? JSON.parse(event.data)
            : event.data;
        } catch {
            return;
        }

        if (
            message?.type !== "PLAYER_EVENT" ||
            message?.data?.event !== "timeupdate"
            ) {
                return;
            }

        window.webkit?.messageHandlers?.iframeDebug?.postMessage(message.data);
    });
})();
