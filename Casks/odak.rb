# Homebrew cask for the slymnyg/homebrew-tap repository.
# Copy this file to Casks/odak.rb in that tap.
#
# On each release:
#   1. Set `version` to the tag without the leading "v".
#   2. Replace `sha256` with the value printed by the Release workflow
#      (or run: shasum -a 256 Odak-<version>.zip).
cask "odak" do
  version "1.0.0"
  # REPLACE: sha256 of Odak-#{version}.zip from the GitHub release.
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/slymnyg/odak/releases/download/v#{version}/Odak-#{version}.zip"
  name "Odak"
  desc "Menu bar focus timer that blocks distracting websites and apps"
  homepage "https://github.com/slymnyg/odak"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Odak.app"

  uninstall_preflight do
    # Clear any active block before the helper is removed.
    helper = "/Library/PrivilegedHelperTools/app.odak.block"
    if File.exist?(helper)
      system_command "/usr/bin/sudo",
                     args:         ["-n", helper, "off"],
                     must_succeed: false
    end
  end

  uninstall quit:   "app.odak.Odak",
            delete: [
              "/Library/PrivilegedHelperTools/app.odak.block",
              "/etc/sudoers.d/app_odak",
            ]

  zap trash: [
    "~/Library/Application Support/Odak",
    "~/Library/Preferences/app.odak.Odak.plist",
  ]
end
