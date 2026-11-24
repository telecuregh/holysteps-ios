# HolySteps for iOS (starter)

SwiftUI, iOS 17+. Tabs: Home, Faith, Fitness, Cycle, Profile. Everything is stored on the phone.

## Open in Xcode
Option A (XcodeGen):
  brew install xcodegen
  cd HolySteps && xcodegen generate && open HolySteps.xcodeproj

Option B (no tools): in Xcode choose File > New > Project > iOS App (SwiftUI, name HolySteps,
bundle id com.holysteps.app). Delete the generated ContentView/App files, drag the Sources folder in,
and add the HealthKit capability under Signing & Capabilities.

Then pick your iPhone or a simulator and press Run. Set your Team under Signing & Capabilities
once the Apple Developer membership is active.
