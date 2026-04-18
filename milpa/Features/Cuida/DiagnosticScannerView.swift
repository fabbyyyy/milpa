import SwiftUI
import SwiftData

struct DiagnosticResultView: View {
    let image: UIImage
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var speaker: Speaker

    @State private var isProcessing = true
    @State private var processingStep = "Analizando imagen con Vision..."
    @State private var analysisResult: PlantAnalysisResult? = nil
    @State private var visionObservations: VisionAnalyzer.ImageObservations? = nil
    @State private var isAddingParcela = false
    @State private var showSuccess = false
    @State private var hasSpoken = false

    private let foundationModels = FoundationModelManager.shared

    var body: some View {
        ZStack {
            MilpaColor.cream.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    Color.clear
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
                        .padding(.horizontal, 16)
                    
                    if isProcessing {
                        VStack(spacing: 12) {
                            ProgressView().tint(MilpaColor.greenD)
                            Text(processingStep)
                                .font(MilpaFont.sans(14))
                                .foregroundStyle(MilpaColor.ink2)
                                .animation(.easeInOut, value: processingStep)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 16)
                    } else {
                        // AI analysis result only (Vision runs in background, not shown to user)
                        if let result = analysisResult {
                            analysisCard(result)
                                .padding(.horizontal, 16)
                            parcelaCard
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Diagnóstico")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await analyzeImage()
        }
    }
    
    // MARK: - Vision Observations Card
    
    private func visionCard(_ obs: VisionAnalyzer.ImageObservations) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .foregroundStyle(MilpaColor.sky)
                Text("Detección Visual")
                    .font(MilpaFont.sans(14, weight: .semibold))
                    .foregroundStyle(MilpaColor.ink)
            }
            
            if !obs.dominantColors.isEmpty {
                HStack(spacing: 6) {
                    Text("Colores:")
                        .font(MilpaFont.sans(12, weight: .medium))
                        .foregroundStyle(MilpaColor.ink2)
                    ForEach(obs.dominantColors.prefix(4), id: \.self) { color in
                        Text(color)
                            .font(MilpaFont.sans(11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MilpaColor.greenBg, in: Capsule())
                            .foregroundStyle(MilpaColor.greenD)
                    }
                }
            }
            
            if !obs.labels.isEmpty {
                Text("Objetos: \(obs.labels.prefix(5).joined(separator: ", "))")
                    .font(MilpaFont.sans(12))
                    .foregroundStyle(MilpaColor.ink3)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MilpaColor.skyBg.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
    }
    
    // MARK: - Analysis Result Card
    
    private func analysisCard(_ result: PlantAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Evaluación de Milpa")
                    .font(MilpaFont.serif(18, weight: .semibold))
                    .foregroundStyle(MilpaColor.greenD)
                Spacer()
                ListenButton(
                    text: "\(result.disease). \(result.recommendation)",
                    label: "Escuchar diagnóstico"
                )
            }
            
            Text(result.disease)
                .font(MilpaFont.sans(16, weight: .bold))
                .foregroundStyle(MilpaColor.ink)
                
            Text("Fiabilidad: \(Int(result.confidence * 100))%")
                .font(MilpaFont.sans(12))
                .foregroundStyle(MilpaColor.ink2)
                
            MarkdownText(result.recommendation, font: MilpaFont.sans(14), foregroundColor: MilpaColor.ink)
        }
        .padding(20)
        .background(MilpaColor.greenBg, in: RoundedRectangle(cornerRadius: 22))
        .onAppear {
            if !hasSpoken {
                hasSpoken = true
                speaker.speak(
                    "\(result.disease). \(result.recommendation)",
                    id: "diagnostic_\(result.disease)"
                )
            }
        }
    }
    
    // MARK: - Parcela Card
    
    private var parcelaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Quieres monitorear esta planta?")
                .font(MilpaFont.sans(14, weight: .medium))
                .foregroundStyle(MilpaColor.ink2)
            
            Button {
                Task { await createParcela() }
            } label: {
                HStack {
                    if isAddingParcela {
                        ProgressView().tint(.white)
                    } else if showSuccess {
                        Image(systemName: "checkmark")
                        Text("Parcela Agregada")
                    } else {
                        Image(systemName: "plus.circle.fill")
                        Text("Agregar a mis parcelas")
                    }
                }
                .font(MilpaFont.sans(16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    showSuccess ? MilpaColor.greenD : MilpaColor.green,
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .disabled(isAddingParcela || showSuccess)
        }
        .padding(20)
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 22))
    }
    
    // MARK: - Logic
    
    private func analyzeImage() async {
        isProcessing = true
        analysisResult = nil
        visionObservations = nil
        
        // Step 1: Vision analysis (actual image processing)
        processingStep = "Analizando imagen con Vision..."
        let observations = await VisionAnalyzer.analyze(image: image)
        visionObservations = observations
        
        // Step 2: Foundation Models interpretation
        processingStep = "Milpa está interpretando los resultados..."
        do {
            let result = try await foundationModels.analyzePlantHealth(visionObservations: observations)
            self.analysisResult = result
        } catch {
            print("Error analizando: \(error)")
            self.analysisResult = PlantAnalysisResult(
                disease: "Revisión general",
                confidence: 0.70,
                recommendation: "No se pudo completar el análisis. Revisa que las hojas no tengan manchas, amarillamiento o marchitamiento. Si ves algo inusual, consulta con Milpa en la sección Decide."
            )
        }
        
        isProcessing = false
    }
    
    private func createParcela() async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isAddingParcela = true
        
        let newParcela = Parcela(
            name: "Nueva Parcela",
            crop: "Cultivo",
            stage: "Detección",
            hectares: 1.0,
            photoData: data
        )
        modelContext.insert(newParcela)
        try? modelContext.save()
        
        withAnimation {
            showSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
        
        isAddingParcela = false
    }
}
