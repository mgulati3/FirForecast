
# ☀️ FitForecast

**FitForecast** is a smart weather-based outfit recommendation app built with **SwiftUI**. It gives personalized clothing suggestions based on real-time weather and user preferences, enhancing both comfort and style.

---

## 📱 Features

- 🌦 **Real-time Weather Integration**  
  Uses [WeatherAPI](https://www.weatherapi.com/) to fetch current weather data for your location or manual input.

- 👕 **Dynamic Outfit Recommendations**  
  Recommends clothing using weather-specific emojis and explanations.

- 💾 **Save & Revisit Outfits**  
  Core Data integration to store, update, and delete outfit history.

- 🎨 **User Preferences**  
  Customize outfit style (casual/formal) and weather sensitivity via sliders and toggles.

- 📍 **Location Services**  
  Uses `MapKit` & `CLLocationManager` to detect city automatically.

- 🌓 **Dark/Light Mode Support**  
  User-controlled toggle stored via `@AppStorage`.

- ⏳ **Loading States**  
  Smooth UX with spinners during weather fetch operations.

---

## 🛠 Tech Stack

- **SwiftUI**
- **Core Data**
- **WeatherAPI**
- **MapKit**
- **MVVM Design Pattern**

---

## 📂 Project Structure

- `ContentView.swift` – main app layout
- `OutfitViewModel.swift` – business logic & weather fetching
- `LocationManager.swift` – handles location permissions
- `PersistenceManager.swift` – Core Data setup
- `Assets.xcassets` – app logo & icons

---

## 📸 App Logo

![LOGO](https://github.com/user-attachments/assets/4081967e-8d88-4e62-ae9e-b1ee42176d76)

---

## 🚀 Getting Started

1. Clone the repository
2. Open `FitForecast.xcodeproj`
3. Run on a simulator or physical device with iOS 15.0+
4. Make sure to allow **Location Access** for full functionality
5. To enable weather fetching, replace the WeatherAPI key if needed in `OutfitViewModel.swift`

---

## Credits

Developed by **Manan Gulati**
CSE 335 – Principles of Mobile Computing
Arizona State University

---

## UI Walkthrough

## 1) HOME PAGE

![Simulator Screenshot - iPhone 16 Pro - 2025-04-21 at 18 29 53](https://github.com/user-attachments/assets/4e12554b-07f8-494f-816b-5276b7619716)

## 2) WEATHER DETAILS OF THAT PARTICULAR AREA

![Simulator Screenshot - iPhone 16 Pro - 2025-04-21 at 18 30 03](https://github.com/user-attachments/assets/eb2fa3fd-f627-48b9-ab2a-e4c3deff090d)

## 3) CLOTHING SUGGESTING FOR THAT PARTICULAR AREA

![Simulator Screenshot - iPhone 16 Pro - 2025-04-21 at 18 30 10](https://github.com/user-attachments/assets/63cf4c30-12df-40fa-873d-16a9f9bd9309)

## 4) SAVED OUTFIT FOR AREA

![Simulator Screenshot - iPhone 16 Pro - 2025-04-21 at 18 30 17](https://github.com/user-attachments/assets/ebbda5a6-a5cb-4c8e-91e8-239e761aad6f)

## 5) SETTING TO TRANSITION BETWEEN LIGHT MODE / DARK MODE

![Simulator Screenshot - iPhone 16 Pro - 2025-04-21 at 18 30 32](https://github.com/user-attachments/assets/881094bd-5a12-4fb4-933e-d5930b9c16a0)

# 6) SETTING ALERT PAGE

![Simulator Screenshot - iPhone 16 Pro - 2025-04-21 at 18 30 37](https://github.com/user-attachments/assets/4c077c15-9494-4200-b020-726feee48043)


---

## 🚧 Future Improvements

- [ ] Multi-day weather forecast
- [ ] Custom outfit image uploads
- [ ] Smart notifications based on weather changes
- [ ] Internationalization (i18n) support


---

## 🔐 API Key

This app uses [WeatherAPI](https://www.weatherapi.com/). Register for a free API key and add it here:

```swift
let apiKey = "your-api-key"
