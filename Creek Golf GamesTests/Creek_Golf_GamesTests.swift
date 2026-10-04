//
//  Creek_Golf_GamesTests.swift
//  Creek Golf GamesTests
//
//  Created by Steven Johnson on 10/3/26.
//

import Foundation
import Testing
@testable import Creek_Golf_Games

/// Checks that the bundled web app is complete and works without a network
/// connection. These run inside the app, so `Bundle.main` is the app bundle.
@Suite("Bundled web app")
struct BundledWebAppTests {
    private func bundledText(_ name: String, _ ext: String) throws -> String {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: ext), "\(name).\(ext) is not in the app bundle")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Returns the values of every `src="…"`, `href="…"` and CSS `url(…)` in the text.
    private func references(in text: String) -> [String] {
        let pattern = #/(?:src|href)="([^"]*)"|url\(\s*['"]?([^'")]+)['"]?\s*\)/#
        return text.matches(of: pattern).compactMap { match in
            (match.output.1 ?? match.output.2).map(String.init)
        }
    }

    @Test func indexHTMLIsBundled() throws {
        let html = try bundledText("index", "html")
        #expect(html.contains("Creek Golf Games"))
    }

    @Test func pageLoadsNothingFromTheInternet() throws {
        let html = try bundledText("index", "html")
        let css = try bundledText("fonts", "css")
        let online = references(in: html + css).filter { $0.hasPrefix("http:") || $0.hasPrefix("https:") || $0.hasPrefix("//") }
        #expect(online.isEmpty, "These still load from the internet: \(online)")
    }

    @Test func everyLocalFileThePageUsesIsBundled() throws {
        let html = try bundledText("index", "html")
        let css = try bundledText("fonts", "css")
        let local = references(in: html + css).filter {
            !$0.isEmpty && !$0.hasPrefix("data:") && !$0.hasPrefix("#")
                && !$0.hasPrefix("javascript:") && !$0.contains("${") && !$0.contains(":")
        }
        #expect(!local.isEmpty)
        for name in Set(local) {
            let path = Bundle.main.bundleURL.appendingPathComponent(name).path
            #expect(FileManager.default.fileExists(atPath: path), "\(name) is referenced but not bundled")
        }
    }
}

@Suite("Saving files from the page")
struct SafeFilenameTests {
    @Test func keepsAPlainFilename() {
        #expect(WebAppView.Coordinator.safeFilename(from: "creek-golf-results-2026-10-03.png") == "creek-golf-results-2026-10-03.png")
    }

    @Test(arguments: ["../../Documents/evil.png", "/tmp/evil.png", "folder/evil.png"])
    func stripsFolders(requested: String) {
        #expect(WebAppView.Coordinator.safeFilename(from: requested) == "evil.png")
    }

    @Test(arguments: [nil, "", "/", ".", ".."] as [String?])
    func fallsBackToADefaultName(requested: String?) {
        #expect(WebAppView.Coordinator.safeFilename(from: requested) == "creek-golf-results.png")
    }
}
