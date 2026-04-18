import SwiftUI

struct AboutSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // IA Justification Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Justificación Técnica de IA")
                            .font(MilpaFont.serif(22, weight: .bold))
                            .foregroundStyle(MilpaColor.greenD)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Milpa prioriza la privacidad, accesibilidad y la independencia de la red utilizando Apple Foundation Models 100% on-device.")
                            .font(MilpaFont.sans(16, weight: .medium))
                            .foregroundStyle(MilpaColor.ink)
                        
                        Text("Para una app rural, no podemos depender de internet. Utilizamos los modelos de lenguaje integrados de iOS para entender la intención del agricultor vía NLP, y Vision para clasificar enfermedades de hojas en tiempo real sin consumir datos ni depender de servidores externos.")
                            .font(MilpaFont.sans(15))
                            .foregroundStyle(MilpaColor.ink2)
                    }
                    .padding()
                    .background(MilpaColor.cream2, in: RoundedRectangle(cornerRadius: 16))
                    
                    // Stats Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("El Impacto")
                            .font(MilpaFont.serif(22, weight: .bold))
                            .foregroundStyle(MilpaColor.ocreD)
                            .accessibilityAddTraits(.isHeader)
                        
                        StatRow(number: "70%", text: "De los alimentos a nivel mundial son producidos por pequeños agricultores.")
                        StatRow(number: "1/3", text: "De la producción se pierde por enfermedades y mala gestión del suelo.")
                        StatRow(number: "100%", text: "De las funciones clave en Milpa operan offline, democratizando el acceso a tecnología avanzada.")
                    }
                    .padding()
                    .background(MilpaColor.ocreBg, in: RoundedRectangle(cornerRadius: 16))
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(MilpaColor.paper.ignoresSafeArea())
            .navigationTitle("Acerca de Milpa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .font(MilpaFont.sans(16, weight: .bold))
                    .foregroundStyle(MilpaColor.green)
                    .accessibilityLabel("Cerrar pantalla acerca de")
                }
            }
        }
    }
}

struct StatRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(MilpaFont.serif(28, weight: .black))
                .foregroundStyle(MilpaColor.rust)
                .frame(width: 80, alignment: .leading)
            
            Text(text)
                .font(MilpaFont.sans(15))
                .foregroundStyle(MilpaColor.ink)
        }
        .accessibilityElement(children: .combine)
    }
}
