# diabox

`diabox` is a Flutter application designed to help users track the usage and stock of consumable items, likely for managing diabetes-related supplies. The app allows users to define different types of consumables, tracks active items, manages stock, and sends local notifications for expiration reminders. All data is stored locally in a SQLite database.

## Key Features

*   **Consumable Type Management:** Define and manage various types of consumable items, specifying their default lifespan (fixed or flexible).
*   **Active Consumables Tracking:** Monitor currently active consumable items, including their start date, expected end date, and deactivation date.
    *   **Editable Start Dates:** Adjust the start date of an active consumable, which automatically recalculates its expected end date.
    *   **Notes:** Add and view notes for active and used consumables, with the ability to copy notes to the clipboard.
*   **Stock Management:** Efficiently manage the quantity of available items for each consumable type.
    *   Add or remove stock items.
    *   Automatic stock decrement upon activating a new consumable (if enabled).
*   **Expiration Reminders:** Receive timely local notifications before items expire.
    *   **Configurable Notification Offsets:** Set multiple custom time offsets (e.g., 1 day, 3 hours) for reminders before expiration.
    *   Global toggle for notifications.
*   **Barcode Scanning:** Utilize the built-in barcode scanner to extract information like lot numbers for notes.
*   **Data Persistence:** All application data is securely stored locally on the device using a SQLite database.
*   **Data Export/Import:** Easily back up your entire app data to a JSON file and restore it, providing a convenient way to migrate data or create backups.

## Technologies Used

*   **Framework**: Flutter
*   **Language**: Dart
*   **Database**: SQLite (`sqflite` package)
*   **Background Tasks**: `workmanager` package
*   **Notifications**: `flutter_local_notifications` package
*   **Barcode Scanning**: `mobile_scanner` package
*   **File Picker**: `file_picker` package

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

*   Flutter SDK: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)

### Installation

1.  Clone the repo:
    ```sh
    git clone https://github.com/Michi90/diabox.git
    ```
2.  Install packages:
    ```sh
    flutter pub get
    ```
3.  Run the app:
    ```sh
    flutter run
    ```

## Project Structure

The project follows a standard Flutter application architecture:

*   `lib/`: Contains all the Dart source code.
    *   `main.dart`: The entry point of the application, handling initialization of app, database, and background services.
    *   `database_helper.dart`: Manages all SQLite database interactions, including schema creation, CRUD operations, and data migration.
    *   `models/`: Defines the data models for the application, such as `ConsumableType`, `StockItem`, and `ActiveConsumable`.
    *   `screens/`: Contains the application's UI screens, including `HomePage`, `ConsumableTypeDetailScreen`, `SettingsPage`, and `BarcodeScannerScreen`.
    *   `utils/`: Contains utility functions and helper classes, such as formatters and GS1 barcode parser.
    *   `widgets/`: Reusable UI components like `EditNoteDialog`.
    *   `theme/`: Defines the application's color scheme and text themes.
