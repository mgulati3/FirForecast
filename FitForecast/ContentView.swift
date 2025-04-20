//
//  ContentView.swift
//  FitForecast
//
//  Created by Ashish Kumar on 30/03/25.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - MODEL
struct Outfit: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let imageName: String
}

struct WeatherResponse: Codable {
    struct Current: Codable {
        let temp_f: Double
        let condition: Condition
    }

    struct Condition: Codable {
        let text: String
        let icon: String
    }

    let current: Current
}

// MARK: - LOCATION MANAGER
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var currentCity: String = ""
    @Published var locationPermissionDenied = false

    // ✅ New: track live region
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334722, longitude: -122.008889),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        // ✅ Update the map region
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }

        reverseGeocode(location)
    }

    func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let city = placemarks?.first?.locality {
                DispatchQueue.main.async {
                    self.currentCity = city
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied {
            locationPermissionDenied = true
        }
    }
}

// MARK: - VIEWMODEL
class OutfitViewModel: ObservableObject {
    @Published var savedOutfits: [Outfit] = []
    @Published var currentWeather: String = "Fetching weather..."

    func saveOutfit(_ outfit: Outfit) {
        savedOutfits.append(outfit)
    }

    func fetchWeather(for city: String) {
        let apiKey = "de0c0e5ab35f416a88b53710252004"
        let query = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let urlString = "https://api.weatherapi.com/v1/current.json?key=\(apiKey)&q=\(query)"

        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.currentWeather = "Invalid city name"
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.currentWeather = "Error: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.currentWeather = "No data received"
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(WeatherResponse.self, from: data)
                let temp = Int(decoded.current.temp_f)
                let condition = decoded.current.condition.text
                DispatchQueue.main.async {
                    self.currentWeather = "\(temp)°F, \(condition)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentWeather = "Failed to decode weather"
                }
            }
        }.resume()
    }
}

// MARK: - CUSTOM BUTTON STYLE
struct RoundedGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: configuration.isPressed ? [Color.purple, Color.blue] : [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    @StateObject private var viewModel = OutfitViewModel()
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        TabView {
            NavigationStack {
                WelcomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                SavedOutfitsView()
            }
            .tabItem {
                Label("Saved", systemImage: "star.fill")
            }

            NavigationStack {
                NotificationView()
            }
            .tabItem {
                Label("Alerts", systemImage: "bell")
            }
        }
        .environmentObject(viewModel)
        .environmentObject(locationManager)
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - WELCOME VIEW
struct WelcomeView: View {
    @EnvironmentObject var viewModel: OutfitViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var cityName: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Welcome to FitForecast")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)

                Text("Get real-time weather updates and outfit suggestions tailored just for you.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                // BIND MapKit view to real-time user region
                Map(coordinateRegion: $locationManager.region)
                    .frame(height: 200)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)

                TextField("Enter City Name", text: $cityName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)

                Button("Allow Location") {
                    locationManager.requestLocation()
                }
                .buttonStyle(RoundedGradientButtonStyle())

                if !locationManager.currentCity.isEmpty {
                    Text("Detected City: \(locationManager.currentCity)")
                        .foregroundColor(.green)
                        .padding(.bottom, 10)
                }

                NavigationLink(destination: HomeView(cityName: cityName.isEmpty ? locationManager.currentCity : cityName)) {
                    Text("Let's Begin")
                }
                .buttonStyle(RoundedGradientButtonStyle())

                Spacer()
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}

// MARK: - HOME VIEW
struct HomeView: View {
    @EnvironmentObject var viewModel: OutfitViewModel
    var cityName: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text(cityName.isEmpty ? "City: Unknown City" : "City: \(cityName)")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(spacing: 10) {
                        Image(systemName: "cloud.sun.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.yellow)

                        Text(viewModel.currentWeather)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }

                    Button("Refresh Weather") {
                        viewModel.fetchWeather(for: cityName)
                    }
                    .buttonStyle(RoundedGradientButtonStyle())

                    VStack(spacing: 10) {
                        Text("Recommended Outfit")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("👕 + 🩳")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)

                    NavigationLink("View Outfit Detail") {
                        OutfitDetailView(
                            outfit: Outfit(
                                name: "Summer Vibes",
                                description: "T-Shirt, Shorts, Sneakers",
                                imageName: "sun.max.fill"
                            )
                        )
                    }
                    .buttonStyle(RoundedGradientButtonStyle())

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Home")
            .onAppear {
                viewModel.fetchWeather(for: cityName)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        PreferencesView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Preferences View
struct PreferencesView: View {
    @State private var weatherSensitivity: Double = 0.5
    @State private var prefersCasual: Bool = true

    var body: some View {
        Form {
            Section(header: Text("Weather Sensitivity")) {
                Slider(value: $weatherSensitivity, in: 0...1)
            }
            Section(header: Text("Outfit Style")) {
                Toggle("Prefer Casual Outfits", isOn: $prefersCasual)
            }
        }
        .navigationTitle("Preferences")
    }
}

// MARK: - Remaining Views
// Same as previous: OutfitDetailView, OutfitSavedConfirmationView, SavedOutfitsView, NotificationView, and ContentView_Previews.


// MARK: - OUTFIT DETAIL VIEW
struct OutfitDetailView: View {
    @EnvironmentObject var viewModel: OutfitViewModel
    let outfit: Outfit
    @State private var showSaveConfirmation = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 15) {
                Image(systemName: outfit.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.orange)

                Text(outfit.name)
                    .font(.title)
                    .foregroundColor(.white)

                Text(outfit.description)
                    .font(.body)
                    .padding(.horizontal)
                    .foregroundColor(.gray)

                Button("Save Outfit") {
                    viewModel.saveOutfit(outfit)
                    showSaveConfirmation = true
                }
                .buttonStyle(RoundedGradientButtonStyle())
                .padding(.top, 20)

                Spacer()
            }
            .padding()
            .navigationTitle("Outfit Detail")
            .navigationDestination(isPresented: $showSaveConfirmation) {
                OutfitSavedConfirmationView()
            }
        }
    }
}

// MARK: - OUTFIT SAVED CONFIRMATION VIEW
struct OutfitSavedConfirmationView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Your Outfit has been Saved!")
                    .font(.title2)
                    .foregroundColor(.green)

                Text("You can view it in your Saved Outfits list.")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            .padding()
            .navigationTitle("Saved!")
        }
    }
}

// MARK: - SAVED OUTFITS VIEW
struct SavedOutfitsView: View {
    @EnvironmentObject var viewModel: OutfitViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                if viewModel.savedOutfits.isEmpty {
                    Text("No outfits saved yet.")
                        .font(.subheadline)
                        .padding()
                        .foregroundColor(.gray)
                } else {
                    List(viewModel.savedOutfits) { outfit in
                        HStack {
                            Image(systemName: outfit.imageName)
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(outfit.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(outfit.description)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(Color.black)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Saved Outfits")
        }
    }
}

// MARK: - NOTIFICATION VIEW
struct NotificationView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Notifications")
                    .font(.largeTitle)
                    .padding(.top, 40)
                    .foregroundColor(.white)
                Text("No new notifications.")
                    .font(.body)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .navigationTitle("Alerts")
        }
    }
}

// MARK: - PREVIEW
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

