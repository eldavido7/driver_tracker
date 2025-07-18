# Driver Tracker App

A **Flutter-based mobile application** for real-time driver location tracking, trip management, and user profile management. The app allows drivers to start and end trips, share live locations, view trip history, and manage their profiles.

---

## ✅ Features

- **User Authentication**: Secure login and logout using API-based authentication.
- **Real-Time Tracking**: Share live location during trips using Google Maps API and device location services.
- **Trip Management**:
  - Start trips via QR code scanning.
  - End trips with distance and duration calculations.
  - Share trip link to others to view your trip details and live location.
- **Trip History**:
  - View past trips with sorting (by date, distance, duration).
  - Filter (search by origin/destination).
  - Pagination support.
- **Profile Management**: Update user details (name, email, and password) with real-time UI updates across the app.
- **Responsive UI**: Clean, modern interface with animations and gradient designs.

---

## 📦 Prerequisites

- **Flutter SDK**: `>=3.0.0`
- **Dart**: `>=2.17.0`
- **Google Maps API Key**: Required for location tracking and directions.
- **Backend API**: A server supporting:
  - `/api/auth`
  - `/api/sessions`
  - `/api/location`

view backend, test driver qrcode and viewer page for this app here [Taxi Tracker](https://https://github.com/eldavido7/taxi-tracker)

---

## 🚀 Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/driver-tracker-app.git
cd driver-tracker-app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment

Create a `.env` file in the root directory and add:

```bash
API_URL=https://your-backend-api-url.com
MAPS_API_KEY=your-google-maps-api-key
```

Ensure your **backend API** is running and accessible.

Add your google maps API key in the `android/local.properties` file:

```bash
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

### 4. Run the App

```bash
flutter run
```

---

## 📚 Key Dependencies

- `flutter_riverpod: ^2.0.0` – State management
- `http: ^0.13.0` – HTTP requests
- `google_maps_flutter: ^2.0.0` – Google Maps integration
- `flutter_polyline_points: ^1.0.0` – Route polylines
- `location: ^4.0.0` – Device location services
- `share_plus: ^6.0.0` – Trip sharing
- `shared_preferences: ^2.0.0` – Local storage for session IDs

---

## 📖 Usage

- **Login**: Authenticate via the login screen to access the app.
- **Start a Trip**: From `WelcomePage`, tap "Start Tracking" to scan a QR code and start a new trip (navigates to `LiveTrackingPage`).
- **Track Live**: View real-time location on a map, share trip links, and end the trip when complete.
- **View History**: Access `TripHistoryPage` to see past trips, sort by date/distance/duration, or filter by search.
- **Manage Profile**: Update name/email/password in `ProfilePage`, with changes reflected across the app.

---

## 🌐 API Endpoints

- `GET /api/auth/me` → Fetch user data (name, email, sessions)
- `PATCH /api/auth/me` → Update user profile
- `POST /api/sessions` → Create a new session
- `PATCH /api/sessions/:id` → End a session (with distance/duration)
- `GET /api/sessions/:id` → Fetch session details
- `POST /api/location` → Post driver location
- `GET /api/location?sessionId=:id` → Fetch latest location for a session

---
