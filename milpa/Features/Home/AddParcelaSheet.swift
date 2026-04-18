//
//  AddParcelaSheet.swift
//  MilpaApp
//
//  Created by Alumno on 18/04/26.
//

import SwiftUI
import PhotosUI
import SwiftData

struct AddParcelaSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var crop = ""
    @State private var hectares = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoImage: UIImage?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    private let crops = ["Maíz", "Frijol", "Calabaza", "Chile", "Jitomate", "Nopal", "Aguacate", "Otro"]
    @State private var selectedCrop = ""
    @State private var customCrop = ""
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !effectiveCrop.isEmpty
    }
    
    private var effectiveCrop: String {
        if selectedCrop == "Otro" {
            return customCrop.trimmingCharacters(in: .whitespaces)
        }
        return selectedCrop
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MilpaColor.cream.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Photo Section
                        photoSection
                        
                        // Form Fields
                        formFields
                    }
                    .padding(22)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Nueva Parcela")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(MilpaColor.ink2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveParcela() }
                        .font(MilpaFont.sans(16, weight: .semibold))
                        .foregroundStyle(isValid ? MilpaColor.green : MilpaColor.ink3)
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $cameraImage)
                    .ignoresSafeArea()
            }
            .onChange(of: cameraImage) { _, newImage in
                if let newImage {
                    photoImage = newImage
                    photoData = newImage.jpegData(compressionQuality: 0.7)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                        photoImage = UIImage(data: data)
                    }
                }
            }
        }
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(spacing: 12) {
            if let photoImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: photoImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    Button {
                        self.photoImage = nil
                        self.photoData = nil
                        self.selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .padding(10)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(MilpaColor.greenD.opacity(0.5))
                    
                    Text("Agrega una foto de tu parcela")
                        .font(MilpaFont.sans(14))
                        .foregroundStyle(MilpaColor.ink3)
                    
                    HStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13))
                                Text("Cámara")
                                    .font(MilpaFont.sans(13, weight: .medium))
                            }
                            .foregroundStyle(MilpaColor.cream)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(MilpaColor.green, in: Capsule())
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 13))
                                Text("Galería")
                                    .font(MilpaFont.sans(13, weight: .medium))
                            }
                            .foregroundStyle(MilpaColor.greenD)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(MilpaColor.greenBg, in: Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(MilpaColor.greenD.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                )
            }
        }
    }
    
    // MARK: - Form Fields
    
    private var formFields: some View {
        VStack(spacing: 16) {
            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("NOMBRE DE LA PARCELA")
                    .font(MilpaFont.sans(11, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(MilpaColor.ink3)
                
                TextField("Ej: Parcela Norte", text: $name)
                    .font(MilpaFont.sans(16))
                    .padding(14)
                    .background(MilpaColor.cream2.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MilpaColor.ink.opacity(0.08)))
            }
            
            // Crop picker
            VStack(alignment: .leading, spacing: 6) {
                Text("¿QUÉ VAS A SEMBRAR?")
                    .font(MilpaFont.sans(11, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(MilpaColor.ink3)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(crops, id: \.self) { c in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCrop = c
                                }
                            } label: {
                                Text(c)
                                    .font(MilpaFont.sans(13, weight: selectedCrop == c ? .semibold : .regular))
                                    .foregroundStyle(selectedCrop == c ? MilpaColor.cream : MilpaColor.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(
                                        selectedCrop == c ? MilpaColor.green : MilpaColor.cream2.opacity(0.5),
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule().strokeBorder(
                                            selectedCrop == c ? Color.clear : MilpaColor.ink.opacity(0.08)
                                        )
                                    )
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
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            // Hectares
            VStack(alignment: .leading, spacing: 6) {
                Text("HECTÁREAS (OPCIONAL)")
                    .font(MilpaFont.sans(11, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(MilpaColor.ink3)
                
                TextField("Ej: 2.5", text: $hectares)
                    .font(MilpaFont.sans(16))
                    .keyboardType(.decimalPad)
                    .padding(14)
                    .background(MilpaColor.cream2.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MilpaColor.ink.opacity(0.08)))
            }
        }
        .padding(18)
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 22))
    }
    
    // MARK: - Save
    
    private func saveParcela() {
        let ha = Double(hectares) ?? 1.0
        let parcela = Parcela(
            name: name.trimmingCharacters(in: .whitespaces),
            crop: effectiveCrop,
            stage: "Siembra",
            hectares: ha,
            createdAt: Date(),
            photoData: photoData
        )
        modelContext.insert(parcela)
        try? modelContext.save()
        dismiss()
    }
}
