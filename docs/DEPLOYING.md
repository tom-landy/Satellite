# Deploying Satellite

Two ways onto a phone: straight from Xcode (today, free or paid Apple account), or TestFlight
(paid Developer Program, one click in GitHub Actions once set up).

## On your iPhone from Xcode

The same as Orbit (Orbit's docs/DEPLOYING.md has the full walkthrough and troubleshooting):

1. GitHub Desktop → clone `tom-landy/Satellite`, branch `claude/focused-volta-9s1swz`.
2. Open `Satellite.xcodeproj`, select the **Satellite** target → Signing & Capabilities → Team.
   The project already carries Orbit's team (`NL3QDK93K4`); pick it if Xcode asks.
3. Plug the phone in, choose it as the run destination, ⌘R.

The bundle ID is `com.warhound.satellite` (`SATELLITE_BUNDLE_ID` in the project's build settings).
Change it before the first TestFlight upload if you want something else; it's fixed after that.

## TestFlight

### Once, in a browser

1. **App Store Connect → Apps → + → New App**: iOS · Name **Satellite** (or **Satellite Reader**
   if taken) · English (UK) · Bundle ID `com.warhound.satellite` (if it isn't in the list, register
   it at developer.apple.com → Identifiers → App IDs, with no extra capabilities) · SKU `satellite-ios`.
2. **API key**: App Store Connect → Users and Access → Integrations → App Store Connect API → **+**.
   Name “GitHub”, access **Admin** (needed for Xcode's cloud signing to create the distribution
   certificate; App Manager isn't enough). Download the `.p8` (you only get one chance), and note
   the **Key ID** and the **Issuer ID** at the top of the page. If Orbit already has one, reuse it.
3. **GitHub secrets**: github.com/tom-landy/Satellite → Settings → Secrets and variables →
   Actions → New repository secret, four times:
   - `ASC_KEY_ID`: the Key ID
   - `ASC_ISSUER_ID`: the Issuer ID
   - `ASC_KEY_P8`: open the `.p8` in TextEdit and paste the whole text, including the BEGIN/END lines
   - `TEAM_ID`: optional; leave it out to use the team in the project

### Each release

1. Run `tools/bump-version.sh` and commit (0.1 → 0.2). Optional for test builds: every upload
   gets its own build number anyway (version 0.1, run 7 → build 1.7).
2. GitHub → **Actions → TestFlight → Run workflow** (on the branch you want to ship).
3. About 15 minutes for the build, then 10–30 for Apple to process it. It appears under
   App Store Connect → Satellite → TestFlight. The first time, add yourself under
   **Internal Testing → +**.
4. Install the **TestFlight** app on the phone, accept the invite, tap **Install**.

### If the workflow fails

| Message | Fix |
|---|---|
| *Missing repo secrets* | Step 3 above. |
| *No profiles for 'com.warhound.satellite' were found* / *Cloud signing permission error* | The API key needs **Admin** access (step 2). |
| *No suitable application records were found* | The app record doesn't exist yet, or its bundle ID differs (step 1). |
| *The bundle version must be higher than the previously uploaded version* | Run `tools/bump-version.sh`, commit, run again. |
| Anything else | Copy the red lines from the failed step to me. |

Privacy: the app ships a privacy manifest (`Satellite/PrivacyInfo.xcprivacy`) declaring no
tracking and no data collected. In App Store Connect's App Privacy section, answer
**Data Not Collected**.
