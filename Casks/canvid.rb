cask "canvid" do
  version "3.1.2"
  sha256 "d47c75d89841cf87d7250ebac122ffded9b7478b9d457b2df98bc9ed3775dcb2"

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
