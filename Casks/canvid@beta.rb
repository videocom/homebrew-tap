cask "canvid@beta" do
  version "3.1.0-beta.7"
  sha256 "b845ee28c8b650a075048485bef4045ae36f633a778afdb253260237ed83f5d5"

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
