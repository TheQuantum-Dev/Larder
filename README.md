# Larder

A pantry companion for students. Photograph what's in your fridge or cupboard and get a recipe you can make right now, with a rough sense of what it costs and how it fits your week. Built for a dorm mini-fridge and a financial-aid budget, not a family kitchen.

## What it does

- **Scan your pantry** with your camera, a barcode, or by typing things in — manual entry is always right there, never an afterthought
- On-device Vision spots what's in a photo, and on Apple Intelligence phones Apple's Foundation Models sharpen that further — either way, you always confirm or fix what it found before it's added
- **Recipes** ranked by how completely you can make them with what's on hand, filterable by ready-now, quick, cheap, or no-stove-needed, from a bundled book of 30 (not a live database)
- A rough cost per recipe, a weekly food budget, and a daily cooking streak
- **Cook Mode** walks you through a recipe step by step, with timers
- **Chat with Nutmeg** about your kitchen (Larder Plus): ask what to cook, what's running low, or how your week's going, and get answers grounded in your own pantry and stats — never a made-up recipe, never cooking steps it invented itself
- Nothing is uploaded: photos are read on your phone, and a barcode scan only ever sends the barcode number

## Requirements

- iPhone, iOS 26.5 or later
- Works on every supported iPhone. Phones with Apple Intelligence get a sharper pantry scan and can chat with Nutmeg using the on-device model instead of the offline fallback

## Running this project

1. Clone the repo and open `Larder/Larder.xcodeproj` in Xcode.
2. **Xcode 27 (iOS 27 SDK) or later is required to build**, even though the app itself runs on iOS 26.5+ — a couple of the on-device AI code paths are only available starting with that SDK.
3. Pick a simulator or a real device running iOS 26.5+ and hit Run. In Xcode's Signing & Capabilities, switch the team to your own if it complains about code signing.
4. Purchases run on RevenueCat's **Test Store**, so no paid Apple Developer account or App Store listing is needed to try Larder Plus — the flow is real, the purchases are simulated.
5. No API keys to set up: barcode lookups use the free, public [Open Food Facts](https://world.openfoodfacts.org) API, and the RevenueCat key already in the project is scoped to the Test Store.

## License

See [LICENSE](LICENSE).
