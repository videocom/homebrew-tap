cask "canvid@beta" do
  version "3.2.0-beta.3"
  sha256 "f1aa4d1a2096784e08bd711a9c101429f1cf31d49ffcb0bbaa875fa5d93fba1b"

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
