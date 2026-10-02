//
//  WebView+load.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/2/26.
//

import WebKit

extension WKWebView {
    @available(macOS, introduced: 26.0, obsoleted: 27.0)
    public func load(_ url: URL) {
        let urlRequest = URLRequest(url: url)
        self.load(urlRequest)
    }
}
