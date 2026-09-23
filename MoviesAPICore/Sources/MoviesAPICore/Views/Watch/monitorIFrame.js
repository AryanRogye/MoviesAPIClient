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
      message?.data?.currentTime !== undefined &&
      message?.data?.duration !== undefined
    ) {
      window.webkit?.messageHandlers?.iframeDebug?.postMessage({
        currentTime: message.data.currentTime,
        duration: message.data.duration
      });
      return;
    }

    if (
      message?.currentTime !== undefined &&
      message?.duration !== undefined
    ) {
      window.webkit?.messageHandlers?.iframeDebug?.postMessage({
        currentTime: message.currentTime,
        duration: message.duration
      });
      return;
    }

    if (
      message?.type === "PLAYER_EVENT" ||
      message?.event === "timeupdate"
    ) {
      window.webkit?.messageHandlers?.iframeDebug?.postMessage(message.data);
    }
  });
})();
