cask "agent-town" do
  version "1.0.28"
  sha256 "62ea9b59551659f0b8c8d144c9d7c1f3d6e7d75c3350ab085e2755acdb8bc2eb"

  url "https://github.com/samsonchen/agent-town-claude-code/releases/download/v#{version}/AgentTown-#{version}.dmg"
  name "agent-town"
  desc "Shows Claude Code's work as a small office"
  homepage "https://github.com/samsonchen/agent-town-claude-code"

  livecheck do
    url :url
    strategy :github_releases
    regex(/^v(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sequoia

  app "AgentTown.app"

  uninstall quit: "ai.careactive.agenttown-claude-code"

  zap trash: [
    "~/Library/Application Support/agent-town-claude-code",
    "~/Library/Preferences/ai.careactive.agenttown-claude-code.plist",
  ]

  caveats <<~EOS
    agent-town also needs the town-link plugin in Claude Code:
      claude plugin marketplace add samsonchen/agent-town-claude-code
      claude plugin install town-link@agent-town-claude-code
  EOS
end
