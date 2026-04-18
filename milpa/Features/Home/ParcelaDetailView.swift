//
//  ParcelaDetailView.swift
//  MilpaApp
//
//  Created by Alumno on 18/04/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ParcelaDetailView: View {
    @Bindable var parcela: Parcela
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var speaker: Speaker
    
    @State private var showDeleteAlert = false
    @State private var showCamera = false
    @State private var showEditSheet = false
    @State private var cameraImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    
    private var cropEmoji: String {
        switch parcela.crop.lowercased() {
        case let c where c.contains("maíz") || c.contains("maiz"): return "🌽"
        case let c where c.contains("frijol"): return "🫘"
        case let c where c.contains("calabaza"): return "🎃"
        case let c where c.contains("chile"): return "🌶️"
        case let c where c.contains("jitomate") || c.contains("tomate"): return "🍅"
        case let c where c.contains("nopal"): return "🌵"
        case let c where c.contains("aguacate"): return "🥑"
        default: return "🌱"
        }
    }
    
    private var stageColor: Color {
        switch parcela.stage.lowercased() {
        case "siembra": return MilpaColor.ocre
        case "crecimiento": return MilpaColor.green
        case "floración": return MilpaColor.corn
        case "cosecha": return MilpaColor.rust
        default: return MilpaColor.greenD
        }
    }
    
    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateStyle = .long
        return fmt.string(from: parcela.createdAt)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            MilpaColor.cream.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero photo section
                    heroSection
                    
                    // Content
                    VStack(spacing: 18) {
                        // Stats row
                        statsRow
                        
                        // Info cards
                        detailCards
                        
                        // Photo section
                        photoManagement
                        
                        // Delete button
                        deleteSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(parcela.name)
                    .font(MilpaFont.sans(16, weight: .semibold))
                    .foregroundStyle(hasPhoto ? .white : MilpaColor.ink)
            }
        }
        .alert("¿Eliminar parcela?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                deleteParcela()
            }
        } message: {
            Text("Se eliminará \"\(parcela.name)\" permanentemente. Esta acción no se puede deshacer.")
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(image: $cameraImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showEditSheet) {
            EditParcelaSheet(parcela: parcela)
        }
        .onChange(of: cameraImage) { _, newImage in
            if let newImage {
                parcela.photoData = newImage.jpegData(compressionQuality: 0.7)
                try? modelContext.save()
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    parcela.photoData = data
                    try? modelContext.save()
                }
            }
        }
    }
    
    private var hasPhoto: Bool {
        parcela.photoData != nil
    }
    
    private var heroSection: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 300)
            .background {
                if let data = parcela.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [MilpaColor.green.opacity(0.6), MilpaColor.greenD],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipped()
            .overlay {
                if hasPhoto {
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                } else {
                    Text(cropEmoji)
                        .font(.system(size: 80))
                        .opacity(0.2)
                }
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(cropEmoji + " " + parcela.crop)
                            .font(MilpaFont.sans(13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                        
                        Text(parcela.name)
                            .font(MilpaFont.serif(28, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 8) {
                            Chip(text: parcela.stage, bg: stageColor.opacity(0.3), fg: .white)
                            Chip(text: "Día \(parcela.daysSinceCreation)", bg: Color.white.opacity(0.2), fg: .white)
                        }
                    }
                    Spacer()
                    ListenButton(
                        text: "Parcela de \(parcela.crop), \(parcela.name). Etapa de \(parcela.stage), al día \(parcela.daysSinceCreation).",
                        variant: .onDark,
                        label: "Escuchar información de parcela"
                    )
                }
                .padding(22)
                .padding(.bottom, 4)
            }
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(parcela.daysSinceCreation)", label: "Días", icon: "calendar")
            
            Divider().frame(height: 36)
            
            statItem(value: String(format: "%.1f", parcela.hectares), label: "Hectáreas", icon: "map")
            
            Divider().frame(height: 36)
            
            statItem(value: parcela.stage, label: "Etapa", icon: "leaf.fill")
        }
        .padding(.vertical, 16)
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MilpaColor.ink.opacity(0.06)))
    }
    
    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(MilpaColor.greenD)
            Text(value)
                .font(MilpaFont.serif(18, weight: .semibold))
                .foregroundStyle(MilpaColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(MilpaFont.sans(11))
                .foregroundStyle(MilpaColor.ink3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Detail Cards
    
    private var detailCards: some View {
        VStack(spacing: 12) {
            // Cultivo info card
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MilpaColor.greenD)
                    Text("INFORMACIÓN")
                        .font(MilpaFont.sans(11, weight: .semibold))
                        .kerning(0.5)
                        .foregroundStyle(MilpaColor.ink3)
                    Spacer()
                    
                    Button {
                        showEditSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .medium))
                            Text("Editar")
                                .font(MilpaFont.sans(12, weight: .medium))
                        }
                        .foregroundStyle(MilpaColor.greenD)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(MilpaColor.greenBg, in: Capsule())
                    }
                }
                
                detailRow(icon: "leaf.fill", label: "Cultivo", value: "\(cropEmoji) \(parcela.crop)")
                Divider().background(MilpaColor.ink.opacity(0.06))
                detailRow(icon: "arrow.up.forward", label: "Etapa", value: parcela.stage)
                Divider().background(MilpaColor.ink.opacity(0.06))
                detailRow(icon: "map", label: "Hectáreas", value: String(format: "%.1f ha", parcela.hectares))
                Divider().background(MilpaColor.ink.opacity(0.06))
                detailRow(icon: "calendar", label: "Fecha de siembra", value: formattedDate)
                Divider().background(MilpaColor.ink.opacity(0.06))
                detailRow(icon: "clock", label: "Edad del cultivo", value: "\(parcela.daysSinceCreation) días")
            }
            .padding(18)
            .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MilpaColor.ink.opacity(0.06)))
        }
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(MilpaColor.greenD)
                .frame(width: 24)
            
            Text(label)
                .font(MilpaFont.sans(14))
                .foregroundStyle(MilpaColor.ink3)
            
            Spacer()
            
            Text(value)
                .font(MilpaFont.sans(14, weight: .medium))
                .foregroundStyle(MilpaColor.ink)
        }
    }
    
    // MARK: - Photo Management
    
    private var photoManagement: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(MilpaColor.greenD)
                Text("FOTO DE LA PARCELA")
                    .font(MilpaFont.sans(11, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(MilpaColor.ink3)
            }
            
            HStack(spacing: 10) {
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill").font(.system(size: 13))
                        Text(hasPhoto ? "Cambiar foto" : "Tomar foto")
                            .font(MilpaFont.sans(13, weight: .medium))
                    }
                    .foregroundStyle(MilpaColor.cream)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(MilpaColor.green, in: Capsule())
                }
                
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 13))
                        Text("Galería")
                            .font(MilpaFont.sans(13, weight: .medium))
                    }
                    .foregroundStyle(MilpaColor.greenD)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(MilpaColor.greenBg, in: Capsule())
                }
                
                if hasPhoto {
                    Button {
                        withAnimation {
                            parcela.photoData = nil
                            try? modelContext.save()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(MilpaColor.rust)
                            .padding(10)
                            .background(MilpaColor.rustBg, in: Circle())
                    }
                }
            }
        }
        .padding(18)
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MilpaColor.ink.opacity(0.06)))
    }
    
    // MARK: - Delete
    
    private var deleteSection: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                Text("Eliminar parcela")
                    .font(MilpaFont.sans(14, weight: .medium))
            }
            .foregroundStyle(MilpaColor.rust)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(MilpaColor.rustBg.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MilpaColor.rust.opacity(0.15)))
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func deleteParcela() {
        modelContext.delete(parcela)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Sheet

struct EditParcelaSheet: View {
    @Bindable var parcela: Parcela
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var selectedCrop: String = ""
    @State private var customCrop: String = ""
    @State private var hectares: String = ""
    @State private var stage: String = ""
    
    private let crops = ["Maíz", "Frijol", "Calabaza", "Chile", "Jitomate", "Nopal", "Aguacate", "Otro"]
    private let stages = ["Siembra", "Crecimiento", "Floración", "Cosecha"]
    
    private var effectiveCrop: String {
        selectedCrop == "Otro" ? customCrop.trimmingCharacters(in: .whitespaces) : selectedCrop
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !effectiveCrop.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MilpaColor.cream.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Name
                        fieldSection(title: "NOMBRE") {
                            TextField("Nombre de la parcela", text: $name)
                                .font(MilpaFont.sans(16))
                                .padding(14)
                                .background(MilpaColor.cream2.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MilpaColor.ink.opacity(0.08)))
                        }
                        
                        // Crop
                        fieldSection(title: "CULTIVO") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(crops, id: \.self) { c in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) { selectedCrop = c }
                                        } label: {
                                            Text(c)
                                                .font(MilpaFont.sans(13, weight: selectedCrop == c ? .semibold : .regular))
                                                .foregroundStyle(selectedCrop == c ? MilpaColor.cream : MilpaColor.ink)
                                                .padding(.horizontal, 14).padding(.vertical, 9)
                                                .background(selectedCrop == c ? MilpaColor.green : MilpaColor.cream2.opacity(0.5), in: Capsule())
                                                .overlay(Capsule().strokeBorder(selectedCrop == c ? Color.clear : MilpaColor.ink.opacity(0.08)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            if selectedCrop == "Otro" {
                                TextField("¿Qué cultivo?", text: $customCrop)
                                    .font(MilpaFont.sans(16))
                                    .padding(14)
                                    .background(MilpaColor.cream2.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MilpaColor.ink.opacity(0.08)))
                            }
                        }
                        
                        // Stage
                        fieldSection(title: "ETAPA") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(stages, id: \.self) { s in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) { stage = s }
                                        } label: {
                                            Text(s)
                                                .font(MilpaFont.sans(12, weight: stage == s ? .semibold : .regular))
                                                .foregroundStyle(stage == s ? MilpaColor.cream : MilpaColor.ink)
                                                .padding(.horizontal, 12).padding(.vertical, 8)
                                                .background(stage == s ? MilpaColor.green : MilpaColor.cream2.opacity(0.5), in: Capsule())
                                                .overlay(Capsule().strokeBorder(stage == s ? Color.clear : MilpaColor.ink.opacity(0.08)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // Hectares
                        fieldSection(title: "HECTÁREAS") {
                            TextField("Ej: 2.5", text: $hectares)
                                .font(MilpaFont.sans(16))
                                .keyboardType(.decimalPad)
                                .padding(14)
                                .background(MilpaColor.cream2.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MilpaColor.ink.opacity(0.08)))
                        }
                    }
                    .padding(22)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Editar Parcela")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(MilpaColor.ink2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveChanges() }
                        .font(MilpaFont.sans(16, weight: .semibold))
                        .foregroundStyle(isValid ? MilpaColor.green : MilpaColor.ink3)
                        .disabled(!isValid)
                }
            }
            .onAppear {
                name = parcela.name
                hectares = String(format: "%.1f", parcela.hectares)
                stage = parcela.stage
                
                // Find matching crop or set to Otro
                if crops.contains(where: { $0.lowercased() == parcela.crop.lowercased() }) {
                    selectedCrop = crops.first(where: { $0.lowercased() == parcela.crop.lowercased() }) ?? ""
                } else {
                    selectedCrop = "Otro"
                    customCrop = parcela.crop
                }
            }
        }
    }
    
    @ViewBuilder
    private func fieldSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MilpaFont.sans(11, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(MilpaColor.ink3)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 18))
    }
    
    private func saveChanges() {
        parcela.name = name.trimmingCharacters(in: .whitespaces)
        parcela.crop = effectiveCrop
        parcela.stage = stage
        parcela.hectares = Double(hectares) ?? parcela.hectares
        try? modelContext.save()
        dismiss()
    }
}
