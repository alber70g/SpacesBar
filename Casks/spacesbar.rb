cask "spacesbar" do
  version "@@VERSION@@"
  sha256 "@@SHA256@@"

  url "https://github.com/alber70g/SpacesBar/releases/download/v#{version}/SpacesBar-#{version}-arm64.zip"
  name "SpacesBar"
  desc "Menu bar app showing apps per space"
  homepage "https://github.com/alber70g/SpacesBar"

  depends_on macos: ">= :tahoe"
  depends_on arch: :arm64

  app "SpacesBar.app"

  caveats <<~EOS
    SpacesBar is unsigned, so macOS Gatekeeper will block it on first launch.

    Remove the quarantine attribute manually before first launch:

      xattr -dr com.apple.quarantine /Applications/SpacesBar.app
  EOS

  zap trash: [
    "~/.config/spacesbar.json",
    "~/Library/Application Support/SpacesBar",
    "~/Library/Logs/SpacesBar",
    "~/Library/Preferences/nl.upgraide.SpacesBar.plist",
  ]
end
