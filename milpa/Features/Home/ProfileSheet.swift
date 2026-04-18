import SwiftUI

struct ProfileSheet: View {
    @AppStorage("userName") private var userName: String = "Agricultor"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                MilpaColor.cream.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .center, spacing: 16) {
                        Circle()
                            .fill(MilpaColor.ocreBg)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(initials(for: userName))
                                    .font(MilpaFont.serif(32, weight: .semibold))
                                    .foregroundStyle(MilpaColor.ocreD)
                            )
                        
                        Text("Configuración de Perfil")
                            .font(MilpaFont.serif(22, weight: .medium))
                            .foregroundStyle(MilpaColor.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tu nombre")
                            .font(MilpaFont.sans(14, weight: .medium))
                            .foregroundStyle(MilpaColor.ink2)
                        
                        TextField("Ej. Juan Pérez", text: $userName)
                            .font(MilpaFont.sans(16))
                            .foregroundStyle(MilpaColor.ink)
                            .padding()
                            .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MilpaColor.ink.opacity(0.1)))
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Guardar cambios")
                            .font(MilpaFont.sans(16, weight: .semibold))
                            .foregroundStyle(MilpaColor.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(MilpaColor.green, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(24)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func initials(for name: String) -> String {
        let words = name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").filter { !$0.isEmpty }
        if words.count >= 2 {
            let first = words[0].prefix(1).uppercased()
            let second = words[1].prefix(1).uppercased()
            return "\(first)\(second)"
        } else if let word = words.first, !word.isEmpty {
            return String(word.prefix(2).uppercased())
        }
        return "AG" // Fallback Agricultor
    }
}
