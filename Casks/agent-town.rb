cask "agent-town" do
  version "1.0.25"
  sha256 "3b9d431d4a7b0e2a3b6d66508029eb1f1080877bdbb53ded03150a55f381e073"

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
