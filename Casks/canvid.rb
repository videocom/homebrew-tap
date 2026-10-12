cask "canvid" do
  version "3.2.0"
  sha256 "9308e280ae28dcb43bc2c2055d9e2f46ad75fce0f5b75197a9a5b52d2bbb5630"

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
