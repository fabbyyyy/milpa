import Vision
import UIKit

/// Uses Apple Vision framework to extract visual features from plant photos.
/// These observations are then passed to Foundation Models for contextual analysis.
struct VisionAnalyzer {

    struct ImageObservations {
        let labels: [String]           // e.g. ["leaf", "plant", "green"]
        let dominantColors: [String]   // e.g. ["green", "brown", "yellow"]
        let hasText: Bool
        
        var summary: String {
            var parts: [String] = []
            if !labels.isEmpty {
                parts.append("Objetos detectados: \(labels.prefix(8).joined(separator: ", "))")
            }
            if !dominantColors.isEmpty {
                parts.append("Colores dominantes: \(dominantColors.joined(separator: ", "))")
            }
            return parts.isEmpty ? "No se pudieron extraer detalles visuales." : parts.joined(separator: ". ")
        }
    }

    /// Analyze an image using Vision framework and return structured observations
    static func analyze(image: UIImage) async -> ImageObservations {
        guard let cgImage = image.cgImage else {
            return ImageObservations(labels: [], dominantColors: [], hasText: false)
        }

        // Run classification and saliency in parallel
        async let classificationResult = classifyImage(cgImage)
        async let colorResult = extractDominantColors(cgImage)

        let labels = await classificationResult
        let colors = await colorResult

        return ImageObservations(
            labels: labels,
            dominantColors: colors,
            hasText: false
        )
    }

    // MARK: - Classification

    private static func classifyImage(_ cgImage: CGImage) async -> [String] {
        // Use synchronous perform to avoid continuation double-resume issues
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            guard let results = request.results else { return [] }
            
            return results
                .filter { $0.confidence > 0.10 }
                .sorted { $0.confidence > $1.confidence }
                .prefix(10)
                .map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }
        } catch {
            // VNClassifyImageRequest fails on Simulator (no Neural Engine)
            // This is expected — color analysis still works
            print("⚠️ Vision classification not available: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Dominant Colors

    private static func extractDominantColors(_ cgImage: CGImage) async -> [String] {
        // Sample pixels from the image to determine dominant color categories
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let totalPixels = width * height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return [] }
        let buffer = data.bindMemory(to: UInt8.self, capacity: totalPixels * bytesPerPixel)

        var colorCounts: [String: Int] = [:]
        let sampleStep = max(1, totalPixels / 2000) // Sample ~2000 pixels

        for i in stride(from: 0, to: totalPixels, by: sampleStep) {
            let offset = i * bytesPerPixel
            let r = Int(buffer[offset])
            let g = Int(buffer[offset + 1])
            let b = Int(buffer[offset + 2])

            let colorName = categorizeColor(r: r, g: g, b: b)
            colorCounts[colorName, default: 0] += 1
        }

        // Return top colors sorted by frequency
        return colorCounts
            .sorted { $0.value > $1.value }
            .prefix(4)
            .map { $0.key }
    }

    private static func categorizeColor(r: Int, g: Int, b: Int) -> String {
        let brightness = (r + g + b) / 3

        if brightness < 40 { return "negro/oscuro" }
        if brightness > 220 && abs(r - g) < 20 && abs(g - b) < 20 { return "blanco/claro" }

        // Brown detection
        if r > 100 && g > 60 && g < r && b < g && (r - b) > 40 { return "café/marrón" }

        // Yellow detection
        if r > 180 && g > 160 && b < 100 { return "amarillo" }

        // Green detection
        if g > r && g > b && g > 80 { return "verde" }

        // Red detection
        if r > g + 40 && r > b + 40 && r > 100 { return "rojo" }

        // Orange
        if r > 180 && g > 80 && g < 160 && b < 80 { return "naranja" }

        // Purple
        if r > 80 && b > 80 && g < 80 { return "morado" }

        // Gray
        if abs(r - g) < 30 && abs(g - b) < 30 { return "gris" }

        return "otro"
    }
}
