//
//  ContentView.swift
//  FitForecast
//
//  Created by Ashish Kumar/ Manan Gulati on 30/03/25.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData

// MARK: - MODEL

struct Outfit: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let imageName: String
    let location: String

    init(id: UUID = UUID(), name: String, description: String, imageName: String, location: String) {
        self.id = id
        self.name = name
        self.description = description
        self.imageName = imageName
        self.location = location
    }

    init(entity: OutfitEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.description = entity.desc ?? ""
        self.imageName = entity.imageName ?? ""
        self.location = entity.location ?? "Unknown"
    }
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
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        reverseGeocode(location)
    }

    func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            if let city = placemarks?.first?.locality {
                DispatchQueue.main.async { self.currentCity = city }
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

// MARK: - VIEWMODELS

class OutfitViewModel: ObservableObject {
    @Published var savedOutfits: [Outfit] = []
    @Published var currentWeather: String = "Fetching weather..."
    @Published var isLoading: Bool = false            // ← Loading indicator

    private var viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchOutfitsFromCoreData()
    }

    func saveOutfit(_ outfit: Outfit) {
        let newOutfit = OutfitEntity(context: viewContext)
        newOutfit.id = outfit.id
        newOutfit.name = outfit.name
        newOutfit.desc = outfit.description
        newOutfit.imageName = outfit.imageName
        newOutfit.location = outfit.location

        do {
            try viewContext.save()
            fetchOutfitsFromCoreData()
        } catch {
            print("Error saving outfit: \(error.localizedDescription)")
        }
    }

    func removeOutfit(at index: Int) {
        guard index >= 0 && index < savedOutfits.count else { return }
        let target = savedOutfits[index]
        let req: NSFetchRequest<OutfitEntity> = OutfitEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", target.id as CVarArg)
        do {
            let results = try viewContext.fetch(req)
            results.forEach(viewContext.delete)
            try viewContext.save()
            fetchOutfitsFromCoreData()
        } catch {
            print("Error deleting outfit: \(error.localizedDescription)")
        }
    }

    func fetchOutfitsFromCoreData() {
        let req: NSFetchRequest<OutfitEntity> = OutfitEntity.fetchRequest()
        do {
            let entities = try viewContext.fetch(req)
            savedOutfits = entities.map { Outfit(entity: $0) }
        } catch {
            print("Error fetching outfits: \(error.localizedDescription)")
            savedOutfits = []
        }
    }

    func fetchWeather(for city: String) {
        DispatchQueue.main.async { self.isLoading = true } // ← start spinner
        let apiKey = "de0c0e5ab35f416a88b53710252004"
        let q = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        guard let url = URL(string: "https://api.weatherapi.com/v1/current.json?key=\(apiKey)&q=\(q)") else {
            DispatchQueue.main.async {
                self.currentWeather = "Invalid city"
                self.isLoading = false                      // ← stop spinner
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            defer { DispatchQueue.main.async { self.isLoading = false } } // ← always stop

            if let err = error {
                DispatchQueue.main.async { self.currentWeather = "Error: \(err.localizedDescription)" }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.currentWeather = "No data" }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(WeatherResponse.self, from: data)
                let temp = Int(decoded.current.temp_f)
                let cond = decoded.current.condition.text
                DispatchQueue.main.async { self.currentWeather = "\(temp)°F, \(cond)" }
            } catch {
                DispatchQueue.main.async { self.currentWeather = "Decode failed" }
            }
        }.resume()
    }
}

class PreferencesViewModel: ObservableObject {
    @Published var weatherSensitivity: Double = 0.5
    @Published var prefersCasual: Bool = true

    private var viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        loadPreferences()
    }

    func loadPreferences() {
        let req: NSFetchRequest<UserPreferencesEntity> = UserPreferencesEntity.fetchRequest()
        req.fetchLimit = 1
        do {
            if let prefs = try viewContext.fetch(req).first {
                weatherSensitivity = prefs.weatherSensitivity
                prefersCasual       = prefs.prefersCasual
            } else {
                savePreferences()
            }
        } catch {
            print("Error loading prefs: \(error.localizedDescription)")
        }
    }

    func savePreferences() {
        let req: NSFetchRequest<UserPreferencesEntity> = UserPreferencesEntity.fetchRequest()
        do {
            let prefs = try viewContext.fetch(req).first ?? UserPreferencesEntity(context: viewContext)
            prefs.id                 = prefs.id ?? "user_preferences"
            prefs.weatherSensitivity = weatherSensitivity
            prefs.prefersCasual      = prefersCasual
            try viewContext.save()
        } catch {
            print("Error saving prefs: \(error.localizedDescription)")
        }
    }
}

// MARK: - BUTTON STYLE

