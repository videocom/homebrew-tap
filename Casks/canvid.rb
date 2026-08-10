cask "canvid" do
  version "3.1.0"
  sha256 "17d6558c5162357aa652c750b691545c398e21a0dd1a2afec8e710efbe675eb2"

  url "https://installers.canvid.com/Canvid-v#{version}-mac.dmg"
  name "Canvid"
  desc "Screen recorder with automatic visual enhancements"
  homepage "https://www.canvid.com/"

  livecheck do
    url "https://installers.canvid.com/latest-mac.yml"
    strategy :yaml do |yaml|
      yaml["version"]
    end
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :monterey

  app "Canvid.app"
end
