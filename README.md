# Medicoo - Your Personal Health Companion

Medicoo is a comprehensive Flutter-based mobile application designed to empower users in managing their healthcare needs efficiently. It provides a centralized platform for booking appointments, maintaining medical records, tracking medications, connecting with family, and accessing relevant health services.

## Features

Medicoo offers a rich set of features to streamline your healthcare journey:

* **User Authentication:** Secure sign-up and login functionality for personalized access.
* **Profile Management:** Manage personal and account details.
* **Appointment Booking:**
    * Browse doctors by specialty.
    * Select preferred doctors and book appointments.
    * View and manage upcoming and past appointments.
    * Video consultation capabilities.
* **Medical Records:**
    * Store and access personal medical history and records.
    * Manage allergy information.
* **Prescription Management:**
    * Keep track of prescriptions.
    * Set up dosage reminders (via Firebase Cloud Functions and local notifications).
* **Family Module:**
    * Add family members to manage their health profiles.
    * Send and receive requests to link accounts with family members.
* **Lab Test Booking:** Facilitates booking of lab tests.
* **Nearby Services:**
    * Find nearby hospitals, clinics, and pharmacies using Google Places API.
* **Notification Center:**
    * Receive timely reminders for appointments.
    * Get alerts for medication dosages.
    * Notifications for family member requests and confirmations.
* **Medical Voice Assistant:** (Conceptual/Planned Feature)
    * Interact with the app using voice commands for certain functionalities.
* **Cross-Platform:** Built with Flutter for a consistent experience on both Android and iOS.
* **Backend Powered by Firebase:**
    * **Authentication:** Secure user management.
    * **Firestore:** Database for storing user data, appointments, records, etc.
    * **Cloud Functions:** For backend logic like sending notifications for appointments, dosage reminders, and family requests.
    * **Cloud Messaging (FCM):** For push notifications.

## Technologies Used

* **Frontend:** Flutter
* **Backend:** Firebase (Authentication, Firestore, Cloud Functions, FCM)
* **APIs:** Google Places API
* **Programming Language:** Dart
* **State Management:** (Specify if a particular package like Provider, BLoC, Riverpod, GetX is predominantly used - this can be inferred from `pubspec.yaml` or lib structure)
* **Navigation:** (Specify if a particular package like go_router is used)
* **Local Notifications:** For on-device reminders.
* **Video Calling:** (Specify the package used, e.g., Agora, Jitsi Meet, or a custom WebRTC implementation)

## Getting Started

This project is a Flutter application. To get started with development:

1.  **Prerequisites:**
    * Ensure you have Flutter SDK installed. For guidance, visit the [official Flutter installation guide](https://flutter.dev/docs/get-started/install).
    * A code editor like VS Code or Android Studio with Flutter plugins.
    * For Firebase integration, you'll need a Firebase project set up. Place your `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) in the appropriate directories.

2.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd Medicoo
    ```

3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

4.  **Run the application:**
    ```bash
    flutter run
    ```
    This command will run the app on a connected device or emulator.

## Backend Setup (Firebase Cloud Functions)

The `functions` directory contains the Firebase Cloud Functions used for sending notifications and other backend tasks.

1.  **Prerequisites:**
    * Node.js and npm installed.
    * Firebase CLI installed (`npm install -g firebase-tools`).

2.  **Deployment:**
    * Navigate to the `functions` directory: `cd functions`
    * Install dependencies: `npm install`
    * Log in to Firebase: `firebase login`
    * Set your Firebase project: `firebase use <your-firebase-project-id>`
    * Deploy functions: `firebase deploy --only functions`

## Contribution

Contributions are welcome! If you'd like to contribute, please follow these steps:
1. Fork the repository.
2. Create a new branch (`git checkout -b feature/your-feature-name`).
3. Make your changes.
4. Commit your changes (`git commit -m 'Add some feature'`).
5. Push to the branch (`git push origin feature/your-feature-name`).
6. Open a Pull Request.

Please ensure your code adheres to the project's coding standards (e.g., as defined in `analysis_options.yaml`).

