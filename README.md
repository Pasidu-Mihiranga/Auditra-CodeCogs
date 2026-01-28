# Auditra - Auditing & Valuation ERP

A full-stack application for property valuation and project management built with a Django REST API backend, React web dashboard, and Flutter mobile app.

## Architecture

```
Auditra/
├── backend/              # Django REST API (Python)
├── auditra web app/      # React web dashboard (Vite + MUI)
├── auditra/              # Flutter mobile app (Dart)
```

### Tech Stack

| Layer      | Technology                                      |
|------------|------------------------------------------------|
| Backend    | Django 5.0, Django REST Framework, PostgreSQL  |
| Auth       | JWT (SimpleJWT), role-based access control     |
| Web App    | React 18, Vite, Material-UI 6, Recharts       |
| Mobile App | Flutter 3.10+, Provider, HTTP                  |
| Email      | SendGrid                                       |

## User Roles

| Role              | Web App                 | Mobile App              |
|-------------------|-------------------------|-------------------------|
| Admin             | Full dashboard          | -                       |
| Coordinator       | Project management      | -                       |
| HR Head           | Leave & attendance mgmt | -                       |
| Accessor          | Project review          | -                       |
| Senior Valuer     | Valuation review        | -                       |
| MD/GM             | Project approval        | -                       |
| General Employee  | Attendance, leave, pay  | -                       |
| Client            | View assigned projects  | -                       |
| Agent             | View assigned projects  | -                       |
| Field Officer     | Attendance, leave, pay  | Projects & valuations   |

Field Officers use the **mobile app** for project work (site visits, valuations, photos, GPS) and the **web app** for employee functions (attendance, leave, payments).

All other roles use the **web app** exclusively.

## Getting Started

### Prerequisites

- Python 3.10+
- Node.js 18+
- PostgreSQL 14+
- Flutter SDK 3.10+ (for mobile development)

### 1. Database Setup

Create a PostgreSQL database:

```sql
CREATE DATABASE auditra_db;
```

### 2. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate it (use one for your OS):
#   Windows (cmd):     venv\Scripts\activate
#   Windows (PowerShell): .\venv\Scripts\Activate.ps1
#   macOS/Linux:       source venv/bin/activate
source venv/bin/activate   # macOS/Linux (omit on Windows and use line above)

# Install dependencies
pip install -r requirements.txt

# Configure environment
# Create a .env file in backend/ with your DB credentials (see Environment Variables below)

# Run migrations
python manage.py migrate


# Create admin user
python manage.py createsuperuser
# Start server
python manage.py runserver
```

The API will be available at `http://localhost:8000/api/`.

### 3. Web App Setup

```bash
cd "auditra web app"

# Install dependencies
npm install

# Start dev server
npm run dev
```

The web app will be available at `http://localhost:5173/`.

### 4. Mobile App Setup

```bash
cd auditra

# Get dependencies
flutter pub get

# Run on device/emulator
flutter run
```

## Environment Variables

Create a `.env` file in the `backend/` directory:

```env
# Database
DB_NAME=auditra_db
DB_USER=postgres
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432

# Django
SECRET_KEY=your-secret-key
DEBUG=True

# Email (SendGrid)
SENDGRID_API_KEY=your-sendgrid-api-key
DEFAULT_FROM_EMAIL=your-email@example.com
```

## API Endpoints

### Authentication (`/api/auth/`)

| Method | Endpoint                        | Description              |
|--------|---------------------------------|--------------------------|
| POST   | `/login/`                       | Login (returns JWT)      |
| POST   | `/register/`                    | Register new user        |
| POST   | `/refresh/`                     | Refresh access token     |
| GET    | `/profile/`                     | Get current user profile |
| GET    | `/my-role/`                     | Get current user role    |
| GET    | `/users/`                       | List all users (admin)   |
| POST   | `/assign-role/`                 | Assign role to user      |
| POST   | `/leave-requests/create/`       | Submit leave request     |
| GET    | `/leave-requests/my/`           | My leave requests        |
| GET    | `/leave-requests/`              | All leave requests (admin/HR) |
| PATCH  | `/leave-requests/<pk>/update/`  | Approve/reject leave     |
| GET    | `/leave-requests/statistics/`   | Leave statistics         |
| POST   | `/payment-slips/generate/`      | Generate payment slips   |
| GET    | `/payment-slips/`               | All payment slips        |
| GET    | `/payment-slips/my/`            | My payment slips         |
| POST   | `/removal-requests/create/`     | Submit removal request   |
| GET    | `/removal-requests/`            | List removal requests    |

### Attendance (`/api/attendance/`)

