import Foundation
import Testing
@testable import TownCore

@Suite struct UpdatesTests {
    @Test func versionsCompareNumberByNumber() {
        #expect(VersionNumber("1.0.9")! < VersionNumber("1.0.10")!)
        #expect(VersionNumber("1.0")! == VersionNumber("1.0.0")!)
        #expect(!(VersionNumber("2.0.0")! < VersionNumber("1.9.9")!))
        #expect(VersionNumber("1.0.x") == nil)
        #expect(VersionNumber("") == nil)
        #expect(VersionNumber("1..0") == nil)
    }

    @Test func newestMacReleaseSkipsWindowsDraftsAndPreReleases() throws {
        let json = """
        [
          {"tag_name":"windows-v9.0.0","draft":false,"prerelease":false,"body":"win","html_url":"https://x/w","assets":[]},
          {"tag_name":"v1.1.0","draft":true,"prerelease":false,"body":"draft","html_url":"https://x/d","assets":[]},
          {"tag_name":"v1.0.12","draft":false,"prerelease":true,"body":"pre","html_url":"https://x/p","assets":[]},
          {"tag_name":"v1.0.10","draft":false,"prerelease":false,"body":"ten","html_url":"https://x/10",
           "assets":[{"name":"AgentTown-1.0.10.dmg","browser_download_url":"https://x/10.dmg"}]},
          {"tag_name":"v1.0.9","draft":false,"prerelease":false,"body":"nine","html_url":"https://x/9","assets":[]}
        ]
        """
        let r = try #require(UpdateFeed.newest(fromReleases: Data(json.utf8), tagPrefix: "v", downloadSuffix: ".dmg"))
        #expect(r.version == "1.0.10")
        #expect(r.notes == "ten")
        #expect(r.download == URL(string: "https://x/10.dmg"))

        let w = try #require(UpdateFeed.newest(fromReleases: Data(json.utf8), tagPrefix: "windows-v", downloadSuffix: ".exe"))
        #expect(w.version == "9.0.0")
        #expect(w.download == nil)
    }

    @Test func installedVersionIsTheUserScopeEntry() {
        let json = """
        {"version":2,"plugins":{
          "other@market":[{"scope":"user","version":"9.9.9"}],
          "town-link@agent-town-claude-code":[
            {"scope":"project","projectPath":"/x","version":"1.0.1"},
            {"scope":"user","installPath":"/p/1.0.7","version":"1.0.7","gitCommitSha":"abc"}
          ]}}
        """
        #expect(UpdateFeed.installedPluginVersion(fromInstalledPlugins: Data(json.utf8)) == "1.0.7")
        let projectOnly = #"{"plugins":{"town-link@agent-town-claude-code":[{"scope":"project","version":"1.0.1"}]}}"#
        #expect(UpdateFeed.installedPluginVersion(fromInstalledPlugins: Data(projectOnly.utf8)) == nil)
        #expect(UpdateFeed.installedPluginVersion(fromInstalledPlugins: Data(#"{"plugins":{}}"#.utf8)) == nil)
        #expect(UpdateFeed.installedPluginVersion(fromInstalledPlugins: Data(#"{"plugins":{"town-link@agent-town-claude-code":{"version":"1.0.7"}}}"#.utf8)) == nil)
        #expect(UpdateFeed.installedPluginVersion(fromInstalledPlugins: Data("not json".utf8)) == nil)
    }

    @Test func badAnswersGiveNothing() {
        #expect(UpdateFeed.newest(fromReleases: Data("{\"message\":\"rate limited\"}".utf8), tagPrefix: "v", downloadSuffix: ".dmg") == nil)
        #expect(UpdateFeed.pluginVersion(fromManifest: Data("{\"version\":\"1.0.3\"}".utf8)) == "1.0.3")
        #expect(UpdateFeed.pluginVersion(fromManifest: Data("not json".utf8)) == nil)
    }

    @Test func aSessionWithoutAVersionIsOlder() {
        #expect(UpdateFeed.isOlder(nil, than: "1.0.3"))
        #expect(UpdateFeed.isOlder("1.0.2", than: "1.0.3"))
        #expect(!UpdateFeed.isOlder("1.0.3", than: "1.0.3"))
        #expect(!UpdateFeed.isOlder("1.0.4", than: "1.0.3"))
        #expect(!UpdateFeed.isOlder("1.0.2", than: "garbage"))
    }
}
