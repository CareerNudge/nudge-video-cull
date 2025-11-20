# Project Requirements: Google Authentication (GCP Native)

## 1. Overview
We are implementing "Login with Google" for a macOS SwiftUI application.
**Constraint:** We must use a **GCP-only workflow**. We will configure everything in the Google Cloud Console (Identity Platform). We will NOT create a separate project in the Firebase Console.

## 2. Google Cloud Platform (GCP) Setup Steps
*You (the developer) must perform these infrastructure steps manually before writing code.*

### 2.1. Enable Identity Platform
1.  Go to [Google Cloud Console](https://console.cloud.google.com/).
2.  Create a new Project (e.g., `nudge-video-app-dev`).
3.  Search for **"Identity Platform"** and enable the API.
4.  Go to **Identity Platform > Providers**.
5.  Click **Add a Provider** -> Select **Google**.
6.  Enable it. This will ask you to configure the "OAuth Consent Screen" if not done yet.

### 2.2. Configure OAuth Consent Screen
1.  Go to **APIs & Services > OAuth consent screen**.
2.  Select **External** (since this will be distributed to public users).
3.  Fill in the required fields (App Name, Support Email).
4.  **Scopes:** Add `email` and `profile` and `openid`.
5.  **Test Users:** Add your own email for testing.

### 2.3. Create Credentials (The Critical Step)
We need two specific Client IDs.

1.  Go to **APIs & Services > Credentials**.
2.  **Client ID #1 (macOS):**
    * Click **Create Credentials** -> **OAuth client ID**.
    * Application Type: **iOS** (Use this for macOS too).
    * Bundle ID: `com.yourname.NudgeVideoCull` (Must match Xcode exactly).
    * *Result:* You will get an `iOS Client ID`.
3.  **Client ID #2 (Web/Server):**
    * This is likely already created automatically by Identity Platform. Look for "Web client (auto created by Google Service)".
    * If not, create a **Web application** Client ID.
    * *Result:* You will get a `Web Client ID` and `Client Secret`.

---

## 3. Application Implementation Requirements

### 3.1. Dependencies
The app must use **Swift Package Manager (SPM)**. Add the following packages:

* **Package:** `https://github.com/firebase/firebase-ios-sdk`
    * **Modules:** `FirebaseAuth`
* **Package:** `https://github.com/google/GoogleSignIn-iOS`
    * **Modules:** `GoogleSignIn`, `GoogleSignInSwift`

*Note: Even though we are using GCP Identity Platform, the client SDK is still called `FirebaseAuth`. This is expected.*

### 3.2. Configuration (Programmatic Approach)
**Do NOT use `GoogleService-Info.plist`.** We want to keep the environment clean. Configure the app programmatically in `VideoCullingApp.swift` using the values from Step 2.3.

```swift
import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Configure Firebase/Identity Platform Programmatically
        let options = FirebaseOptions(googleAppID: "YOUR_IOS_GOOGLE_APP_ID",
                                      gcmSenderID: "YOUR_GCM_SENDER_ID")
        options.apiKey = "YOUR_API_KEY" // Found in GCP Credentials
        options.projectID = "nudge-video-app"
        
        FirebaseApp.configure(options: options)
        
        // 2. Configure Google Sign In
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }
}