| Method | Endpoint            | Description              |
|--------|---------------------|--------------------------|
| POST   | `/mark/`            | Check in                 |
| POST   | `/checkout/`        | Check out                |
| GET    | `/today/`           | Today's attendance       |
| GET    | `/summary/`         | Attendance summary       |
| GET    | `/summary/weekly/`  | Weekly summary (admin)   |

### Projects (`/api/projects/`)

| Method | Endpoint                              | Description                |
|--------|---------------------------------------|----------------------------|
| GET    | `/`                                   | List projects              |
| POST   | `/`                                   | Create project             |
| GET    | `/<pk>/`                              | Project detail             |
| PUT    | `/<pk>/`                              | Update project             |
| DELETE | `/<pk>/`                              | Delete project             |
| POST   | `/<id>/assign-field-officer/`         | Assign field officer       |
| POST   | `/<id>/assign-client/`                | Assign client              |
| POST   | `/<id>/assign-agent/`                 | Assign agent               |
| POST   | `/<id>/assign-accessor/`              | Assign accessor            |
| POST   | `/<id>/assign-senior-valuer/`         | Assign senior valuer       |
| GET    | `/available-field-officers/`          | List available FOs         |
| GET    | `/available-clients/`                 | List available clients     |
| GET    | `/available-agents/`                  | List available agents      |
| GET    | `/available-accessors/`               | List available accessors   |
| GET    | `/available-senior-valuers/`          | List available SVs         |
| POST   | `/<pk>/md-gm-approve/`               | MD/GM approve project      |
| POST   | `/<pk>/md-gm-reject/`                | MD/GM reject project       |
| POST   | `/documents/`                         | Upload document            |

### Valuations (`/api/valuations/`)

| Method | Endpoint               | Description              |
|--------|------------------------|--------------------------|
| GET    | `/`                    | List valuations          |
| POST   | `/`                    | Create valuation         |
| GET    | `/<pk>/`               | Valuation detail         |
| POST   | `/<pk>/submit/`        | Submit for review        |
| POST   | `/<pk>/review/`        | Review valuation (SV)    |
| POST   | `/<pk>/photos/`        | Upload photos            |

## Project Structure

### Backend (`backend/`)

```
backend/
├── auditra_backend/        # Django project settings
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── authentication/         # Users, roles, leave, payments, removals
├── attendance/             # Check-in/out, summaries, overtime
├── projects/               # Projects, assignments, documents
├── valuations/             # Valuations, photos, GPS data
├── requirements.txt
└── manage.py
```

### Web App (`auditra web app/`)

```
auditra web app/
├── src/
│   ├── api/                # Axios client with JWT interceptor
│   ├── components/         # Layout, Sidebar, shared UI components
│   ├── contexts/           # AuthContext (login state, role)
│   ├── pages/
│   │   ├── admin/          # User mgmt, attendance, leave, payments
│   │   ├── coordinator/    # Project CRUD, assignments
│   │   ├── hr/             # Leave requests, attendance, removals
│   │   ├── accessor/       # Assigned projects
│   │   ├── senior-valuer/  # Valuation review
│   │   ├── md-gm/          # Project approval
│   │   ├── field-officer/  # Attendance/leave/pay dashboard
│   │   ├── shared/         # Common pages (attendance, leave, pay, profile)
│   │   ├── auth/           # Login, Register
│   │   └── public/         # Landing page, public forms
│   ├── services/           # API service modules
│   ├── utils/              # Role config, helpers
│   └── App.jsx             # Router with role-based routing
├── package.json
└── vite.config.js
```

### Mobile App (`auditra/`)

```
auditra/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── home_screen.dart           # Role routing (FO only)
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── field_officer_dashboard.dart
│   │   ├── field_officer/             # FO-specific screens
│   │   ├── valuation_form_screen.dart
│   │   ├── project_details_screen.dart
│   │   ├── payment_slips_screen.dart
│   │   ├── leave_request_screen.dart
│   │   ├── my_leave_requests_screen.dart
│   │   ├── personal_info_screen.dart
│   │   └── change_password_screen.dart
│   ├── models/             # Data models
│   ├── services/           # API & offline services
│   ├── theme/              # App theme & colors
│   └── widgets/            # Reusable widgets
└── pubspec.yaml
```

## Running Both Servers

For development, run the backend and web app simultaneously in separate terminals:

**Terminal 1 - Backend:**
```bash
cd backend
python manage.py runserver
```

**Terminal 2 - Web App:**
```bash
cd "auditra web app"
npm run dev
```

Then open `http://localhost:5173/` in your browser.
