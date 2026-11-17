# Waktu Solat — iPhone + Apple Watch

Prayer times from **JAKIM e-Solat**, with automatic zone detection from GPS. The project includes:

| Target | What it does |
|---|---|
| **WaktuSolat** (iPhone) | Detects your JAKIM zone from GPS (or you pick one), downloads ~1 month of times, and shows the next prayer with a live countdown. Sends the times to the watch. |
| **WaktuSolatWidget** | Home Screen widgets (small, medium) and Lock Screen widgets (circular, rectangular, inline). |
| **WaktuSolatWatch** | Watch app showing the next prayer and today's times. Gets data from the iPhone and can also download from JAKIM by itself. |
| **WaktuSolatWatchWidget** | Watch face complications (circular, rectangular, inline, corner). |

Requires Xcode 15 or later, iOS 17+, and watchOS 10+.

---

## 1. Generate the Xcode project

The project file is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen), so you don't have to set up four targets by hand.

```bash
brew install xcodegen          # one time
cd WaktuSolat
xcodegen generate
open WaktuSolat.xcodeproj
```

## 2. Signing

1. Find your **Team ID** in Xcode → Settings → Accounts → (your Apple ID) → team, or at developer.apple.com → Membership.
2. Put it in `project.yml` under `DEVELOPMENT_TEAM: ""` and run `xcodegen generate` again.
   You can also set **Team** under *Signing & Capabilities* for each of the 4 targets in Xcode.
3. Bundle IDs use the prefix `com.syaahid.waktusolat`. If Xcode says the ID is taken, replace `com.syaahid` everywhere:
   ```bash
   grep -rl "com.syaahid" project.yml Shared | xargs sed -i '' 's/com\.syaahid/com.yourname/g'
   xcodegen generate
   ```
   The App Group (`group.com.syaahid.waktusolat`) appears in `project.yml` and in `Shared/AppConfig.swift`. The command above updates both.

> **App Groups** let the app, widgets and watch share cached prayer times. Xcode registers the group automatically when signing is set to Automatic. If you use a free Apple ID and Xcode refuses the App Group capability, the app still runs, but the widgets won't see the app's data until you use a paid developer account.

## 3. Run it

- **iPhone:** select the `WaktuSolat` scheme, choose your iPhone, and press Run. Allow location when asked.
- **Apple Watch:** the watch app installs with the iPhone app (check the Watch app on your iPhone → Available Apps if it doesn't appear). To debug it directly, select the `WaktuSolatWatch` scheme and your watch. Turn on Developer Mode on both devices first.
- **Widgets:** long-press the Home Screen or Lock Screen → Edit → Add Widget → *Waktu Solat*.
- **Complication:** long-press the watch face → Edit → Complications → *Waktu Solat*.

**Testing in the Simulator:** in the Simulator menu, choose Features → Location → Custom Location… For example, enter UTP Seri Iskandar at lat `4.385`, long `100.979`. It should resolve to **PRK05**.

---

## How it works

### Data from JAKIM
`Shared/JakimAPI.swift` calls

```
POST https://www.e-solat.gov.my/index.php?r=esolatApi/takwimsolat&period=duration&zone=PRK05
body: datestart=YYYY-MM-DD&dateend=YYYY-MM-DD
```

It downloads yesterday through 31 days ahead. If that request fails, it falls back to `period=month`. The results are cached in the App Group, so the app works offline and widgets don't need the network every time.

### GPS → JAKIM zone
JAKIM has no GPS endpoint, so `Shared/ZoneResolver.swift` works out the zone on the device:

1. It reverse-geocodes your location with Apple Maps to get the state, district and town.
2. It matches the district and town names against the zone list in `Shared/Zones.swift`. The longest match wins, so "Parit Buntar" goes to PRK06, not PRK05's "Parit".
3. If no name matches, it picks the nearest zone in the same state. Special zones (Gunung Jerai, Bukit Larut, Gunung Kinabalu, islands) are only chosen when their name matches.

You can always override this from the map button → choose a zone. Tapping the location button switches back to GPS.

### iPhone ↔ Watch
`PhoneConnectivity` (iPhone) sends the cached schedule with `WCSession.updateApplicationContext`, plus `transferCurrentComplicationUserInfo` when a complication is active. `WatchModel` (watch) saves it to the watch's App Group and reloads the complications. If the phone isn't nearby, the watch downloads from JAKIM using the last zone it received.

### Widgets
`WidgetShared/PrayerTimelineProvider.swift` creates a timeline entry at every prayer time and at midnight for the next 48 hours, so "next prayer" changes exactly on time. When the cache runs low, the provider downloads from JAKIM itself.

---

## Troubleshooting

- **"Couldn't reach JAKIM e-Solat"**: JAKIM's API is unofficial and occasionally changes or goes down. Check the URL in `JakimAPI.swift`. The last good data stays cached.
- **Wrong zone detected**: add the town name to the `extra:` list of the correct zone in `Zones.swift`.
- **Deprecation warnings for `CLGeocoder`** with the iOS 26 SDK: these are warnings only. Apple's replacement is MapKit's `MKReverseGeocodingRequest`, if you want to migrate later.
- **Watch shows "Open Waktu Solat on your iPhone"**: open the iPhone app once so it detects your zone and sends it to the watch.

## Ideas for next steps
- Azan or reminder notifications (`UNUserNotificationCenter`, scheduled from the cached times)
- Qibla direction (JAKIM's response includes a `bearing` field)
- Monthly timetable screen
