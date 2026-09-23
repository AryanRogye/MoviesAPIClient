//
//  IFrameLogsView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/23/26.
//

import SwiftUI

struct IFrameLogsView: View {
    @Binding var logs: [String]
    @Binding var videoLogs: [String]
    @Binding var navigationLogs: [String]

    @State private var filter: LogFilter = .all

    @Environment(\.dismiss) var dismiss

    private var displayedLogsAreEmpty: Bool {
        switch filter {
        case .all: logs.isEmpty && videoLogs.isEmpty && navigationLogs.isEmpty
        case .iframe: logs.isEmpty
        case .video: videoLogs.isEmpty
        case .navigation: navigationLogs.isEmpty
        }
    }

    var body: some View {
        List {
            Picker("Log type", selection: $filter) {
                ForEach(LogFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if displayedLogsAreEmpty {
                Text("No Logs Yet")
            } else {
                if (filter == .all || filter == .iframe) && !logs.isEmpty {
                    Section("IFrame Logs") {
                        ForEach(Array(logs.reversed()).enumerated(), id: \.offset) { index, log in
                            logLink(number: logs.count - index, log: log, title: "IFrame Log")
                        }
                    }
                }
                if (filter == .all || filter == .video) && !videoLogs.isEmpty {
                    Section("Video Frame Logs") {
                        ForEach(Array(videoLogs.reversed()).enumerated(), id: \.offset) { index, log in
                            logLink(number: videoLogs.count - index, log: log, title: "Video Frame Log")
                        }
                    }
                }
                if (filter == .all || filter == .navigation) && !navigationLogs.isEmpty {
                    Section("Navigation Logs") {
                        ForEach(Array(navigationLogs.reversed()).enumerated(), id: \.offset) { index, log in
                            logLink(number: navigationLogs.count - index, log: log, title: "Navigation Log")
                        }
                    }
                }
            }
        }
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }

            #if os(macOS)
                ToolbarSpacer(.flexible)
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    if filter == .all || filter == .iframe { logs.removeAll() }
                    if filter == .all || filter == .video { videoLogs.removeAll() }
                    if filter == .all || filter == .navigation { navigationLogs.removeAll() }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(displayedLogsAreEmpty)
                .help("Clear displayed logs")
            }
        }
    }

    private func logLink(number: Int, log: String, title: String) -> some View {
        NavigationLink {
            LogDetailView(title: "\(title) #\(number)", log: log)
        } label: {
            IFrameLogRow(number: number, log: log)
        }
    }
}

private enum LogFilter: String, CaseIterable, Identifiable {
    case all, iframe, video, navigation

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .iframe: "IFrame"
        case .video: "Video"
        case .navigation: "Navigation"
        }
    }
}

private struct IFrameLogRow: View {
    let number: Int
    let log: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("#\(number)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(LogFormatting.formattedJSON(log))
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let decoded = LogFormatting.decodedData(in: log)
            {
                DisclosureGroup("Decoded data") {
                    Text(decoded)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
            }
        }
        .padding(.vertical, 6)
    }

}

private enum LogFormatting {
    static func formattedJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        else {
            return string
        }
        return prettyPrinted(json) ?? string
    }

    static func decodedData(in log: String) -> String? {
        guard let outerData = log.data(using: .utf8),
              let fields = (try? JSONSerialization.jsonObject(with: outerData)) as? [String: Any],
              let string = fields["data"] as? String else { return nil }
        guard let data = string.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        else {
            return nil
        }
        return prettyPrinted(json)
    }

    private static func prettyPrinted(_ value: Any) -> String? {
        if let data = try? JSONSerialization.data(
            withJSONObject: value,
            options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
        ), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return nil
    }
}

private struct LogDetailView: View {
    let title: String
    let log: String

    @State private var query = ""
    @State private var selectedMatch = 0

    private var content: String {
        let outer = LogFormatting.formattedJSON(log)
        guard let decoded = LogFormatting.decodedData(in: log) else { return outer }
        return outer + "\n\nDecoded data:\n" + decoded
    }

    private var lines: [String] {
        content.components(separatedBy: "\n")
    }

    private var matchingLines: [Int] {
        guard !query.isEmpty else { return [] }
        return lines.indices.filter { lines[$0].localizedStandardContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Find in log", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: query) { _, _ in selectedMatch = 0 }

                if !query.isEmpty {
                    Text(matchingLines.isEmpty ? "No matches" : "\(min(selectedMatch + 1, matchingLines.count)) of \(matchingLines.count) lines")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button { moveMatch(by: -1) } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(matchingLines.isEmpty)
                    Button { moveMatch(by: 1) } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(matchingLines.isEmpty)
                }
            }
            .padding()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines.indices, id: \.self) { index in
                            highlighted(lines[index])
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                                .padding(.horizontal)
                                .background(currentLine == index ? Color.accentColor.opacity(0.12) : Color.clear)
                                .id(index)
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: query) { _, _ in scrollToMatch(proxy) }
                .onChange(of: selectedMatch) { _, _ in scrollToMatch(proxy) }
            }
        }
        .navigationTitle(title)
    }

    private var currentLine: Int? {
        guard matchingLines.indices.contains(selectedMatch) else { return nil }
        return matchingLines[selectedMatch]
    }

    private func moveMatch(by offset: Int) {
        guard !matchingLines.isEmpty else { return }
        selectedMatch = (selectedMatch + offset + matchingLines.count) % matchingLines.count
    }

    private func scrollToMatch(_ proxy: ScrollViewProxy) {
        guard let currentLine else { return }
        withAnimation { proxy.scrollTo(currentLine, anchor: .center) }
    }

    private func highlighted(_ line: String) -> Text {
        guard !query.isEmpty else { return Text(verbatim: line) }
        var result = Text("")
        var start = line.startIndex
        while start < line.endIndex,
              let range = line.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: start..<line.endIndex) {
            let prefix = Text(verbatim: String(line[start..<range.lowerBound]))
            let match = Text(verbatim: String(line[range]))
                .foregroundColor(.orange)
                .bold()
            result = Text("\(result)\(prefix)\(match)")
            start = range.upperBound
        }
        return Text("\(result)\(Text(verbatim: String(line[start...])))")
    }
}
