# Auditra - Full Stack Flutter & Django Application

A complete authentication system with Flutter mobile app and Django backend using PostgreSQL.

## 🚀 Features

- ✅ User Registration
- ✅ User Login with JWT Authentication
- ✅ User Profile Management
- ✅ Beautiful Material Design UI
- ✅ Persistent Session Management
- ✅ PostgreSQL Database
- ✅ RESTful API with Django REST Framework

## 📁 Project Structure

```
Auditra/
├── auditra/              # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── home_screen.dart
│   │   └── services/
│   │       └── api_service.dart
│   └── pubspec.yaml
│
├── backend/              # Django backend
│   ├── auditra_backend/
│   │   ├── settings.py
│   │   └── urls.py
│   ├── authentication/
│   │   ├── views.py
│   │   ├── serializers.py
│   │   └── urls.py
│   ├── manage.py
│   └── requirements.txt
│
└── README.md
```

## 🛠️ Tech Stack

### Frontend
- **Flutter** - Cross-platform mobile framework
- **Dart** - Programming language
- **Material Design 3** - UI/UX

### Backend
- **Django 5.0** - Python web framework
- **Django REST Framework** - API framework
- **PostgreSQL** - Database
- **JWT** - Authentication
- **CORS Headers** - Cross-origin support

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- Flutter SDK (latest stable version)
- Python 3.9+
- PostgreSQL 13+
- Android Studio / Xcode (for mobile development)
- Git

## 🔧 Installation & Setup

### 1. Clone the Repository

```bash
cd Auditra
```

### 2. Backend Setup (Django)

#### Step 1: Install PostgreSQL

**Windows:**
- Download from https://www.postgresql.org/download/windows/
- Install and remember your password

**Mac:**
```bash
brew install postgresql
brew services start postgresql
```

**Linux:**
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
```

#### Step 2: Create Database

```bash
# Connect to PostgreSQL
psql -U postgres

# In PostgreSQL shell:
CREATE DATABASE auditra_db;
\q
```

#### Step 3: Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

#### Step 4: Configure Environment

Create a `.env` file in the `backend/` directory:

```env
DB_NAME=auditra_db
DB_USER=postgres
DB_PASSWORD=your_postgres_password
DB_HOST=localhost
DB_PORT=5432
```

#### Step 5: Run Migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

#### Step 6: Create Superuser (Optional)

```bash
python manage.py createsuperuser
```

#### Step 7: Start Django Server

```bash
python manage.py runserver
```

Backend will be available at: `http://localhost:8000/`

### 3. Frontend Setup (Flutter)

#### Step 1: Install Dependencies

```bash
cd ../auditra
flutter pub get
```

#### Step 2: Configure API URL

Edit `lib/services/api_service.dart` and update the `baseUrl`:

```dart
// For Android Emulator
static const String baseUrl = 'http://10.0.2.2:8000/api';

// For iOS Simulator
static const String baseUrl = 'http://localhost:8000/api';

// For Physical Device (replace with your computer's IP)
static const String baseUrl = 'http://192.168.1.XXX:8000/api';
```

#### Step 3: Run the App

```bash
flutter run
```

## 🌐 API Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/auth/register/` | Register new user | No |
| POST | `/api/auth/login/` | Login user | No |
| GET | `/api/auth/profile/` | Get user profile | Yes |

### Example API Requests

**Register:**
```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username":"testuser",
    "email":"test@example.com",
    "password":"securepass123",
    "password2":"securepass123"
  }'
```

**Login:**
```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "username":"testuser",
    "password":"securepass123"
  }'
```

**Get Profile:**
```bash
curl -X GET http://localhost:8000/api/auth/profile/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## 📱 App Screenshots

### Features:
1. **Splash Screen** - Animated loading screen with branding
2. **Login Screen** - Clean authentication UI with validation
3. **Registration Screen** - Comprehensive signup form
4. **Home Screen** - Dashboard with user info and quick actions

## 🔐 Authentication Flow

1. User registers with username, email, and password
2. Backend validates and creates user account
3. JWT access & refresh tokens are generated
4. Tokens stored securely in device (SharedPreferences)
5. All API requests include Bearer token in headers
6. User stays logged in until explicit logout

## 🐛 Troubleshooting

### Connection Refused Error

**Problem:** Flutter app can't connect to Django backend

**Solutions:**
1. Verify Django is running: `python manage.py runserver`
2. Check firewall settings allow port 8000
3. For physical device, use your computer's IP address
4. Ensure both devices are on same network

### PostgreSQL Connection Error

**Problem:** Django can't connect to PostgreSQL

**Solutions:**
1. Verify PostgreSQL is running: `pg_isready`
2. Check credentials in `.env` file
3. Ensure database `auditra_db` exists
4. Update `pg_hba.conf` for authentication method

### Flutter Build Errors

**Problem:** App won't build or dependencies fail

**Solutions:**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Symlink Error on Windows

Enable Developer Mode:
```
start ms-settings:developers
```

## 🚀 Deployment Tips

### Backend (Django)

1. Set `DEBUG = False` in production
2. Use proper `SECRET_KEY`
3. Configure `ALLOWED_HOSTS`
4. Use environment variables for sensitive data
5. Set up HTTPS
6. Use production WSGI server (Gunicorn, uWSGI)

### Frontend (Flutter)

1. Update API URLs to production
2. Enable code obfuscation
3. Build release APK/IPA:
```bash
flutter build apk --release
flutter build ios --release
```

## 📚 Dependencies

### Flutter (pubspec.yaml)
```yaml
dependencies:
  http: ^1.1.0
  shared_preferences: ^2.2.2
  provider: ^6.1.1
  cupertino_icons: ^1.0.8
```

### Django (requirements.txt)
```
Django==5.0.0
djangorestframework==3.14.0
psycopg==3.1.18
django-cors-headers==4.3.1
python-decouple==3.8
djangorestframework-simplejwt==5.3.1
```

## 🎯 Future Enhancements

- [ ] Email verification
- [ ] Password reset functionality
- [ ] Social authentication (Google, Facebook)
- [ ] Profile picture upload
- [ ] Two-factor authentication
- [ ] Push notifications
- [ ] Dark mode theme
- [ ] Multi-language support

## 📄 License

This project is created for educational purposes.

## 👥 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## 📧 Support

For support, please open an issue in the repository.

---

**Built with ❤️ using Flutter & Django**

# Auditra
