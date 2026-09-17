//
//  BlockingService.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation
import WebKit

@Observable
@MainActor
public final class BlockingService {
    let networkFilteringService = NetworkFilteringService()
    let popupFilteringService = PopupFilteringService()

    public var isCompilingNetworkFiltering: Bool = false
    public var appliedNetworkFiltering = false
    public var hasAttemptedNetworkFiltering = false
    public var networkFilterError: String? = nil
    private var networkFilterTask: Task<Void, Never>?

    public var appliedPopupBlocking = false
    public var popupBlockingError: String? = nil

    public private(set) var isNetworkFilteringReady = false

    public init() {
        preloadNetworkFilters()
    }

    public func attachPopupBlocking(to config: WKWebViewConfiguration) {
        do {
            let javascript = try popupFilteringService.getJavascript()
            let script = WKUserScript(
                source: javascript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false,
                in: .defaultClient
            )
            config.userContentController.addUserScript(script)
            appliedPopupBlocking = true
        } catch {
            self.popupBlockingError = error.localizedDescription
            appliedPopupBlocking = false
        }
    }

    public func preloadNetworkFilters() {
        networkFilterTask = Task {
            isCompilingNetworkFiltering = true

            defer {
                isCompilingNetworkFiltering = false
                networkFilterTask = nil
            }

            do {
                _ = try await networkFilteringService.compileNetworkRules()
                try Task.checkCancellation()

                isNetworkFilteringReady = true
                networkFilterError = nil
            } catch is CancellationError {
                return
            } catch {
                isNetworkFilteringReady = false
                networkFilterError = error.localizedDescription
            }
        }
    }

    public func attachNetworkFilters(to webView: WKWebView) {
        if appliedNetworkFiltering || hasAttemptedNetworkFiltering {
            return
        }

        /// Check Cache first
        if let cachedRuleList = networkFilteringService.ruleList {
            webView.configuration.userContentController.add(cachedRuleList)
            appliedNetworkFiltering = true
            hasAttemptedNetworkFiltering = true
            isNetworkFilteringReady = true
            networkFilterError = nil
            return
        }

        isCompilingNetworkFiltering = true
        networkFilterError = nil

        /// Cancel an older attachment attempt before starting a new one.
        networkFilterTask?.cancel()
        networkFilterTask = Task {
            defer {
                self.isCompilingNetworkFiltering = false
                self.networkFilterTask = nil
            }
            do {
                let ruleList = try await networkFilteringService.compileNetworkRules()
                try Task.checkCancellation()
                webView.configuration.userContentController.add(ruleList)
                appliedNetworkFiltering = true
                hasAttemptedNetworkFiltering = true
                isNetworkFilteringReady = true
            } catch is CancellationError {
                /// Ignore
                return
            } catch {
                /// Ignore Error
                /// we dont want to block the users flow
                networkFilterError = error.localizedDescription
                hasAttemptedNetworkFiltering = true
                isNetworkFilteringReady = false
            }
        }
    }

}
