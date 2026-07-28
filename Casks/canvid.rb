cask "canvid" do
  version "3.0.0"
  sha256 "9891667ac3b34d78426c20e8b9314c7fc5b60e6ff6b47424d0a4ce500d0ed0c6"

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
