# Gemini Project Context: diabox

## Project Overview

`diabox` is a Flutter application designed to help users track the usage and stock of consumable items. Based on the name, it is likely intended for managing diabetes-related supplies. The app allows users to define different types of consumables, each with its own lifespan (either fixed or flexible). It tracks active consumables, manages stock, and sends local notifications to remind users when items are nearing their expiration date. All data is stored locally in a SQLite database.

### Key Technologies

*   **Framework**: Flutter
*   **Language**: Dart
*   **Database**: SQLite (`sqflite` package)
*   **Background Tasks**: `workmanager` package
*   **Notifications**: `flutter_local_notifications` package

### Architecture

The project follows a standard Flutter application architecture:

*   **`lib/`**: Contains all the Dart source code.
    *   **`main.dart`**: The entry point of the application. It initializes the app, database, and background services.
    *   **`database_helper.dart`**: Manages all interactions with the SQLite database, including table creation, CRUD operations, and data migration.
    *   **`models/`**: Defines the data models for the application, such as `ConsumableType`, `StockItem`, and `ActiveConsumable`.
    *   **`screens/`**: Contains the UI of the application.
        *   **`home_page.dart`**: The main screen that displays a list of all consumable types and their current status.
        *   **`consumable_type_detail_screen.dart`**: A screen to view and manage a specific consumable type, its stock, and its usage history.
        *   **`settings_page.dart`**: A screen for app settings, including data export and import.
    *   **`utils/`**: Contains utility functions and helper classes, such as formatters and extensions.

## Building and Running

To build and run this project, use the standard Flutter commands:

1.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

2.  **Run the app:**
    ```bash
    flutter run
    ```

## Development Conventions

*   **Code Style**: The project uses the `flutter_lints` package to enforce the recommended Dart and Flutter coding practices. The configuration can be found in `analysis_options.yaml`.
*   **Database**: The database schema is defined and managed in `lib/database_helper.dart`. The database version is tracked and migrations are handled in the `_onUpgrade` method.
*   **State Management**: The app appears to use `StatefulWidget` and `setState` for managing local state.
