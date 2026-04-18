import Foundation
import Combine
import SwiftUI

@MainActor
final class VendeViewModel: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    @Published var selectedCrop: String = "FRIJOL NEGRO"
    @Published var currentPrice: Double = 25.40
    @Published var priceTrend: Double = 8.1 // percent increase
    
    // Historical prices simulation
    @Published var priceHistory: [MarketDataPoint] = [
        MarketDataPoint(day: 1, price: 18),
        MarketDataPoint(day: 2, price: 19),
        MarketDataPoint(day: 3, price: 19),
        MarketDataPoint(day: 4, price: 20),
        MarketDataPoint(day: 5, price: 21),
        MarketDataPoint(day: 6, price: 20),
        MarketDataPoint(day: 7, price: 22),
        MarketDataPoint(day: 8, price: 23),
        MarketDataPoint(day: 9, price: 22),
        MarketDataPoint(day: 10, price: 24),
        MarketDataPoint(day: 11, price: 24),
        MarketDataPoint(day: 12, price: 25.40)
    ]
    
    let recommendationAudio = "Vende el viernes en el mercado de Oaxaca. El pronóstico sube a 26 pesos con 80 centavos por kilo. Vas a ganar 420 pesos más que si vendes hoy."
    
    // Extracted markets
    let markets: [MarketInfo] = [
        MarketInfo(name: "Central de Oaxaca", km: "42 km", price: "$26.80", trend: .up, isBest: true),
        MarketInfo(name: "Tianguis Etla", km: "18 km", price: "$25.40", trend: .flat, isBest: false),
        MarketInfo(name: "Acopio CONASUPO", km: "8 km", price: "$22.10", trend: .down, isBest: false)
    ]
}

struct MarketDataPoint: Identifiable {
    let id = UUID()
    let day: Int
    let price: Double
}

struct MarketInfo: Identifiable {
    let id = UUID()
    let name: String
    let km: String
    let price: String
    let trend: MarketRowTrend
    let isBest: Bool
}

enum MarketRowTrend {
    case up, flat, down
}
