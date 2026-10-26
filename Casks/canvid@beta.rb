cask "canvid@beta" do
  version "3.3.0-beta.1"
  sha256 "2e6a1c2a43ec310daf87cf6abea57a5f4bffbe73c34a59f93f887c56d4343b00"

  url "https://installers.canvid.com/Canvid%20Beta-v#{version}-mac.dmg"
  name "Canvid Beta"
  desc "Beta channel of the Canvid screen recorder"
  homepage "https://www.canvid.com/"

  livecheck do
    url "https://installers.canvid.com/beta-mac.yml"
    strategy :yaml do |yaml|
      yaml["version"]
    end
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :monterey

  app "Canvid Beta.app"
end
