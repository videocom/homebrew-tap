cask "canvid" do
  version "3.2.1"
  sha256 "24959b7ca77afd55b9e77278142fc1218f4583699daaea6f907d558115f049d0"

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
