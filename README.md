# SpacesBar

<i>Full disclosure: I'm not a Swift dev, I mostly vibe-coded this</i>

Lightweight macOS menu bar app that shows which apps are active on which macOS space. Relies on [yabai](https://github.com/koekeishiya/yabai) as its backend.

`1 [Chrome] [WhatsApp]  2 [VS Code] [iTerm2]  5 [LM Studio]`

|     |     |
| --- | --- | 
| Colors, including empty | <img width="474" height="30" alt="full-color" src="https://github.com/user-attachments/assets/e19e45d9-c477-40a0-a27d-a17e340d35a9" /> |
| Colors, excluding empty | <img width="474" height="30" alt="active-color" src="https://github.com/user-attachments/assets/cc1f72d8-ee38-4592-a895-2096ced1831d" /> |
| Mono, including empty   | <img width="474" height="30" alt="full-mono" src="https://github.com/user-attachments/assets/a987e74c-278b-407a-a9eb-f70112ef5689" /> |
| Mono, excluding empty   | <img width="474" height="30" alt="active-mono" src="https://github.com/user-attachments/assets/55dc3fc0-cf6f-4769-bf18-90cc2daaa101" /> |

## Requirements

- macOS 26.2 (Tahoe) or later
- Apple Silicon (arm64)
- yabai installed and running

## Install

### Homebrew (recommended)

```sh
brew tap alber70g/tap
brew install --cask spacesbar
# the app is unsigned so remove the quarantine attribute
xattr -dr com.apple.quarantine /Applications/SpacesBar.app
```

### Manual (zip)

1. Download the latest `SpacesBar-<version>-arm64.zip` from [Releases](https://github.com/alber70g/SpacesBar/releases).
2. Unzip and move `SpacesBar.app` to `/Applications`.
3. Because the build is unsigned, macOS Gatekeeper will block it on first launch. Remove the quarantine attribute:

   - run this shell command
     ```sh
     xattr -dr com.apple.quarantine /Applications/SpacesBar.app
     ```

4. Open the app. It will appear in the menu bar with no Dock icon.

## Dev builds

Every push to `master` republishes a rolling [`dev` prerelease](https://github.com/alber70g/SpacesBar/releases/tag/dev) with an unsigned `.app` zip built by GitHub Actions. Versioned releases are cut from `v*` tags.

## Configuration

<img width="474" height="160" alt="configuration" src="https://github.com/user-attachments/assets/1634d6b5-9202-4638-8d41-1699895b6239" />

On first launch SpacesBar writes defaults to `~/.config/spacesbar.json`:

```json
{
  "hideEmptySpaces": false,
  "iconStyle": "colored",
  "refreshFallbackSeconds": 5
}
```

- `iconStyle`: `colored` · `monochrome`
- `hideEmptySpaces`: hide spaces with no apps
- `refreshFallbackSeconds`: safety-net poll interval (event-driven refresh is primary)

The same options are available from the menu bar dropdown: icon style, hide empty spaces, copy current output, quit.

Logs: `~/Library/Logs/SpacesBar/spacesbar.log`

## Yabai event integration (recommended)

SpacesBar listens for file-system events on `~/Library/Application Support/SpacesBar/refresh.signal`. Wire yabai to `touch` that file so the menu bar updates instantly instead of waiting for the fallback timer.

Add to `~/.config/yabai/yabairc`:

```sh
#!/usr/bin/env sh
SIGNAL="$HOME/Library/Application Support/SpacesBar/refresh.signal"
yabai -m signal --add event=space_changed       action="touch \"$SIGNAL\""
yabai -m signal --add event=window_created      action="touch \"$SIGNAL\""
yabai -m signal --add event=window_destroyed    action="touch \"$SIGNAL\""
yabai -m signal --add event=window_moved        action="touch \"$SIGNAL\""
yabai -m signal --add event=application_visible action="touch \"$SIGNAL\""
yabai -m signal --add event=application_hidden  action="touch \"$SIGNAL\""
```

Reload yabai (`brew services restart yabai`) and the menu bar will refresh on every yabai event.

## Build from source

Requires Xcode 26.4+ (matches `MACOSX_DEPLOYMENT_TARGET = 26.2`).

```sh
# Open in Xcode
open SpacesBar.xcodeproj

# Or build from CLI
xcodebuild \
  -project SpacesBar.xcodeproj \
  -scheme SpacesBar \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

open build/Build/Products/Release/SpacesBar.app
```

## Maintainer: cutting a release

1. Bump `MARKETING_VERSION` in `SpacesBar.xcodeproj/project.pbxproj` (or let CI override it via the tag).
2. Tag and push:

   ```sh
   git tag v1.2.3
   git push origin v1.2.3
   ```

3. The `release` workflow builds `SpacesBar-<version>-arm64.zip`, attaches it to a GitHub Release, and — if `TAP_GITHUB_TOKEN` is configured — opens a `bump/spacesbar-<version>` pull request against [`alber70g/homebrew-tap`](https://github.com/alber70g/homebrew-tap) updating `Casks/spacesbar.rb`. Merge the PR to publish the new version on the tap.

To set up the Homebrew tap the first time:

```sh
# In a separate repo named `homebrew-tap` under your GitHub account
mkdir -p Casks
cp /path/to/SpacesBar/Casks/spacesbar.rb Casks/spacesbar.rb
git add Casks/spacesbar.rb && git commit -m "Add spacesbar cask" && git push
```

Then create a fine-grained PAT scoped to `alber70g/homebrew-tap` with permissions **Contents: Read and write** and **Pull requests: Read and write**, and add it to this repo's Actions secrets as `TAP_GITHUB_TOKEN`. If the secret is missing the release still publishes — only the tap PR is skipped.

## License

[MIT](LICENSE)
