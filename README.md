# Restante

Held wants collect on payday, never mid-cycle.

Restante is for impulse buyers who are paid on a schedule and want a lock they cannot talk themselves out of. File a want with price, necessity, discretion and priority. Hours come from price versus the monthly impulse limit, then snap forward to the next payday. Buying early is remontoire: another cooling want whose remaining hours cover the gap is sacrificed. No checkout, no bank login, no skip.

## Architecture

PAC — Presentation, Abstraction, Control.

The home Pendulum is a wait clock, not a tab plus a list. Presentations draw and forward input. Abstractions hold remaining hours, gate-open versus still-cooling, and wait phase. Controls own the fusee formula, the payday snap, swap-release, and JSON writes. This split keeps cooling math out of SwiftUI and keeps the hub from becoming a record list.

## Payday-anchored unlock

Computed hours never fire mid-cycle. Base hours come from price versus the monthly impulse limit:

`hours = base × priority × (1.5 − necessity/100) × (2 − discretion/100)`

Clamped 6…720, then snapped to the next configured payday. The home clock shows that snapped remaining time. Remontoire is the only early path.

## Design

Poste restante held mail. Palette lives in `Assets.xcassets` and is reached only through `PostageInk`: background `#F6EDE0`, surface `#FFF9F0`, ink `#1C1410`, accent `#A32E28`, muted `#5C4638`. Type is Copperplate for headlines and labels; New York (serif) for long copy and large Dynamic Type. Hard edges. Spacing unit 8 pt. Tap targets 44 pt.

## Art

Style: vintage postage cancellation marks on cream wove envelope paper.

Base prompt reused for every asset:

```
Vintage postage cancellation marks on cream wove envelope paper, circular date-stamp geometry with no readable letters or numbers, wavy killer bars, carmine and graphite ink bleed, dry paper tooth, poste restante held-mail window, quiet studio light, no typography
```

| Asset | Prompt |
| --- | --- |
| `rst_AppIcon` | Abstract circular postage cancellation and wavy killer bars in carmine and graphite on cream envelope paper, no letters, no numbers, no words, no rounded corners, subject inside the middle 80 percent, edge-to-edge, no alpha |
| `rst_Splash` | Base prompt, a vertical hero composition with a calm, uncluttered centre band |
| `rst_Onboarding1` | Base prompt, a sealed cream envelope waiting behind a pigeonhole window |
| `rst_Onboarding2` | Base prompt, a hand filing an envelope into a poste restante slot, mid-gesture |
| `rst_Onboarding3` | Base prompt, several held envelopes accumulated in a wooden pigeonhole |
| `rst_EmptyHome` | Empty poste restante pigeonhole behind a waiting window, cream paper, faint unused cancellation ring, calm, no people, no text |
| `rst_EmptyList` | A bare sorting tray for held letters with no envelopes, cream and graphite, one empty slot highlighted, no text |
| `rst_CardBackdrop` | Base prompt, an abstract backdrop suitable for sitting behind a card, low contrast |
| `rst_ControlFace` | A clockmaker winding key laid on a cancelled envelope, brass and carmine ink, square-on, no text |
| `rst_TwistHero` | A clock face fused with an unstruck cancellation mark, the next payday gate still closed, carmine bars and cream paper, no readable type |
| `rst_SuccessMark` | A freshly struck circular cancellation in carmine, no letters, no date digits, cream paper around it |
| `rst_HeaderDecor` | A wide strip of wavy killer bars and faint circular stamp fragments across cream paper, low contrast, no text |

## How this is not a repeat

Not a calorie tracker and not a fixed 24-hour or 7-day timer. The home screen is the wait clock. Hours still come from price, priority, necessity and discretion, then snap to payday. Distinct from Clickface (desk calculator) and Washfolio (year stroke). No Game tab.

## Build

```bash
cd Restante
xcodegen generate
xcodebuild -scheme Restante -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Bundle identifier: `com.restante.hold`. Contact: https://restante.pro/contact-us

Review screenshots: launch with `-ReviewScreen today|log|goals` after onboarding. Simulator seed uses `rst.demo.v1` and never runs on a device. The driver captures PNG with `simctl`, not `ImageRenderer`.
