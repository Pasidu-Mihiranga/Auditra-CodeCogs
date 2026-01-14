# Auditra Flutter App

A Flutter application with Django backend authentication using PostgreSQL.

## Features

- User Registration
- User Login with JWT Authentication
- User Profile Display
- Beautiful Material Design UI
- Persistent Session Management

## Setup Instructions

### Prerequisites

- Flutter SDK installed
- Android Studio / Xcode for mobile development
- Django backend running (see backend/README.md)

### 1. Install Dependencies

```bash
cd auditra
flutter pub get
```

### 2. Configure Backend URL

Edit `lib/services/api_service.dart` and update the `baseUrl`:

- For Android Emulator: `http://10.0.2.2:8000/api`
- For iOS Simulator: `http://localhost:8000/api`
- For Physical Device: `http://YOUR_COMPUTER_IP:8000/api`

### 3. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point with splash screen
├── screens/
│   ├── login_screen.dart     # Login page
│   ├── register_screen.dart  # Registration page
│   └── home_screen.dart      # Home page after login
└── services/
    └── api_service.dart      # API service for backend communication
```

## Backend API Endpoints

- `POST /api/auth/register/` - Register new user
- `POST /api/auth/login/` - Login user
- `GET /api/auth/profile/` - Get user profile

## Important Notes

### For Testing on Physical Device

1. Make sure your computer and phone are on the same network
2. Find your computer's IP address:
   - Windows: `ipconfig`
   - Mac/Linux: `ifconfig`
3. Update the `baseUrl` in `api_service.dart`
4. Make sure Django server allows connections from your network (ALLOWED_HOSTS in settings.py)

### Enable Developer Mode on Windows

If you see symlink errors, run:
```
start ms-settings:developers
```
Then enable "Developer Mode"

## Screenshots

- Login Screen: Clean Material Design with username and password fields
- Register Screen: Comprehensive form with validation
- Home Screen: Dashboard with user profile and quick stats

## Technology Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Django REST Framework
- **Database**: PostgreSQL
- **Authentication**: JWT (JSON Web Tokens)
- **State Management**: Provider (included in dependencies)

## Dependencies

- `http`: ^1.1.0 - HTTP requests
- `shared_preferences`: ^2.2.2 - Local storage
- `provider`: ^6.1.1 - State management
- `cupertino_icons`: ^1.0.8 - iOS icons

## Development

To add new features:

1. Create new screens in `lib/screens/`
2. Add API methods in `lib/services/api_service.dart`
3. Update routes in `main.dart` if needed

## Troubleshooting

### Connection Error

- Verify Django server is running
- Check the baseUrl in api_service.dart
- For physical devices, ensure firewall allows connections
- Test API endpoints using Postman first

### Authentication Issues

- Clear app data: Long press app icon → App Info → Clear Data
- Check token expiration in Django settings
- Verify credentials are correct

## License

This project is for educational purposes.
