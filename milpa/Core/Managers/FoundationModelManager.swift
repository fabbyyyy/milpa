import Foundation
import FoundationModels
import SwiftData
import Combine

@MainActor
final class FoundationModelManager: ObservableObject {
    static let shared = FoundationModelManager()

    nonisolated let objectWillChange = ObservableObjectPublisher()

    @Published var isAvailable: Bool = false

    private var session: LanguageModelSession?

    private let systemInstructions = """
    Eres Milpa, un asistente agrícola experto para agricultores mexicanos.
    Respondes en español, de forma clara, práctica y concisa.
    Das recomendaciones específicas sobre siembra, riego, plagas y mercados.
    Máximo 3 oraciones por respuesta.
    Nunca uses formato markdown como **, ##, - o bullets. Escribe en texto plano natural.
    """

    init() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            isAvailable = true
            session = LanguageModelSession(instructions: systemInstructions)
        case .unavailable(let reason):
            isAvailable = false
            print("⚠️ Foundation Models no disponible: \(reason)")
        }
    }

    /// Single-turn response (legacy, kept for compatibility)
    func analyzeVoiceCommand(text: String) async throws -> String {
        guard let session else {
            return "Apple Intelligence no está disponible. Actívalo en Configuración → Apple Intelligence."
        }
        let response = try await session.respond(to: text)
        return response.content
    }

    /// Chat-style response using the persistent session
    func sendChatMessage(_ text: String) async throws -> String {
        guard let session else {
            return "Apple Intelligence no está disponible. Actívalo en Configuración → Apple Intelligence."
        }
        let response = try await session.respond(to: text)
        return response.content
    }

    /// One-shot query using a fresh session (no accumulated context)
    func oneShot(_ prompt: String) async throws -> String {
        guard isAvailable else {
            return "Apple Intelligence no está disponible."
        }
        let freshSession = LanguageModelSession(instructions: systemInstructions)
        let response = try await freshSession.respond(to: prompt)
        return response.content
    }

    /// Reset the session to start a new conversation
    func resetSession() {
        guard isAvailable else { return }
        session = LanguageModelSession(instructions: systemInstructions)
    }

    /// Analyze a plant's health using Vision framework observations.
    /// Vision extracts real visual features from the photo, then Foundation Models
    /// interprets those observations to give contextual plant health advice.
    func analyzePlantHealth(visionObservations: VisionAnalyzer.ImageObservations) async throws -> PlantAnalysisResult {
        guard isAvailable else {
            return PlantAnalysisResult(
                disease: "No disponible",
                confidence: 0,
                recommendation: "Activa Apple Intelligence en Configuración para usar esta función."
            )
        }
        
        // Pre-analyze colors to guide the AI prompt
        let warningColors = Set(["café/marrón", "amarillo", "gris", "rojo", "negro/oscuro"])
        let dominantColors = visionObservations.dominantColors
        let topThree = Set(dominantColors.prefix(3))
        let warningCount = topThree.intersection(warningColors).count
        let greenIsTop = dominantColors.first == "verde"
        
        // Color-based health verdict BEFORE asking the AI
        let colorsLookBad = warningCount >= 2 || (!greenIsTop && warningCount >= 1)
        
        let toneGuidance = colorsLookBad
            ? "IMPORTANTE: Los colores detectados (gris, café, marrón) son señales claras de deterioro, sequía o enfermedad. NO digas que la planta está sana. Describe los problemas que estos colores indican."
            : "Si los colores son mayormente verdes y no hay señales de alerta, puedes indicar que la planta parece estar en buen estado."
        
        let freshSession = LanguageModelSession(instructions: """
        Eres un ingeniero agrónomo experto y crítico en salud de plantas en México.
        Respondes en español, de forma clara y práctica.
        Nunca uses formato markdown. Escribe en texto plano natural.
        Eres estricto: si hay cualquier señal de problema, la reportas.
        """)
        
        let response = try await freshSession.respond(
            to: """
            Un agricultor acaba de tomar una foto de una planta. El sistema de visión por computadora detectó lo siguiente:
            \(visionObservations.summary)
            
            \(toneGuidance)
            
            Basándote en estas observaciones visuales:
            1. Si hay colores café, marrón, gris o negro dominantes, indica deterioro, sequía o posible enfermedad.
            2. Solo indica que está sana si el verde es el color claramente dominante sin presencia significativa de café o gris.
            3. Da una recomendación específica de acción.
            Sé breve: máximo 3 oraciones.
            """
        )
        
        let content = response.content
        
        // Hard override based on actual pixel colors — AI opinion is secondary
        let isHealthy: Bool
        let lowerContent = content.lowercased()
        let aiSaysHealthy = lowerContent.contains("sana") || lowerContent.contains("saludable") || lowerContent.contains("buen estado") || lowerContent.contains("buena salud")
        
        if colorsLookBad {
            // Colors clearly indicate a problem — NEVER mark as healthy
            isHealthy = false
        } else if greenIsTop {
            // Green is dominant — trust the AI's assessment
            // (minor yellows from flowers, small brown from soil are normal)
            isHealthy = aiSaysHealthy
        } else {
            // Green is not dominant but no strong warnings — lean towards AI
            isHealthy = aiSaysHealthy
        }
        
        let observationCount = visionObservations.labels.count
        let baseConfidence: Double = observationCount > 3 ? 0.85 : 0.70
        
        return PlantAnalysisResult(
            disease: isHealthy ? "Planta sana ✅" : "Revisión recomendada ⚠️",
            confidence: isHealthy ? min(baseConfidence + 0.05, 0.95) : baseConfidence,
            recommendation: content
        )
    }

    /// Detect the crop type — uses context from the user's existing parcelas
    func suggestCropType(existingCrops: [String]) async throws -> String {
        guard isAvailable else { return "Maíz" }
        
        let freshSession = LanguageModelSession(instructions: systemInstructions)
        let context = existingCrops.isEmpty ? "maíz" : existingCrops.joined(separator: ", ")
        let response = try await freshSession.respond(
            to: "El agricultor cultiva: \(context). Acaba de tomar una foto de una planta nueva. ¿Qué cultivo podría ser? Responde con una sola palabra."
        )
        return response.content
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? "Maíz"
    }
}

struct PlantAnalysisResult {
    let disease: String
    let confidence: Double
    let recommendation: String
}
