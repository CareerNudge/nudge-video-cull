# Nudge Video Cull - App Store Distribution Plan
**Goal:** To prepare, configure, and submit the "Nudge Video Cull" app to the Mac App Store with a trial + subscription model.

This guide is broken into four phases:
1.  **Legal & Account Setup:** The one-time administrative "paperwork."
2.  **Technical App Preparation:** The list of mandatory code changes for your agent.
3.  **App Store Connect Setup:** Creating the "storefront" and the subscription product.
4.  **Submission & Review:** The final process of launching.

---

## Phase 1: Legal & Account Setup (Your Tasks)

Before you can submit anything, you must be a registered Apple Developer.

### 1.1: Enroll in the Apple Developer Program
* **Action:** Go to the [Apple Developer Program website](https://developer.apple.com/programs/enroll/) and enroll.
* **Requirement:** This is a paid program, typically **$99/year**.
* **Result:** You gain access to App Store Connect, the ability to create certificates, and the right to submit apps.

### 1.2: Set Up Agreements, Tax, and Banking
* **Action:** Log in to [App Store Connect](https://appstoreconnect.apple.com/).
* **Requirement:** You cannot sell a paid app (or subscription) until you do this.
* **Details:**
    1.  Go to the **"Agreements, Tax, and Banking"** section.
    2.  Fill out the **"Paid Applications"** agreement.
    3.  Provide your **tax information** (W-9 for U.S. developers).
    4.  Provide your **banking information** so Apple knows where to send your revenue.

---

## Phase 2: Technical App Preparation (Tasks for Coding Agent)

Your coding agent must implement these changes to make the app compliant with App Store policies.

### 2.1: Implement App Sandboxing (Mandatory)
* **Goal:** Restrict the app's access to the file system to only what the user explicitly grants.
* **Actions:**
    1.  **Enable Capability:** In the Xcode project, go to the "Signing & Capabilities" tab, click "+ Capability," and add **App Sandbox**.
    2.  **Set Entitlements:** In the new "App Sandbox" section, check the "File Access" -> "User Selected File" box and set it to **Read/Write**.
    3.  **Add `Info.plist` Key:** Add `com.apple.security.files.user-selected.read-write` as a `Boolean` with a value of `YES`.
    4.  **Implement Security-Scoped Bookmarks:**
        * When a user selects a folder (in `ContentViewModel.selectFolder()`), the app must create a security-scoped bookmark from the URL.
        * The `Data` from this bookmark must be saved to `UserDefaults`.
        * On app launch (in `VideoCullingApp.init()`), the app must load this bookmark `Data` from `UserDefaults`, resolve it back into a URL, and call `url.startAccessingSecurityScopedResource()` to regain access.

### 2.2: Replace FFmpeg with AVFoundation (Mandatory)
* **Goal:** Remove the App Store-incompatible FFmpeg dependency and replace it with Apple's native frameworks.
* **Actions:**
    1.  Remove all `Process` API calls and any bundled `ffmpeg` binaries.
    2.  Refactor `ProcessingService.swift` to handle all exports using `AVFoundation`.
    3.  The service must support two export paths:
        * **Lossless Trim (No LUT):** If *only* trim points are set, use `AVAssetExportSession` with the preset `AVAssetExportPresetPassthrough`. This is a lossless stream copy.
        * **Filtered Export (With LUT):** If a LUT is applied (or any other filter), you *must* re-encode. Use `AVAssetExportSession` with `AVAssetExportPresetHighestQuality`.

### 2.3: Implement LUTs Natively
* **Goal:** Allow users to preview and "bake in" `.cube` LUTs.
* **Actions:**
    1.  **Create `LutParser.swift`:** A utility to read `.cube` files, parse the `LUT_3D_SIZE` (dimension), and convert the RGB color table into a `Data` blob formatted for Core Image (padded with an Alpha channel, e.g., `R G B A R G B A...`).
    2.  **Live Preview:**
        * In `PlayerView.swift`, when a user selects a LUT, create a `CIColorCube` filter.
        * Load the LUT `Data` and `dimension` into the filter.
        * Create an `AVMutableVideoComposition` using `init(asset:applyingCIFiltersWith:)`.
        * Inside the initializer's closure, apply the `CIColorCube` filter to the `request.sourceImage` and call `request.finish(with: outputImage)`.
        * Set this `videoComposition` on the `AVPlayerItem`.
    3.  **Export (Bake-in):**
        * In `ProcessingService.swift`, when handling a "Filtered Export," create the *exact same* `AVMutableVideoComposition` as in the preview.
        * Assign this composition to the `AVAssetExportSession.videoComposition` property before running `await exportSession.export()`.

### 2.4: Implement StoreKit 2 for Subscriptions
* **Goal:** Add the code to manage the $2.99/month subscription and trial.
* **Actions:**
    1.  **Import `StoreKit`**.
    2.  **Create `StoreKitManager.swift`:**
        * Make it an `ObservableObject`.
        * Define `productID: ProductID = "nudge_pro_monthly"`.
        * Add `@Published var isSubscribed: Bool = false`.
        * Add `@Published var products: [Product] = []`.
        * Add a `listenForTransactions()` function that uses `Transaction.updates`.
        * Add an `updateSubscriptionStatus()` function that iterates over `Transaction.currentEntitlements` to check if the user has an *active* entitlement for `productID`.
        * Add `purchase(_ product:)` and `restorePurchases()` functions.
    3.  **Integrate `StoreKitManager`:**
        * Inject it as an `@StateObject` in `VideoCullingApp.swift` and pass it into the view hierarchy using `.environmentObject()`.
    4.  **Create `PaywallView.swift`:**
        * This view is shown if `store.isSubscribed` is `false`.
        * It must fetch and display the `Product` from the `StoreKitManager`.
        * It must clearly display the introductory offer (e.g., "Start with a 1 Month Free Trial") by reading `product.introductoryOffer`.
        * It must have a "Try Free & Subscribe" button that calls `store.purchase()`.
        * It must have a **"Restore Purchases"** button (mandatory).

### 2.5: Add `Info.plist` Privacy & App Icon
* **Goal:** Declare data usage and provide a valid icon.
* **Actions:**
    1.  **App Icon:** Create an `AppIcon.appiconset` in `Assets.xcassets` and provide all required sizes for a macOS app (including the 1024x1024 "App Store" version).
    2.  **Privacy Manifest:** Add these keys to `Info.plist` with clear explanations:
        * `Privacy - Photo Library Usage Description`: "Nudge Video Cull needs to access videos in your library to help you cull and organize them."
        * `Privacy - Sensitive Data Usage Description (Faces)`: "Nudge Video Cull scans your videos locally, on your device, to find and organize faces. This data never leaves your computer and is not shared with anyone."

---

## Phase 3: App Store Connect Setup (Your Tasks)

This is where you create the product page and payment model on Apple's website.



### 3.1: Create Your App Record
1.  Log in to **App Store Connect**.
2.  Go to "My Apps" and click the `+` to create a "New App."
3.  Fill out the initial details:
    * **Name:** `Nudge Video Cull`
    * **Primary Language:** English
    * **Bundle ID:** This *must* match the "Bundle Identifier" in your Xcode project's settings.
    * **SKU:** A unique ID you create, e.g., `NUDGE-001`.

### 3.2: Configure the Subscription Product
1.  In your app's record, go to **"Subscriptions"** in the sidebar.
2.  Click `+` to create a **"Subscription Group"**. Name it something like `Nudge Pro`.
3.  Click `+` to create a subscription product *inside* that group.
4.  **Reference Name:** `Nudge Pro Monthly` (this is for you).
5.  **Product ID:** `nudge_pro_monthly` (this **must match your code** in `StoreKitManager.swift`).
6.  **Subscription Duration:** `1 Month`.
7.  **Price:** Click `+` and set the price to **$2.99**.



### 3.3: Configure the 1-Month Free Trial
1.  On the subscription product page you just created, find the **"Introductory Offers"** section.
2.  Click `+` to create a new offer.
3.  **Type:** Select **Free**.
4.  **Duration:** Select **1 Month**.
5.  **Eligibility:** Select "New Subscribers" (or "All").
6.  Apple's servers will handle this automatically. Your `StoreKit` code will present this offer by default to all eligible users.

### 3.4: Complete the App Store Listing Page
* **Action:** Fill out all the required metadata.
* **App Privacy:** You must fill this out. It's a questionnaire about what data you collect. Since your app is on-device, you will check "Data Not Collected."
* **Screenshots:** You must upload high-quality screenshots of the app in action.
* **Description & Keywords:** Write the marketing text for your app page.

---

## Phase 4: Submission & Review (Final Steps)

### 4.1: Create a Sandbox Tester Account
* **Goal:** To allow Apple's reviewer (and yourself) to test the subscription for free.
* **Action:**
    1.  In App Store Connect, go to **"Users and Access"** -> **"Sandbox Testers"**.
    2.  Click `+` and create a new tester account. Use a real email address you can access.
    3.  You will use this fake Apple ID to log in on your Mac (in "App Store" -> "Sandbox Account") to test your app.

### 4.2: Archive and Upload
1.  In Xcode, make sure your build target is set to **Any Mac (Apple Silicon, Intel)**.
2.  Go to the menu bar and select **Product -> Archive**.
3.  After the build finishes, the "Organizer" window will appear.
4.  Select your new archive and click **"Distribute App"**.
5.  Follow the prompts to upload the app to App Store Connect.

### 4.3: Submit for Review
1.  Go back to your app's page on **App Store Connect**.
2.  Go to the **"App Review"** page.
3.  Select the build you just uploaded.
4.  Fill out the **"App Review Information"** section. This is **CRITICAL**:
    * **Sign-In Information:** Check "Sign-in required" and provide the **Sandbox Tester Account** email and password you created in step 4.1.
    * **Notes:** Write a clear note to the reviewer.
        > **Example Note:**
        > "Hello,
        >
        > This app uses an auto-renewable subscription for all features. Please use the provided Sandbox test account to 'purchase' the plan and test the app.
        >
        > **Sandbox Account:** `tester@example.com`
        > **Password:** `[YourSandboxPassword]`
        >
        > To test the app:
        > 1.  Launch and use the sandbox account to start the free trial.
        > 2.  Click "Select Folder" and choose any folder containing video files (.mov, .mp4).
        >
        > All file access, trimming, and facial recognition (if enabled) is 100% on-device and private. No data is sent to any server. Thank you!"

5.  Click **"Submit for Review"**. You will typically get a response within 24-48 hours.