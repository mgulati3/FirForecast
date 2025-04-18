//
//  ContentView.swift
//  FitForecast
//
//  Created by Manan Gulati on 30/03/25.
//

import SwiftUI
import MapKit

// MARK: - MODEL
struct Outfit: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let imageName: String
}

// MARK: - VIEWMODEL
class OutfitViewModel: ObservableObject {
    @Published var savedOutfits: [Outfit] = []
    
    // Save outfit function
    func saveOutfit(_ outfit: Outfit) {
        savedOutfits.append(outfit)
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

// MARK: - MAIN CONTENT VIEW (TabView)
struct ContentView: View {
    @StateObject private var viewModel = OutfitViewModel()
    
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
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - 1) WELCOME VIEW
struct WelcomeView: View {
    @EnvironmentObject var viewModel: OutfitViewModel
    @State private var cityName: String = ""
    
    // For MapKit
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334722, longitude: -122.008889),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("👋 Welcome to Weather Outfit!")
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
                    .foregroundColor(.white)
                
                Text("Get real-time weather updates and outfit suggestions tailored just for you.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                // Map View using MapKit
                Map(coordinateRegion: $region)
                    .frame(height: 200)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                
                TextField("Enter City Name", text: $cityName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                
                Button("Allow Location") {
                }
                .buttonStyle(RoundedGradientButtonStyle())
                
                NavigationLink(destination: HomeView(cityName: cityName)) {
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

// MARK: - 2) HOME VIEW
struct HomeView: View {
    @EnvironmentObject var viewModel: OutfitViewModel
    var cityName: String
    @State private var weatherText: String = "72°F, Sunny"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text(cityName.isEmpty ? "City: Unknown City" : "City: \(cityName)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 10) {
                        Image(systemName: "sun.max.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.yellow)
                        Text(weatherText)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    Button("Refresh Weather") {
                        // Simulate a weather update
                        let possibleWeathers = ["68°F, Cloudy", "75°F, Sunny", "70°F, Rainy", "66°F, Windy"]
                        weatherText = possibleWeathers.randomElement() ?? "72°F, Sunny"
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
            .toolbar {
                // Toolbar button to navigate to Preferences
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

// MARK: - NEW: PREFERENCES VIEW
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

// MARK: - 3) OUTFIT DETAIL VIEW
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

// MARK: - 3.5) OUTFIT SAVED CONFIRMATION VIEW
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

// MARK: - 4) SAVED OUTFITS VIEW
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

// MARK: - 5) NOTIFICATION VIEW
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

// MARK: - PREVIEWS
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