struct RoundedGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: configuration.isPressed
                        ? [Color.purple, Color.blue]
                        : [Color.blue, Color.purple]),
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
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()

    @AppStorage("isDarkMode") private var isDarkMode: Bool = true  // ← Dark mode toggle

    var body: some View {
        TabView {
            NavigationStack { WelcomeView() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { SavedOutfitsView() }
                .tabItem { Label("Saved", systemImage: "star.fill") }

            NavigationStack { NotificationView() }
                .tabItem { Label("Alerts", systemImage: "bell") }
        }
        .environmentObject(OutfitViewModel(context: viewContext))
        .environmentObject(locationManager)
        .environmentObject(PreferencesViewModel(context: viewContext))
        .preferredColorScheme(isDarkMode ? .dark : .light)           // ← apply scheme
    }
}

// MARK: - WELCOME VIEW

struct WelcomeView: View {
    @EnvironmentObject var viewModel: OutfitViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var cityName: String = ""

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Welcome to FitForecast")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
                    .padding(.top, 40)

                Text("Get real-time weather updates and outfit suggestions tailored just for you.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Map(coordinateRegion: $locationManager.region)
                    .frame(height: 200)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)

                TextField("Enter City Name", text: $cityName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .onAppear {
                        if !UserDefaults.standard.lastUsedCity.isEmpty {
                            cityName = UserDefaults.standard.lastUsedCity
                        }
                    }

                Button("Allow Location") {
                    locationManager.requestLocation()
                }
                .buttonStyle(RoundedGradientButtonStyle())

                if !locationManager.currentCity.isEmpty {
                    Text("Detected City: \(locationManager.currentCity)")
                        .foregroundColor(.green)
                        .padding(.bottom, 10)
                }

                NavigationLink(
                    destination: HomeView(cityName: cityName.isEmpty
                        ? locationManager.currentCity
                        : cityName)
                ) {
                    Text("Let's Begin")
                }
                .buttonStyle(RoundedGradientButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    let cityToSave = cityName.isEmpty
                        ? locationManager.currentCity
                        : cityName
                    if !cityToSave.isEmpty {
                        UserDefaults.standard.lastUsedCity = cityToSave
                    }
                })

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
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text(cityName.isEmpty ? "City: Unknown" : "City: \(cityName)")
                        .font(.headline)

                    HStack(spacing: 10) {
                        Image(systemName: "cloud.sun.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                        Text(viewModel.currentWeather)
                            .font(.subheadline)
                    }

                    Button("Refresh Weather") {
                        viewModel.fetchWeather(for: cityName)
                    }
                    .buttonStyle(RoundedGradientButtonStyle())

                    VStack(spacing: 10) {
                        Text("Recommended Outfit")
                            .font(.headline)
                        Text(dynamicEmoji)
                            .font(.title2)
                            .bold()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)

                    NavigationLink {
                        OutfitDetailView(
                            outfit: Outfit(
                                name: "Dynamic Look",
                                description: "Tailored to your local weather.",
                                imageName: "sun.max.fill",
                                location: cityName
                            )
                        )
                    } label: {
                        Text("View Outfit Detail")
                    }
                    .buttonStyle(RoundedGradientButtonStyle())

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Home")
            .onAppear { viewModel.fetchWeather(for: cityName) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { PreferencesView() } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }

            // ← Loading spinner overlay
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding(30)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(12)
            }
        }
    }

    private var dynamicEmoji: String {
        let weather = viewModel.currentWeather.lowercased()
        switch true {
        case weather.contains("snow"):   return "🧥 + 🧤"
        case weather.contains("rain"), weather.contains("drizzle"): return "🌂 + 🧥"
        case weather.contains("cloud"): return "🧢 + 🧥"
        case weather.contains("sunny"), weather.contains("clear"): return "👕 + 🩳"
        case weather.contains("storm"): return "🌩️ + 🧥"
        default:                         return "🧥 + 👖"
        }
    }
}

// MARK: - PREFERENCES VIEW

struct PreferencesView: View {
    @EnvironmentObject private var preferencesViewModel: PreferencesViewModel
    @AppStorage("isDarkMode") private var isDarkMode: Bool = true

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Toggle("Dark Mode", isOn: $isDarkMode)
            }
            Section(header: Text("Weather Sensitivity")) {
                Slider(value: $preferencesViewModel.weatherSensitivity, in: 0...1)
                    .onChange(of: preferencesViewModel.weatherSensitivity) { _ in
                        preferencesViewModel.savePreferences()
                    }
            }
            Section(header: Text("Outfit Style")) {
                Toggle("Prefer Casual", isOn: $preferencesViewModel.prefersCasual)
                    .onChange(of: preferencesViewModel.prefersCasual) { _ in
                        preferencesViewModel.savePreferences()
                    }
            }
        }
        .navigationTitle("Preferences")
    }
}

// MARK: - OUTFIT DETAIL VIEW

