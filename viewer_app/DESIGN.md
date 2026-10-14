# Uziy — Meadow UI

Uziy connects targeted video and short surveys to a real tögrög reward. The interface therefore prioritizes the reward amount, time commitment, next action, account verification, and wallet access.

## Visual system

- Warm paper background (`#F5F7F3`), white cards, and quiet sage borders.
- Forest green (`#145C45`) for primary actions and selected controls. White labels maintain contrast across the brand gradient.
- Warm gold remains reserved for currency illustrations and reward chips. Coins draw the ₮ mark directly, without depending on font coverage.
- Shared typography, 20-point page gutters, 44-point minimum tap targets, responsive width limits, and reduced-motion support.
- Video retains a dark stage with white overlay controls; the information panel uses the same light surfaces as the rest of the app.

## Screen changes

Home separates the wallet shortcut, available reward total, content filters, and campaign list. The total is described as a potential reward rather than a promise of daily earnings. Campaign badges no longer imply advertiser verification without supporting data.

Wallet uses a forest-green balance card, a clear withdrawal action, and a link to the existing earned-reward history page instead of an unconditional empty transaction placeholder.

Profile places identity and verification side by side when space allows, with a stacked layout for narrow screens and larger accessibility text. Login removes decorative falling coins and developer API details. Shared fields, buttons, OTP, survey options, progress tracks, sheets, history, help, and privacy screens inherit the light system.

## Verification and visual review

```sh
flutter analyze
flutter test
flutter build web
```

The manual preview renderer uses production presentation widgets with local sample data; it does not alter API responses or inject demo data into the app. Login is rendered directly. It requires a locally available Cyrillic-capable font (no font is copied into the repository).

```sh
flutter test tool/render_design_test.dart \
  --dart-define=UI_PREVIEW_FONT=/absolute/path/to/font.ttf
```

It writes home, wallet, profile, survey, and login PNGs to `build/design-preview/`. These are visual-review compositions, not backend-connected end-to-end screenshots. Native devices use their platform system font, so exact line wrapping may differ.

## Existing limitations

The video screen still contains the pre-existing timer/artwork placeholder instead of real video playback. This redesign does not change reward validation, authentication, payouts, or API contracts. Live backend and physical-device validation remain separate from widget tests and the web build.

## Appearance modes

The home header and Profile → Харагдах горим open the same appearance picker: device setting, light, or dark. The preference is stored separately from authentication and restored before launch. The device setting follows live OS brightness changes. A failed save keeps the selection for the session and shows an actionable message.

Colors, type, gradients, loading placeholders, inputs, survey choices, and painted progress now resolve from each widget's current theme context. Dark mode uses forest surfaces with mint actions; currency retains its gold motif and media overlays retain their own contrast. The appearance sheet has a clear “Боллоо” dismissal action.

Generate the matching dark previews with the renderer's additional `--dart-define=UI_PREVIEW_DARK=true` flag. Files are named `home-dark.png`, `wallet-dark.png`, etc. Theme tests cover storage failure, rapid choices, OS changes, text contrast, and preservation of entered form text and focus while switching.
