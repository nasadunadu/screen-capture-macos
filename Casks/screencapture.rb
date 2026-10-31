cask "screencapture" do
  version "0.5.0"
  sha256 "e4088ca8d99af88ffcca6f6a509341fa164e48f21ab7b7907f399d00c42a6582"

  url "https://github.com/nasadunadu/screen-capture-macos/releases/download/v#{version}/ScreenCapture-#{version}-macos-arm64.dmg"
  name "Screen Capture"
  desc "Native, private-by-design screenshot and scrolling long-capture utility"
  homepage "https://github.com/nasadunadu/screen-capture-macos"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "ScreenCapture.app"

  zap trash: [
    "~/Library/Preferences/com.nasa.ScreenCapture.plist",
  ]
end