struct OutfitDetailView: View {
    @EnvironmentObject var viewModel: OutfitViewModel
    @EnvironmentObject var locationManager: LocationManager
    let outfit: Outfit
    @State private var showSaveConfirmation = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 15) {
                Image(systemName: outfit.imageName)
                    .resizable().scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.orange)

                Text(outfit.name)
                    .font(.title)

                Text("Recommended for: \(outfit.location)")
                    .font(.subheadline)

                HStack(spacing: 8) {
                    ForEach(outfitTags(for: viewModel.currentWeather), id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }

                Text(recommendationReason(for: viewModel.currentWeather))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Save Outfit") {
                    let city = locationManager.currentCity.isEmpty
                        ? outfit.location
                        : locationManager.currentCity
                    let toSave = Outfit(
                        id: outfit.id,
                        name: outfit.name,
                        description: outfit.description,
                        imageName: outfit.imageName,
                        location: city
                    )
                    viewModel.saveOutfit(toSave)
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

    private func outfitTags(for weather: String) -> [String] {
        let lower = weather.lowercased()
        if lower.contains("snow") {
            return ["Jacket", "Gloves", "Boots"]
        } else if lower.contains("rain") {
            return ["Raincoat", "Boots", "Umbrella"]
        } else if lower.contains("cloud") {
            return ["Jacket", "Jeans", "Cap"]
        } else if lower.contains("sunny") || lower.contains("clear") {
            return ["T-shirt", "Shorts", "Sneakers"]
        } else {
            return ["Light Jacket", "Jeans", "Shoes"]
        }
    }

    private func recommendationReason(for weather: String) -> String {
        let lower = weather.lowercased()
        if lower.contains("snow") {
            return "Recommended for cold and snowy conditions to keep you warm."
        } else if lower.contains("rain") {
            return "Stay dry and comfortable during rainy weather."
        } else if lower.contains("cloud") {
            return "Cloudy skies call for a mix of warm and cool layers."
        } else if lower.contains("sunny") || lower.contains("clear") {
            return "Ideal for warm sunny days – keeps you cool and comfortable."
        } else {
            return "A balanced outfit for mixed weather conditions."
        }
    }
}

// MARK: - OUTFIT SAVED CONFIRMATION VIEW

struct OutfitSavedConfirmationView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Your Outfit has been Saved!")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("You can view it in your Saved Outfits list.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Saved!")
        }
    }
}

// MARK: - SAVED OUTFITS VIEW

struct SavedOutfitsView: View {
    @EnvironmentObject var viewModel: OutfitViewModel
    @State private var showDeleteAlert = false
    @State private var outfitToDelete: IndexSet?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack {
                if viewModel.savedOutfits.isEmpty {
                    Text("No outfits saved yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.savedOutfits) { outfit in
                            NavigationLink {
                                OutfitDetailView(outfit: outfit)
                            } label: {
                                HStack {
                                    Image(systemName: outfit.imageName)
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                    VStack(alignment: .leading) {
                                        Text(outfit.name)
                                            .font(.headline)
                                        Text("Saved for \(outfit.location)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { idx in
                            outfitToDelete = idx
                            showDeleteAlert = true
                        }
                    }
                    .alert(isPresented: $showDeleteAlert) {
                        Alert(
                            title: Text("Delete Outfit"),
                            message: Text("Are you sure you want to delete this outfit?"),
                            primaryButton: .destructive(Text("Delete")) {
                                if let i = outfitToDelete?.first {
                                    viewModel.removeOutfit(at: i)
                                }
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .navigationTitle("Saved Outfits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

// MARK: - NOTIFICATION VIEW

struct NotificationView: View {
    @State private var notificationsEnabled: Bool = UserDefaults.standard.notificationsEnabled

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Notifications")
                    .font(.largeTitle)
                    .padding(.top, 40)

                Toggle("Enable Daily Weather Alerts", isOn: $notificationsEnabled)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .onChange(of: notificationsEnabled) { newValue in
                        UserDefaults.standard.notificationsEnabled = newValue
                    }

                if notificationsEnabled {
                    Text("You will receive daily outfit recommendations based on weather.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("No new notifications.")
                }

                Spacer()
            }
            .navigationTitle("Alerts")
        }
    }
}

// MARK: - PREVIEW

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let pm = PersistenceManager.shared
        ContentView()
            .environment(\.managedObjectContext, pm.container.viewContext)
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    static let lastCityKey      = "lastUsedCity"
    static let notificationsKey = "notificationsEnabled"

    var lastUsedCity: String {
        get { string(forKey: Self.lastCityKey) ?? "" }
        set { set(newValue, forKey: Self.lastCityKey) }
    }

    var notificationsEnabled: Bool {
        get { bool(forKey: Self.notificationsKey) }
        set { set(newValue, forKey: Self.notificationsKey) }
    }
}

