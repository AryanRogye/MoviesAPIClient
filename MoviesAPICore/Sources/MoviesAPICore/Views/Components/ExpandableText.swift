//
//  ExpandableText.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI

struct ExpandableText: View {
    let text: String
    var collapsedLines: Int = 3
    let tintColor: Color
    #if os(iOS)
    let font: UIFont
    #elseif os(macOS)
    let font: NSFont
    #endif
    var background: Color

    @State private var isTruncated = false
    @State private var isExpanded = false
    @State private var displayString: AttributedString?
    @State private var containerWidth: CGFloat = 0

    private static let moreURL = URL(string: "expandable-text://more")!
    private static let lessURL = URL(string: "expandable-text://less")!

    var body: some View {
        Text(displayString ?? AttributedString(text))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newWidth in
                guard newWidth > 0, newWidth != containerWidth else { return }
                containerWidth = newWidth
                rebuild()
            }
            .environment(\.openURL, OpenURLAction { url in
                if url == Self.moreURL {
                    withAnimation(.easeInOut) { isExpanded = true }
                    rebuild()
                    return .handled
                } else if url == Self.lessURL {
                    withAnimation(.easeInOut) { isExpanded = false }
                    rebuild()
                    return .handled
                }
                return .systemAction
            })
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rebuild() {
        guard containerWidth > 0 else { return }

        if isExpanded {
            var s = AttributedString(text)
            s += AttributedString(" Show less")
            if let range = s.range(of: "Show less") {
                s[range].foregroundColor = tintColor
                s[range].font = .callout.weight(.semibold)
                s[range].link = Self.lessURL
            }
            displayString = s
            return
        }

        let lines = splitIntoLines(text, width: containerWidth)
        isTruncated = lines.count > collapsedLines

        guard isTruncated else {
            displayString = AttributedString(text)
            return
        }

        var visible = lines[0..<collapsedLines].joined()

        // Trim trailing characters until "<visible>… More" still fits in
        // `collapsedLines` lines when re-measured.
        while !visible.isEmpty {
            let candidateText = visible.trimmedTrailingWhitespace + "… More"
            if lineCount(candidateText, width: containerWidth) <= collapsedLines {
                break
            }
            visible.removeLast()
        }

        var s = AttributedString(visible.trimmedTrailingWhitespace)
        s += AttributedString("… ")
        var more = AttributedString("More")
        more.foregroundColor = tintColor
        more.font = .body.weight(.semibold)
        more.link = Self.moreURL
        s += more

        displayString = s
    }

    // MARK: - TextKit measuring

    private func splitIntoLines(_ text: String, width: CGFloat) -> [String] {
        let storage = NSTextStorage(string: text, attributes: [.font: font])
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        let ns = text as NSString
        var result: [String] = []
        var glyphIndex = 0

        while glyphIndex < layoutManager.numberOfGlyphs {
            var glyphRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &glyphRange)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            result.append(ns.substring(with: charRange))
            glyphIndex = NSMaxRange(glyphRange)
        }
        return result
    }

    private func lineCount(_ text: String, width: CGFloat) -> Int {
        splitIntoLines(text, width: width).count
    }
}

private extension String {
    var trimmedTrailingWhitespace: String {
        var s = self
        while let last = s.last, last.isWhitespace || last == "\n" {
            s.removeLast()
        }
        return s
    }
}
