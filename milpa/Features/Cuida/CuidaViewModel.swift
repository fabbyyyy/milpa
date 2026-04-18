import Foundation
import SwiftUI
import PhotosUI
import Combine
import SwiftData

struct CuidaReminder: Identifiable {
    let id = UUID()
    let symbol: String
    let tone: MilpaTone
    let title: String
    let subtitle: String
    let when: String
    let whenTone: MilpaTone
}

@MainActor
final class CuidaViewModel: ObservableObject {
    @Published var reminders: [CuidaReminder] = []
    @Published var isLoadingReminders: Bool = false

    private let foundationModels = FoundationModelManager.shared
    
    // Cache: avoid regenerating every time the view appears
    private var lastParcelaHash: String = ""
    private var lastGeneratedAt: Date?
    private let cacheMinutes: TimeInterval = 120 // 2 hours

    func generateReminders(for parcelas: [Parcela], force: Bool = false) async {
        guard !parcelas.isEmpty else {
            reminders = []
            return
        }
        
        // Build a hash based on parcela names + days to detect real changes
        let currentHash = parcelas.prefix(5).map { "\($0.name)\($0.daysSinceCreation)" }.joined()
        
        // Skip if parcelas haven't changed and cache is fresh
        if !force,
           currentHash == lastParcelaHash,
           !reminders.isEmpty,
           let lastTime = lastGeneratedAt,
           Date().timeIntervalSince(lastTime) < cacheMinutes {
            return
        }
        
        isLoadingReminders = true
        
        let parcelaDescriptions = parcelas.prefix(5).map { p in
            "\(p.crop) (\(p.name)), \(p.daysSinceCreation) días de edad, etapa: \(p.stage)"
        }.joined(separator: "; ")
        
        let prompt = """
        Basándote en estos cultivos: \(parcelaDescriptions).
        Dame exactamente 3 recordatorios urgentes para hoy/mañana/esta semana.
        Formato por línea: CATEGORÍA|TÍTULO|DETALLE|CUÁNDO
        Donde CATEGORÍA es una sola palabra de estas opciones: riego, plaga, sol, siembra, poda, fertilizar, revisar
        Y CUÁNDO es: Hoy, Mañana, o un día de la semana.
        Solo las 3 líneas, nada más. Sin explicaciones, sin markdown, sin numeración.
        """
        
        do {
            let response = try await foundationModels.oneShot(prompt)
            let lines = response.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            var parsed: [CuidaReminder] = []
            for (index, line) in lines.prefix(3).enumerated() {
                let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 4 else { continue }
                
                let category = parts[0].lowercased()
                let title = parts[1]
                let detail = parts[2]
                let when = parts[3]
                
                let (icon, tone) = iconAndTone(for: category, index: index)
                let whenTones: [MilpaTone] = [.green, .ocre, .rust]
                
                parsed.append(CuidaReminder(
                    symbol: icon,
                    tone: tone,
                    title: title,
                    subtitle: detail,
                    when: when,
                    whenTone: whenTones[index % whenTones.count]
                ))
            }
            
            if parsed.isEmpty {
                parsed = defaultReminders(for: parcelas)
            }
            
            reminders = parsed
            lastParcelaHash = currentHash
            lastGeneratedAt = Date()
        } catch {
            print("Error generating reminders: \(error)")
            // Only fall back to defaults if we have nothing cached
            if reminders.isEmpty {
                reminders = defaultReminders(for: parcelas)
            }
        }
        
        isLoadingReminders = false
    }
    
    private func iconAndTone(for category: String, index: Int) -> (String, MilpaTone) {
        let keyword = category.trimmingCharacters(in: .punctuationCharacters)
        
        if keyword.contains("riego") || keyword.contains("agua") || keyword.contains("humedad") {
            return ("drop.fill", .sky)
        } else if keyword.contains("plaga") || keyword.contains("insecto") {
            return ("ant.fill", .rust)
        } else if keyword.contains("sol") || keyword.contains("calor") || keyword.contains("clima") {
            return ("sun.max.fill", .ocre)
        } else if keyword.contains("siembra") || keyword.contains("sembrar") || keyword.contains("planta") {
            return ("leaf.fill", .green)
        } else if keyword.contains("poda") || keyword.contains("cortar") || keyword.contains("corte") {
            return ("scissors", .ocre)
        } else if keyword.contains("fertiliz") || keyword.contains("abono") || keyword.contains("nutrient") {
            return ("sparkles", .green)
        } else if keyword.contains("revis") || keyword.contains("inspeccio") || keyword.contains("observ") {
            return ("eye.fill", .sky)
        } else {
            let fallbacks: [(String, MilpaTone)] = [
                ("leaf.fill", .green),
                ("drop.fill", .sky),
                ("sun.max.fill", .ocre)
            ]
            return fallbacks[index % fallbacks.count]
        }
    }
    
    private func defaultReminders(for parcelas: [Parcela]) -> [CuidaReminder] {
        guard let first = parcelas.first else { return [] }
        return [
            CuidaReminder(symbol: "drop.fill", tone: .sky, title: "Revisar riego", subtitle: "\(first.crop) — \(first.name)", when: "Hoy", whenTone: .green),
            CuidaReminder(symbol: "leaf.fill", tone: .green, title: "Inspeccionar hojas", subtitle: "Buscar manchas o plagas", when: "Mañana", whenTone: .ocre),
            CuidaReminder(symbol: "sun.max.fill", tone: .ocre, title: "Proteger del sol", subtitle: "Temperaturas altas esta semana", when: "Viernes", whenTone: .rust),
        ]
    }
}
