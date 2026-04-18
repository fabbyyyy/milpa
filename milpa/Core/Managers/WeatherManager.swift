import Foundation
import WeatherKit
import CoreLocation
import Combine

/// Simple weather data for the UI
struct MilpaWeather {
    let highTemp: String          // e.g. "34°"
    let rainMM: String            // e.g. "12mm"
    let humidity: String          // e.g. "68%"
    let alertMessage: String      // e.g. "Riesgo de estrés hídrico..."
    let locationName: String      // e.g. "Nuevo León"
    let isOffline: Bool           // true if this is AI-estimated
    
    var audioSummary: String {
        "\(alertMessage). Máxima de \(highTemp). \(rainMM) de lluvia esperada. Humedad: \(humidity)."
    }
}

@MainActor
final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    
    @Published var weather: MilpaWeather?
    @Published var isLoading = false
    
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared
    private let foundationModels = FoundationModelManager.shared
    private var lastLocation: CLLocation?
    private var lastFetchTime: Date?
    private var fetchTimer: AnyCancellable?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        setupTimer()
    }
    
    private func setupTimer() {
        fetchTimer = Timer.publish(every: 1800, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.requestWeather(force: true)
            }
    }
    
    func requestWeather(force: Bool = false) {
        guard !isLoading else { return }
        if !force, let last = lastFetchTime, Date().timeIntervalSince(last) < 1800 {
            return
        }
        
        isLoading = true
        
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        } else {
            // No location permission — use default coordinates (Monterrey, NL)
            Task {
                await fetchWeather(for: CLLocation(latitude: 25.6866, longitude: -100.3161), name: "Nuevo León")
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            self.lastLocation = location
            await self.fetchWeather(for: location, name: nil)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error)")
        Task { @MainActor in
            // Fallback: Monterrey, NL
            await self.fetchWeather(for: CLLocation(latitude: 25.6866, longitude: -100.3161), name: "Nuevo León")
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
    
    // MARK: - Fetch
    
    private func fetchWeather(for location: CLLocation, name: String?) async {
        // Resolve location name
        let locationName: String
        if let name = name {
            locationName = name
        } else {
            let geocoder = CLGeocoder()
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            locationName = placemarks?.first?.administrativeArea ?? placemarks?.first?.locality ?? "Tu zona"
        }
        
        do {
            let forecast = try await weatherService.weather(for: location)
            let today = forecast.dailyForecast.first
            let current = forecast.currentWeather
            
            let high = today?.highTemperature.value ?? current.temperature.value
            let precip = today?.precipitationAmount.value ?? 0
            let humid = current.humidity * 100
            
            // Generate smart alert with Foundation Models
            let alert = await generateAlert(
                high: high, precip: precip, humidity: humid, location: locationName
            )
            
            self.weather = MilpaWeather(
                highTemp: "\(Int(high))°",
                rainMM: precip > 0 ? "\(Int(precip))mm" : "0mm",
                humidity: "\(Int(humid))%",
                alertMessage: alert,
                locationName: locationName,
                isOffline: false
            )
        } catch {
            print("⛅ WeatherKit error: \(error). Using AI fallback.")
            await fetchOfflineFallback(location: locationName)
        }
        
        self.lastFetchTime = Date()
        isLoading = false
    }
    
    private func fetchOfflineFallback(location: String) async {
        do {
            let monthName = {
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "es_MX")
                fmt.dateFormat = "MMMM"
                return fmt.string(from: Date())
            }()
            
            let response = try await foundationModels.oneShot("""
            Basándote en patrones históricos de clima para \(location), México, en el mes de \(monthName), estima valores numéricos probables.
            Luego, escribe una alerta agrícola muy breve, de UNA SOLA ORACIÓN y máximo 15 palabras.
            Retorna UNICAMENTE con esta estructura unida por '|':
            TEMP_MAX|LLUVIA_MM|HUMEDAD_PORCIENTO|ALERTA_BREVE
            Ejemplo: 34|5|50|Hoy hará calor, asegura el riego matutino temprano.
            """)
            
            let parts = response.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 4 {
                // Strip any existing units the AI may have included
                let rawTemp = parts[0].replacingOccurrences(of: "°", with: "").replacingOccurrences(of: "C", with: "").trimmingCharacters(in: .whitespaces)
                let rawRain = parts[1].replacingOccurrences(of: "mm", with: "").trimmingCharacters(in: .whitespaces)
                let rawHumidity = parts[2].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                let alertText = parts[3...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
                
                // Validate numbers exist
                guard let temp = Int(rawTemp), let rain = Int(rawRain), let humidity = Int(rawHumidity),
                      temp > 0, temp < 60, humidity > 0, humidity <= 100 else {
                    self.weather = defaultWeather(location: location)
                    return
                }
                
                // Validate alert is actual text, not just a number
                let finalAlert = (alertText.count > 5 && Int(alertText) == nil)
                    ? alertText
                    : "Clima estimado para hoy. Mantén el riego habitual."
                
                self.weather = MilpaWeather(
                    highTemp: "\(temp)°",
                    rainMM: "\(rain)mm",
                    humidity: "\(humidity)%",
                    alertMessage: finalAlert,
                    locationName: "\(location) (estimado)",
                    isOffline: true
                )
            } else {
                self.weather = defaultWeather(location: location)
            }
        } catch {
            self.weather = defaultWeather(location: location)
        }
    }
    
    private func defaultWeather(location: String) -> MilpaWeather {
        MilpaWeather(
            highTemp: "32°",
            rainMM: "5mm",
            humidity: "55%",
            alertMessage: "Mantén el riego habitual hoy.",
            locationName: "\(location) (estimado)",
            isOffline: true
        )
    }
    
    private func generateAlert(high: Double, precip: Double, humidity: Double, location: String) async -> String {
        do {
            var response = try await foundationModels.oneShot("""
            Datos del clima hoy en \(location): Máxima \(Int(high))°, \(precip)mm de lluvia, \(Int(humidity))% humedad.
            Escribe UNA SOLA ORACIÓN breve (máximo 15 palabras) con una sugerencia directa para un agricultor.
            Ejemplo: Aprovecha la lluvia para ahorrar agua de riego hoy.
            """)
            response = response.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            return response
        } catch {
            if high > 33 {
                return "Las altas temperaturas llegarán pronto, asegura un riego profundo."
            } else if precip > 10 {
                return "La lluvia aliviará los cultivos, pausa el riego manual."
            } else {
                return "Clima estable. Mantén tu rutina de monitoreo normal."
            }
        }
    }
}
