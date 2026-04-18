//  CuidaView.swift
//  MilpaApp
//
//  Created by Alumno on 17/04/26.
//

import SwiftUI
import PhotosUI
import SwiftData

struct CuidaView: View {
    @StateObject private var viewModel = CuidaViewModel()
    @StateObject private var weatherManager = WeatherManager.shared
    @EnvironmentObject var speaker: Speaker
    @Query(sort: \Parcela.createdAt, order: .reverse) private var parcelas: [Parcela]
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var navigateToResult = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var diagnosticId = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                MilpaColor.cream.ignoresSafeArea()
                VStack {
                    LinearGradient(colors: [MilpaColor.green.opacity(0.55), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 300)
                        .ignoresSafeArea(edges: .top)
                    Spacer()
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Diagnóstico y alertas para tu campo")
                            .font(MilpaFont.sans(15))
                            .foregroundStyle(MilpaColor.ink2)
                            .padding(.bottom, 8)
                            
                        diagnosticoCard
                        climaCard
                        recordatoriosSection
                    }
                    .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 110)
                }
            }
            .navigationTitle("Cuida tu cultivo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                Task {
                    await viewModel.generateReminders(for: parcelas)
                }
                weatherManager.requestWeather()
            }
            .sheet(isPresented: $showCamera, onDismiss: {
                if capturedImage != nil {
                    diagnosticId = UUID()
                    navigateToResult = true
                }
            }) {
                CameraPicker { image in
                    capturedImage = image
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .navigationDestination(isPresented: $navigateToResult) {
                if let image = capturedImage {
                    DiagnosticResultView(image: image)
                        .id(diagnosticId)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        capturedImage = img
                        selectedPhoto = nil
                        diagnosticId = UUID()
                        navigateToResult = true
                    }
                }
            }
        }
    }

    private var diagnosticoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "camera.macro")
                        .foregroundStyle(MilpaColor.greenD)
                    Text("Diagnóstico Inteligente")
                        .font(MilpaFont.sans(14, weight: .semibold))
                        .foregroundStyle(MilpaColor.ink)
                }
                Spacer()
                ListenButton(
                    text: "Sube o toma una foto de cualquier planta para identificar plagas, deficiencias o detectar si está completamente sana.",
                    variant: .icon,
                    label: "Escuchar indicaciones de diagnóstico"
                )
            }
            .padding(20)
            
            VStack(spacing: 20) {
                Text("¿Tus cultivos lucen algo diferentes?")
                    .font(MilpaFont.serif(19, weight: .semibold))
                    .foregroundStyle(MilpaColor.ink)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                            Text("Galería")
                                .font(MilpaFont.sans(14, weight: .medium))
                        }
                        .foregroundStyle(MilpaColor.greenD)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(MilpaColor.greenBg, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .accessibilityLabel("Elegir foto de la galería")
                    
                    Button {
                        capturedImage = nil
                        showCamera = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                            Text("Cámara")
                                .font(MilpaFont.sans(14, weight: .medium))
                        }
                        .foregroundStyle(MilpaColor.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(MilpaColor.green, in: RoundedRectangle(cornerRadius: 18))
                        .shadow(color: MilpaColor.greenD.opacity(0.15), radius: 8, y: 4)
                    }
                    .accessibilityLabel("Tomar foto de la planta para analizarla")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(MilpaColor.ink.opacity(0.04), lineWidth: 1)
        )
    }

    private var climaCard: some View {
        Group {
            if weatherManager.isLoading && weatherManager.weather == nil {
                HStack(spacing: 12) {
                    ProgressView().tint(MilpaColor.greenD)
                    Text("Leyendo el clima de tu parcela...")
                        .font(MilpaFont.sans(14))
                        .foregroundStyle(MilpaColor.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 22))
            } else if let w = weatherManager.weather {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: w.isOffline ? "cloud.sun.fill" : "location.fill")
                                    .foregroundStyle(w.isOffline ? MilpaColor.ocreD : MilpaColor.greenD)
                                Text(w.locationName)
                                    .font(MilpaFont.sans(13, weight: .semibold))
                                    .foregroundStyle(MilpaColor.ink2)
                            }
                            Text(w.isOffline ? "Clima Estimado" : "Clima Actual")
                                .font(MilpaFont.serif(18, weight: .semibold))
                                .foregroundStyle(MilpaColor.ink)
                        }
                        Spacer()
                        ListenButton(text: w.audioSummary, variant: .icon, label: "Escuchar alerta")
                    }
                    .padding(20)
                    
                    // Stats Row
                    HStack(spacing: 12) {
                        WeatherStat(value: w.highTemp, label: "Temp. Máx", bg: MilpaColor.rustBg, fg: MilpaColor.rust)
                        WeatherStat(value: w.rainMM, label: "Precipitación", bg: MilpaColor.skyBg, fg: MilpaColor.sky)
                        WeatherStat(value: w.humidity, label: "Humedad", bg: MilpaColor.ocreBg, fg: MilpaColor.ocreD)
                    }
                    .padding(.horizontal, 20)
                    
                    // Alert Block
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(MilpaColor.green)
                        Text(w.alertMessage)
                            .font(MilpaFont.sans(14))
                            .foregroundStyle(MilpaColor.ink)
                            .lineSpacing(3)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MilpaColor.greenBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(20)
                }
                .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 26))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(MilpaColor.ink.opacity(0.04), lineWidth: 1)
                )
            }
        }
    }

    private var recordatoriosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Recordatorios")
            
            if viewModel.isLoadingReminders {
                HStack {
                    ProgressView().tint(MilpaColor.greenD)
                    Text("Milpa genera tus recordatorios...")
                        .font(MilpaFont.sans(13))
                        .foregroundStyle(MilpaColor.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
            } else if viewModel.reminders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(MilpaColor.ink3.opacity(0.4))
                    Text("Agrega parcelas para recibir recordatorios personalizados")
                        .font(MilpaFont.sans(13))
                        .foregroundStyle(MilpaColor.ink3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
            } else {
                ForEach(viewModel.reminders) { reminder in
                    TaskRow(
                        symbol: reminder.symbol,
                        tone: reminder.tone,
                        title: reminder.title,
                        sub: reminder.subtitle,
                        when: reminder.when,
                        whenTone: reminder.whenTone,
                        listen: "\(reminder.title). \(reminder.subtitle). \(reminder.when)."
                    )
                }
            }
        }
    }
}

// MARK: - Components

struct WeatherStat: View {
    let value: String, label: String, bg: Color, fg: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(MilpaFont.serif(22, weight: .semibold))
                .foregroundStyle(fg)
            Text(label).font(MilpaFont.sans(11))
                .foregroundStyle(MilpaColor.ink3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(bg, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct TaskRow: View {
    let symbol: String
    let tone: MilpaTone
    let title: String
    let sub: String
    let when: String
    let whenTone: MilpaTone
    let listen: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(tone.fg)
                .frame(width: 38, height: 38)
                .background(tone.bg, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(MilpaFont.sans(14, weight: .semibold))
                    .foregroundStyle(MilpaColor.ink)
                Text(sub).font(MilpaFont.sans(12))
                    .foregroundStyle(MilpaColor.ink2)
            }
            Spacer()
            Chip(text: when, bg: whenTone.bg, fg: whenTone.fg)
            ListenButton(text: listen, variant: .icon, label: "Escuchar \(title)")
        }
        .padding(14)
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Picker Cámara
struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var onImagePicked: (UIImage) -> Void
        init(onImagePicked: @escaping (UIImage) -> Void) { self.onImagePicked = onImagePicked }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage { onImagePicked(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}
#Preview {
    CuidaView()
}
