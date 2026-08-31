cask "canvid@beta" do
  version "3.1.2-beta.1"
  sha256 "e05d702eeb7d4d8050ce6238a42cdfd2c0a8b90889cf51501f5a26dfe982fe02"

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
