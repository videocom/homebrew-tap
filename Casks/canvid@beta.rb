cask "canvid@beta" do
  version "3.2.1-beta.1"
  sha256 "4ac07c89817cd870605c513d4b6db9675449017c9c1a48675f99e7bdd9259aac"

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
