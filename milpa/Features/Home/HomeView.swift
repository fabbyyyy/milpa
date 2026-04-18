//
//  HomeView.swift
//  MilpaApp
//
//  Created by Alumno on 17/04/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Parcela.createdAt, order: .reverse) private var parcelas: [Parcela]
    @Query(sort: \ChatMessage.timestamp, order: .reverse) private var allMessages: [ChatMessage]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var speaker: Speaker
    @EnvironmentObject var router: AppRouter
    @StateObject private var cuidaVM = CuidaViewModel()
    @StateObject private var weatherManager = WeatherManager.shared
    @AppStorage("userName") private var userName: String = "Agricultor"
    @State private var showingProfile = false
    @State private var showingAddParcela = false

    /// Recent user questions paired with their assistant answers (up to 3)
    private var recentPairs: [(question: ChatMessage, answer: ChatMessage?)] {
        let userMessages = allMessages.filter { $0.role == "user" }
        return Array(userMessages.prefix(3)).map { userMsg in
            let answer = allMessages.first(where: {
                $0.role == "assistant"
                && $0.conversationId == userMsg.conversationId
                && $0.timestamp > userMsg.timestamp
            })
            return (question: userMsg, answer: answer)
        }
    }

    private let greeting = "Buenos días. Hoy hay 70% de probabilidad de lluvia. No riegues tu maíz, la naturaleza se encarga."

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
                    VStack(alignment: .leading, spacing: 22) {
                        greetingCard
                            .padding(.horizontal, 22)
                        parcelasSection
                        remindersSection
                            .padding(.horizontal, 22)
                        recentConsultations
                            .padding(.horizontal, 22)
                    }
                    .padding(.top, 8).padding(.bottom, 110)
                }
            }
            .navigationTitle("Inicio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                weatherManager.requestWeather()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingProfile = true
                    } label: {
                        Circle().fill(MilpaColor.ocreBg).frame(width: 36, height: 36)
                            .overlay(Text(initials(for: userName)).font(MilpaFont.sans(14, weight: .semibold))
                                .foregroundStyle(MilpaColor.ocreD))
                    }
                    .accessibilityLabel("Configuración de Perfil")
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileSheet()
            }
            .sheet(isPresented: $showingAddParcela) {
                AddParcelaSheet()
            }
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
        return "AG"
    }

    // MARK: - Greeting Card
    
    private var greetingCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26).fill(MilpaColor.green)
            RadialGradient(colors: [MilpaColor.corn.opacity(0.28), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 180)
                .clipShape(RoundedRectangle(cornerRadius: 26))
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    MilpaMark(size: 24)
                    Text("MILPA").font(MilpaFont.sans(12, weight: .medium))
                        .kerning(0.4).foregroundStyle(.white.opacity(0.75))
                }
                
                if weatherManager.isLoading && weatherManager.weather == nil {
                    Text("Obteniendo clima...")
                        .font(MilpaFont.serif(21, weight: .regular))
                        .foregroundStyle(MilpaColor.cream)
                        .lineSpacing(4)
                } else if let w = weatherManager.weather {
                    Text(w.alertMessage)
                        .font(MilpaFont.serif(21, weight: .regular))
                        .foregroundStyle(MilpaColor.cream)
                        .lineSpacing(4)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    
                    HStack(spacing: 8) {
                        if w.rainMM != "0mm" {
                            Chip(text: "\(w.rainMM) lluvia", bg: MilpaColor.corn.opacity(0.22), fg: MilpaColor.corn)
                        } else {
                            Chip(text: w.isOffline ? "Clima estimado" : w.locationName, bg: MilpaColor.corn.opacity(0.22), fg: MilpaColor.corn)
                        }
                        Chip(text: w.highTemp, bg: Color.white.opacity(0.15), fg: MilpaColor.cream)
                        Spacer()
                        ListenButton(text: w.audioSummary, variant: .onDark)
                    }
                } else {
                    Text("Clima no disponible. Mantén tus cultivos y prepara tu jornada.")
                        .font(MilpaFont.serif(21, weight: .regular))
                        .foregroundStyle(MilpaColor.cream)
                        .lineSpacing(4)
                }
            }
            .padding(20)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Parcelas Section
    
    private var parcelasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Tus parcelas")
                    .font(MilpaFont.serif(20, weight: .medium))
                    .foregroundStyle(MilpaColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 22)
            
            if parcelas.isEmpty {
                emptyParcelasView
                    .padding(.horizontal, 22)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(parcelas) { p in
                            NavigationLink(destination: ParcelaDetailView(parcela: p)) {
                                ParcelaCard(parcela: p)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        addMoreCard
                    }
                    .padding(.horizontal, 22)
                }
                .scrollClipDisabled()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyParcelasView: some View {
        Button {
            showingAddParcela = true
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    // Decorative background circles
                    Circle()
                        .fill(MilpaColor.greenBg.opacity(0.5))
                        .frame(width: 100, height: 100)
                    Circle()
                        .fill(MilpaColor.greenBg)
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(MilpaColor.greenD)
                }
                
                VStack(spacing: 6) {
                    Text("Agrega tu primera parcela")
                        .font(MilpaFont.serif(18, weight: .medium))
                        .foregroundStyle(MilpaColor.ink)
                    
                    Text("Registra tus cultivos, toma fotos y lleva el control de tu campo")
                        .font(MilpaFont.sans(13))
                        .foregroundStyle(MilpaColor.ink3)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                    Text("Crear parcela")
                        .font(MilpaFont.sans(14, weight: .semibold))
                }
                .foregroundStyle(MilpaColor.cream)
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(MilpaColor.green, in: Capsule())
                .shadow(color: MilpaColor.greenD.opacity(0.25), radius: 8, y: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32).padding(.horizontal, 20)
            .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(MilpaColor.greenD.opacity(0.1), style: StrokeStyle(lineWidth: 1.5, dash: [10, 8]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Crear tu primera parcela")
    }
    
    // MARK: - Add More Card (at end of horizontal scroll)
    
    private var addMoreCard: some View {
        Button {
            showingAddParcela = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(MilpaColor.greenD.opacity(0.6))
                Text("Añadir")
                    .font(MilpaFont.sans(12, weight: .medium))
                    .foregroundStyle(MilpaColor.ink3)
            }
            .frame(width: 100, height: 230)
            .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(MilpaColor.ink.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Añadir otra parcela")
    }

    // MARK: - Reminders from AI
    
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Recordatorios")
            
            if cuidaVM.isLoadingReminders {
                HStack(spacing: 10) {
                    ProgressView().tint(MilpaColor.greenD)
                    Text("Milpa genera tus recordatorios...")
                        .font(MilpaFont.sans(13))
                        .foregroundStyle(MilpaColor.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
            } else if cuidaVM.reminders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(MilpaColor.ink3.opacity(0.4))
                    Text("Agrega parcelas para recibir recordatorios")
                        .font(MilpaFont.sans(13))
                        .foregroundStyle(MilpaColor.ink3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
            } else {
                ForEach(cuidaVM.reminders) { reminder in
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
        .onAppear {
            if cuidaVM.reminders.isEmpty {
                Task {
                    await cuidaVM.generateReminders(for: parcelas)
                }
            }
        }
    }
    
    // MARK: - Recent Consultations
    
    private var recentConsultations: some View {
        Group {
            if recentPairs.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Últimas consultas")
                        .font(MilpaFont.sans(14, weight: .semibold))
                        .foregroundStyle(MilpaColor.ink3)
                        .padding(.top, 4)
                    
                    VStack(spacing: 8) {
                        ForEach(recentPairs, id: \.question.id) { pair in
                            Button {
                                router.selectedConversationId = pair.question.conversationId
                                router.tab = .decide
                            } label: {
                                consultationCard(
                                    question: pair.question.content,
                                    date: relativeTime(pair.question.timestamp)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private func consultationCard(question: String, date: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question)
                    .font(MilpaFont.sans(14, weight: .medium))
                    .foregroundStyle(MilpaColor.ink)
                    .lineLimit(2)
                
                Text(date)
                    .font(MilpaFont.sans(11))
                    .foregroundStyle(MilpaColor.ink3)
                    .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MilpaColor.ink3.opacity(0.5))
        }
        .padding(16)
        .background(MilpaColor.cream2.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MilpaColor.ink.opacity(0.04)))
    }
    
    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Ahora" }
        if interval < 3600 { return "Hace \(Int(interval / 60)) min" }
        if interval < 86400 { return "Hace \(Int(interval / 3600)) h" }
        if interval < 172800 { return "Ayer" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "d MMM"
        return fmt.string(from: date)
    }
}
