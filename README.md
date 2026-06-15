# Rately

Live **currency & crypto rates** right in your Mac's menu bar. Track the pairs
you care about, glance at your headline rate without opening anything, and
convert any amount in a couple of clicks.

**Privacy first** — Rately fetches rates from free, public APIs over HTTPS and
stores your tracked pairs only on your Mac. No account, no tracking.

## Features
- Live fiat rates (20+ currencies) and crypto prices (BTC, ETH, SOL, ADA, DOGE, XRP)
- Your headline pair shown right in the menu bar
- Built-in converter for any amount
- **Rately Pro** (one-time purchase): unlimited pairs, faster refresh, and all themes

Rates come from [open.er-api.com](https://open.er-api.com) (fiat) and
[CoinGecko](https://www.coingecko.com) (crypto). No API keys required.

## Build
The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open Rately.xcodeproj
```

CI/CD: built & signed for the Mac App Store on Codemagic (`codemagic.yaml`).
Monetization via [RevenueCat](https://www.revenuecat.com) (entitlement `pro`).

- Bundle ID: `app.rately.Rately`
- Minimum macOS: 13.0
