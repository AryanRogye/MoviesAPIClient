//
//  WebKitProcessLocator.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/22/26.
//

import ObjectiveC.runtime
import WebKit
import Darwin

enum WebKitProcessLocator {

    /// https://github.com/WebKit/WebKit/blob/286a99d1fd350792a2c1b6d18364ca5ce48f589b/Source/WebKit/UIProcess/API/Cocoa/WKWebView.mm#L5556-L5562
    /**
     * - (pid_t)_webProcessIdentifier
     * {
     *      if (![self _isValid])
     *      return 0;
     *
     *      return _page->legacyMainFrameProcessID();
     * }
     */
    static let sel = NSSelectorFromString("_webProcessIdentifier")

    typealias WebProcessIdentifierIMP = @convention(c) (
        AnyObject,
        Selector
    ) -> pid_t

    static func webProcessIdentifier(for webView: WKWebView) -> pid_t? {
        let selector = NSSelectorFromString("_webProcessIdentifier")

        /// checks to see whether WKWebview implements or inherits `_webProcessIdentifier`
        guard webView.responds(to: selector) else {
            print("WKWebview does not implement or inherit _webProcessIdentifier")
            return nil
        }

        /// makes sure that we have the method
        guard let method = class_getInstanceMethod(WKWebView.self, selector) else {
            print("Cannot get instance method: _webProcessIdentifier")
            return nil
        }

        let imp = method_getImplementation(method)
        let function = unsafeBitCast(imp, to: WebProcessIdentifierIMP.self)
        let pid = function(webView, selector)

        if pid == 0 {
            print("PID: 0")
            return nil
        }
        return pid
    }
}

//proofreadingSession:didReceiveSuggestions:processedRange:inContext:finished:
//_doAfterProcessingAllPendingKeyEvents:
//_doAfterProcessingAllPendingMouseEvents:
//_getProcessDisplayNameWithCompletionHandler:
//_gpuProcessIdentifier
//_gpuToWebProcessConnectionCountForTesting:
//_killWebContentProcess
//_killWebContentProcessAndResetState
//_launchInitialProcessIfNecessary
//_modelProcessIdentifier
//_modelProcessModelPlayerCountForTesting:
//_networkProcessIdentifier
//_processDidResumeForTesting
//_processWillSuspendForTesting:
//_processWillSuspendImminentlyForTesting
//_progressBasedTimelinesForScrollingNodeID:processID:
//_provisionalWebProcessIdentifier
//_scrollbarStateForScrollingNodeID:processID:isVertical:
//_webContentProcessVariantForFrame:
//_webProcessIdentifier
//_webProcessIsResponsive
//_webProcessState
//accessibilityUIProcessLocalTokenHash
//registeredRemoteAccessibilityPids
//
//=== NSView ===
//_effectiveFocusGroupIdentifier
//automaticallyNotifiesObserversOf_focusGroupIdentifier
//set_focusGroupIdentifier:
//_focusGroupIdentifier
//computed_effectiveFocusGroupIdentifier
//
//=== NSResponder ===
//
//=== NSObject ===
//accessibilityPresenterProcessIdentifier
//accessibilitySetPresenterProcessIdentifier:
