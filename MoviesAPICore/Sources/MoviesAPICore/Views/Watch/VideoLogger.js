//
//  VideoLogger.js
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/23/26.
//

/// Just Going To Log Video Values
//(() => {
//  const video = document.querySelectorAll("video");
//
//  if (video.length === 0) return;
//
//  window.webkit?.messageHandlers?.videoLogger?.postMessage(video);
//  
//})();

(() => {

  function dumpVideo(video) {
    const result = {};
    
    for (const key in video) {
      try {
        const value = video[key];
        
        if (
          typeof value === "function" ||
          typeof value === "object"
        ) {
          continue;
        }
        
        // JSON cannot represent NaN / ±Infinity
        if (
          typeof value === "number" &&
          !Number.isFinite(value)
        ) {
          result[key] = null;
          continue;
        }
        
        result[key] = value;
      } catch {
        // Property couldn't be read
      }
    }
    
    return result;
  }
  

  function findVideo() {
    const video = document.querySelector("video");

    if (!video) return false;

    window.webkit?.messageHandlers?.videoLogger?.postMessage(
      dumpVideo(video)
    );
    
    return true;
  }

  findVideo();

  setInterval(findVideo, 20000);

  // // Already exists
  // if (findVideo()) return;

  // // Look for a video to be true
  // const observer = new MutationObserver(() => {
  //   setInterval(() => {
  //     findVideo()
  //   }, 5000)
  // });

  // // assign it
  // observer.observe(document.documentElement, {
  //   childList: true,
  //   subtree: true
  // });
  
})();
