//
//  ExpandableText.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI

struct ExpandableText<ForegroundStlye: ShapeStyle>: View {
    let text: String
    var collapsedLines: Int = 3
    let tintColor: Color
    #if os(iOS)
    let font: UIFont
    #elseif os(macOS)
    let font: NSFont
    #endif
    var background: Color
    var foregroundStyle: ForegroundStlye

    @State private var isTruncated = false
    @State private var isExpanded = false
    @State private var displayString: AttributedString?
    @State private var containerWidth: CGFloat = 0

    private let moreURL = URL(string: "expandable-text://more")!
    private let lessURL = URL(string: "expandable-text://less")!

    var body: some View {
        Text(displayString ?? AttributedString(text))
            .foregroundStyle(foregroundStyle)
            .onChange(of: text) {
                isExpanded = false
                rebuild()
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newWidth in
                guard newWidth > 0, newWidth != containerWidth else { return }
                containerWidth = newWidth
                rebuild()
            }
            .environment(\.openURL, OpenURLAction { url in
                if url == moreURL {
                    withAnimation(.easeInOut) { isExpanded = true }
                    rebuild()
                    return .handled
                } else if url == lessURL {
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
            var s = baseAttributedString(text)
            s += AttributedString(" Show less")
            if let range = s.range(of: "Show less") {
                s[range].foregroundColor = tintColor
                s[range].font = Font(font).weight(.semibold)
                s[range].link = lessURL
            }
            displayString = s
            return
        }

        let lines = splitIntoLines(text, width: containerWidth)
        isTruncated = lines.count > collapsedLines

        guard isTruncated else {
            displayString = baseAttributedString(text)
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

        var s = baseAttributedString(visible.trimmedTrailingWhitespace)
        s += AttributedString("… ")
        var more = AttributedString("More")
        more.foregroundColor = tintColor
        more.font = Font(font).weight(.semibold)
        more.link = moreURL
        s += more

        displayString = s
    }

    private func baseAttributedString(_ text: String) -> AttributedString {
        var string = AttributedString(text)
        string.font = Font(font)
        return string
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
