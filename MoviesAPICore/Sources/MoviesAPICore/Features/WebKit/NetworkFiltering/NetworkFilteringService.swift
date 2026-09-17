//
//  NetworkFilteringService.swift
//  ComfyPortal
//
//  Created by Aryan Rogye on 9/4/26.
//

import Foundation
import WebKit

@MainActor
final class NetworkFilteringService {

    private(set) var ruleList: WKContentRuleList?

    /// Update On Change
    private static let networkFilteringIdentifier: String = "com.aryanrogye.ComfyPortal.network-blocking.\(1)"

    private var compilationTask: Task<WKContentRuleList, Error>?

    enum NetworkFilteringError: LocalizedError {
        case cantFindNetworkBlockingJson
        case failedToLoadNetworkBlockingJson(Error)
        case ruleListWasNil

        var errorDescription: String? {
            switch self {
            case .cantFindNetworkBlockingJson:
                "Cant Find NetworkBlockingRules.json"
            case .failedToLoadNetworkBlockingJson(let error):
                "Failed To Load NetworkBlockingRules.json: \(error.localizedDescription)"
            case .ruleListWasNil:
                "Rule List Was: NIL"
            }
        }
    }

    func compileNetworkRules() async throws -> WKContentRuleList {

        /// Rulelist already is compiled so we can reuse this
        if let ruleList {
            return ruleList
        }
        /// If there is a `compilationTask` we just await it
        if let compilationTask {
            return try await compilationTask.value
        }

        /// we set a task variable to the output of loadOrCompileRuleList
        /// this is because this task is not nil and we can check it after
        let task = Task {
            try await loadOrCompileRuleList()
        }

        /// set `compilationTask` to task so any future callers
        /// know that its in progress
        compilationTask = task

        /// Assignment
        do {
            let ruleList = try await task.value

            self.ruleList = ruleList
            self.compilationTask = nil

            return ruleList
        } catch {
            /// Important: allow another attempt later if this one failed.
            self.compilationTask = nil
            self.ruleList = nil
            throw error
        }
    }

    private func loadOrCompileRuleList() async throws -> WKContentRuleList {
        do {
            if let existing = try await existingRuleList() {
                return existing
            }
        } catch {
            /// Cached list couldn't be loaded.
            /// Fall through and rebuild it.
        }

        let rules = try self.rulesJson()

        return try await compileRuleList(rules)
    }

    private func compileRuleList(_ rules: String) async throws -> WKContentRuleList {
        try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: Self.networkFilteringIdentifier,
                encodedContentRuleList: rules
            ) { ruleList, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let ruleList else {
                    continuation.resume(throwing: NetworkFilteringError.ruleListWasNil)
                    return
                }

                continuation.resume(returning: ruleList)
            }
        }
    }

    /// Returns `WKContentRuleList` that is stored on disk
    private func existingRuleList() async throws -> WKContentRuleList? {
        try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().lookUpContentRuleList(
                forIdentifier: Self.networkFilteringIdentifier
            ) { ruleList, error in

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: ruleList)
            }
        }
    }

    /// Function Loads `NetworkBlockingRules.Json` and
    /// returns as `String`
    private nonisolated func rulesJson() throws -> String {
        guard let url = Bundle.module.url(
            forResource: "NetworkBlockingRules",
            withExtension: "json",
        ) else {
            throw NetworkFilteringError.cantFindNetworkBlockingJson
        }

        let rules: String
        do {
            rules = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw NetworkFilteringError.failedToLoadNetworkBlockingJson(error)
        }

        return rules
    }
}
