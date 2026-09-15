//
//  PopupFilteringService.swift
//  ComfyPortal
//
//  Created by Aryan Rogye on 9/6/26.
//

import SwiftUI

class PopupFilteringService {

    private var javascript: String?

    enum PopupFilteringError: LocalizedError {
        case popupFiltersJsonDoesntExist
        case cantDecodeJson(Error)

        var errorDescription: String? {
            switch self {
            case .popupFiltersJsonDoesntExist:
                "PopupFilters.json Doesnt Exist"
            case .cantDecodeJson(let error):
                "Cant Decode Json: \(error.localizedDescription)"
            }
        }
    }

    public func getJavascript() throws -> String {
        if let javascript {
            return javascript
        }
        let filters = try getPopupFiltersJson()

        guard !filters.isEmpty else {
            throw PopupFilteringError.popupFiltersJsonDoesntExist // or a dedicated "empty" case
        }

        let end = "    const suspicious = " + filters
            .map { signature in
                "(" + signature
                    .map { "source.includes(\(jsStringLiteral($0)))" }
                    .joined(separator: " && ") + ")"
            }
            .joined(separator: " ||\n        ") + ";"

        let full = """
        console.log("🔥 COMFYPORTAL POPUP FILTER LOADED 🔥");
        
        function isSuspiciousPopup(frame) {
            if (!(frame instanceof HTMLIFrameElement)) {
                return false;
            }
        
            const source = frame.srcdoc;
        
            if (!source) {
                return false;
            }
        
        \(end)
        
            if (suspicious) {
        console.log("🚨 COMFYPORTAL FOUND POPUP", frame);
            }
        
            return suspicious;
        }
        
        function removeIfSuspicious(frame) {
            if (isSuspiciousPopup(frame)) {
                frame.remove();
            }
        }
        
        function inspectNode(node) {
            if (!(node instanceof Element)) {
                return;
            }
        
            // The added node itself might be an iframe.
            removeIfSuspicious(node);
        
            // Or the added node might contain an iframe.
            node.querySelectorAll("iframe").forEach(removeIfSuspicious);
        }
        
        new MutationObserver(records => {
            for (const record of records) {
                // Inspect only newly-added nodes.
                for (const node of record.addedNodes) {
                    inspectNode(node);
                }
        
                // An existing iframe may have received its srcdoc later.
                if (
                    record.type === "attributes" &&
                    record.target instanceof HTMLIFrameElement
                ) {
                    removeIfSuspicious(record.target);
                }
            }
        }).observe(document.documentElement, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ["srcdoc"]
        });
        
        // One initial scan for iframes that already exist.
        document.querySelectorAll("iframe").forEach(removeIfSuspicious);
        """
        self.javascript = full
        return full
    }

    func jsStringLiteral(_ s: String) -> String {
        let data = try! JSONEncoder().encode(s) // JSON string encoding == valid JS string literal
        return String(data: data, encoding: .utf8)!
    }

    private struct PopupFiltersJson: Decodable {
        let signatures: [[String]]
    }

    private func getPopupFiltersJson() throws -> [[String]] {
        guard let url = Bundle.main.url(
            forResource: "PopupFilters",
            withExtension: "json"
        ) else {
            throw PopupFilteringError.popupFiltersJsonDoesntExist
        }

        let json: PopupFiltersJson
        do {
            let data = try Data(contentsOf: url)
            json = try JSONDecoder().decode(PopupFiltersJson.self, from: data)
        } catch {
            throw PopupFilteringError.cantDecodeJson(error)
        }

        return json.signatures
    }
}
