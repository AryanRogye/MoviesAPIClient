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

    @State private var filter: LogFilter = .all

    @Environment(\.dismiss) var dismiss

    private var displayedLogsAreEmpty: Bool {
        switch filter {
        case .all: logs.isEmpty && videoLogs.isEmpty
        case .iframe: logs.isEmpty
        case .video: videoLogs.isEmpty
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
                if filter != .video && !logs.isEmpty {
                    Section("IFrame Logs") {
                        ForEach(Array(logs.reversed()).enumerated(), id: \.offset) { index, log in
                            IFrameLogRow(number: logs.count - index, log: log)
                        }
                    }
                }
                if filter != .iframe && !videoLogs.isEmpty {
                    Section("Video Frame Logs") {
                        ForEach(Array(videoLogs.reversed()).enumerated(), id: \.offset) { index, log in
                            IFrameLogRow(number: videoLogs.count - index, log: log)
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
                    if filter != .video { logs.removeAll() }
                    if filter != .iframe { videoLogs.removeAll() }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(displayedLogsAreEmpty)
                .help("Clear displayed logs")
            }
        }
    }
}

private enum LogFilter: String, CaseIterable, Identifiable {
    case all, iframe, video

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .iframe: "IFrame"
        case .video: "Video"
        }
    }
}

private struct IFrameLogRow: View {
    let number: Int
    let log: String

    private var fields: [String: Any]? {
        guard let data = log.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("#\(number)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(formattedJSON(log))
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let data = fields?["data"] as? String,
                let decoded = formattedEmbeddedJSON(data)
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

    private func formattedJSON(_ string: String) -> String {
        guard let data = string.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        else {
            return string
        }
        return prettyPrinted(json) ?? string
    }

    private func formattedEmbeddedJSON(_ string: String) -> String? {
        guard let data = string.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        else {
            return nil
        }
        return prettyPrinted(json)
    }

    private func prettyPrinted(_ value: Any) -> String? {
        if let data = try? JSONSerialization.data(
            withJSONObject: value,
            options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
        ), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return nil
    }
}
