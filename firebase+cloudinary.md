# Firebase & Cloudinary Setup Guide

This project requires Firebase (for authentication, firestore, etc.) and Cloudinary (for media uploads) to function correctly. Since the project's original credentials are not included in this repository, you must set up your own instances of these services.

## 1. Firebase Setup

### Prerequisites
- A Google Account
- [Firebase CLI](https://firebase.google.com/docs/cli) installed (`npm install -g firebase-tools`)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed

### Steps

1. **Create a Firebase Project:**
   - Go to the [Firebase Console](https://console.firebase.google.com/).
   - Click **Add project** and follow the on-screen instructions.

2. **Enable Required Services:**
   - **Authentication:** Go to *Build > Authentication > Sign-in method* and enable the providers you need (e.g., Email/Password, Google).
   - **Cloud Firestore:** Go to *Build > Firestore Database* and click **Create database**. Start in *Test mode* or configure security rules directly from the `firestore.rules` file provided in this repository.

3. **Configure the Flutter App:**
   - Open your terminal and log in to Firebase:
     ```bash
     firebase login
     ```
   - Make sure you are in the `mobile_app` directory:
     ```bash
     cd mobile_app
     ```
   - Run the FlutterFire CLI to configure the app for your Firebase project:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure --project=YOUR_PROJECT_ID
     ```
     *(Replace `YOUR_PROJECT_ID` with the ID of your newly created Firebase project).*
   - This command will automatically generate `lib/firebase_options.dart` and `android/app/google-services.json` (and matching files for iOS/web) containing your specific project credentials.

4. **Deploy Firestore Rules and Indexes:**
   - From the repository root directory, run:
     ```bash
     firebase deploy --only firestore
     ```

## 2. Cloudinary Setup

The app uses Cloudinary for free-tier image and video uploads instead of Firebase Storage.

### Steps

1. **Create a Cloudinary Account:**
   - Go to [Cloudinary](https://cloudinary.com/) and sign up for a free account.

2. **Create an Unsigned Upload Preset:**
   - Go to your Cloudinary **Dashboard**.
   - Navigate to **Settings** (gear icon) > **Upload**.
   - Scroll down to *Upload presets* and click **Add upload preset**.
   - Change the **Signing Mode** to **Unsigned**.
   - Give it a name (e.g., `proxi_unsigned`) and save it.

3. **Get Your Credentials:**
   - Find your **Cloud Name** on your Cloudinary Dashboard.
   - For file deletion features, you will also need your **API Key** and **API Secret**. Go to **Settings > Access Keys** to find these.

4. **Update the App Code:**
   - Open `mobile_app/lib/services/cloudinary_service.dart`.
   - Fill in the credentials at the top of the file:
     ```dart
     static const String cloudName = 'YOUR_CLOUD_NAME';
     static const String uploadPreset = 'YOUR_UPLOAD_PRESET';

     // For deletion support:
     static const String apiKey = 'YOUR_API_KEY';
     static const String apiSecret = 'YOUR_API_SECRET';
     ```

Your app is now connected to your own Firebase and Cloudinary projects!
