import SwiftUI
import SwiftData

struct DecideView: View {
    @StateObject private var viewModel = DecideViewModel()
    @EnvironmentObject var speaker: Speaker
    @EnvironmentObject var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isTextFieldFocused: Bool
    @State private var showChatHistory = false
    @State private var recordingTimer: TimeInterval = 0
    @State private var timerTask: Timer?
    @State private var waveformPhase: CGFloat = 0
    @State private var spokenMessageIds: Set<UUID> = []
    @State private var showTextInput = false

    var body: some View {
        NavigationStack {
            ZStack {
                MilpaColor.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        welcomeView
                    } else {
                        chatMessages
                    }

                    inputBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                .onTapGesture {
                    isTextFieldFocused = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showChatHistory = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(MilpaColor.ink)
                    }
                    .accessibilityLabel("Ver conversaciones anteriores")
                }
                ToolbarItem(placement: .principal) {
                    Text("Milpa")
                        .font(MilpaFont.sans(16, weight: .semibold))
                        .foregroundStyle(MilpaColor.ink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        speaker.stop()
                        viewModel.startNewConversation()
                    } label: {
                        Image(systemName: "plus.message")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(MilpaColor.ink)
                    }
                    .accessibilityLabel("Nueva conversación")
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.checkExistingPermissions()
            }
            .onReceive(router.$selectedConversationId) { id in
                if let id = id {
                    viewModel.loadExistingConversation(id)
                    // We don't reset standard tab behaviors here, 
                    // just reset the id out of the router once consumed 
                    // to prevent re-triggering. Wait, doing so might cause a re-render 
                    // which is safe. For a clean implementation, do it asynchronously.
                    DispatchQueue.main.async {
                        router.selectedConversationId = nil
                    }
                }
            }
            .sheet(isPresented: $showChatHistory) {
                ChatHistorySheet(
                    onSelectConversation: { conversationId in
                        viewModel.loadExistingConversation(conversationId)
                        showChatHistory = false
                    },
                    onNewChat: {
                        viewModel.startNewConversation()
                        showChatHistory = false
                    }
                )
            }
        }
    }

    // MARK: - Welcome (empty state)

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 100)

                // Milpa spark icon
                MilpaMark(size: 64)
                    .padding(12)

                Text("¿En qué te ayudo hoy?")
                    .font(MilpaFont.serif(24, weight: .medium))
                    .foregroundStyle(MilpaColor.ink)

                Spacer().frame(height: 30)

                VStack(spacing: 10) {
                    suggestionChip("🌽 ¿Cuándo debo regar mi maíz?")
                    suggestionChip("💰 ¿Qué precio tiene el frijol?")
                    suggestionChip("🌱 ¿Es buen momento para sembrar?")
                    suggestionChip("🐛 Tengo plaga blanca, ¿qué hago?")
                }

                Spacer()
            }
            .padding(.horizontal, 28)
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            // Strip emoji for cleaner AI input
            let cleanText = text.replacingOccurrences(of: "🌽 ", with: "")
                .replacingOccurrences(of: "💰 ", with: "")
                .replacingOccurrences(of: "🌱 ", with: "")
                .replacingOccurrences(of: "🐛 ", with: "")
            viewModel.inputText = cleanText
            viewModel.sendTextMessage()
        } label: {
            HStack(spacing: 10) {
                Text(text)
                    .font(MilpaFont.sans(14))
                    .foregroundStyle(MilpaColor.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MilpaColor.ink3)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MilpaColor.ink.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat Messages

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.messages) { msg in
                        chatBubble(msg)
                            .id(msg.id)
                    }

                    if viewModel.isProcessing {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToEnd(proxy)
            }
            .onChange(of: viewModel.isProcessing) { _, _ in
                scrollToEnd(proxy)
            }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if viewModel.isProcessing {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 50) }

            if !message.isUser {
                MilpaMark(size: 22)
                    .padding(.bottom, 4)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if message.isUser {
                    Text(message.content)
                        .font(MilpaFont.sans(15))
                        .foregroundStyle(.white)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                } else {
                    MarkdownText(message.content, font: MilpaFont.sans(15), foregroundColor: MilpaColor.ink)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    Text(timeString(message.timestamp))
                        .font(MilpaFont.sans(10))
                        .foregroundStyle(message.isUser ? .white.opacity(0.6) : MilpaColor.ink3)

                    if !message.isUser {
                        Button {
                            if speaker.speakingID == message.id.uuidString {
                                speaker.stop()
                            } else {
                                speaker.speak(message.content, id: message.id.uuidString)
                            }
                        } label: {
                            Image(systemName: speaker.speakingID == message.id.uuidString ? "pause.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(MilpaColor.greenD)
                                .padding(6)
                                .background(MilpaColor.greenBg, in: Circle())
                        }
                        .accessibilityLabel("Escuchar respuesta")
                        .accessibilityHint("Lee el texto en voz alta")
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                message.isUser
                    ? AnyShapeStyle(MilpaColor.green)
                    : AnyShapeStyle(MilpaColor.paper),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                message.isUser
                    ? nil
                    : RoundedRectangle(cornerRadius: 20).strokeBorder(MilpaColor.ink.opacity(0.06))
            )

            if !message.isUser { Spacer(minLength: 50) }
        }
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .onAppear {
            if !message.isUser && message.id == viewModel.messages.last?.id {
                if !spokenMessageIds.contains(message.id) {
                    spokenMessageIds.insert(message.id)
                    speaker.speak(message.content, id: message.id.uuidString)
                }
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            MilpaMark(size: 22)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(MilpaColor.greenD.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: viewModel.isProcessing
                        )
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MilpaColor.ink.opacity(0.06)))

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Live transcription above the bar while recording
            if viewModel.isListening && !viewModel.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(MilpaColor.rust).frame(width: 6, height: 6)
                        Text("ESCUCHANDO")
                            .font(MilpaFont.sans(10, weight: .semibold))
                            .kerning(0.4)
                            .foregroundStyle(MilpaColor.rust)
                    }
                    Text(viewModel.transcribedText)
                        .font(MilpaFont.sans(14))
                        .foregroundStyle(MilpaColor.ink)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(MilpaColor.rustBg.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if viewModel.isListening {
                recordingBar
            } else if showTextInput {
                textInputBar
            } else {
                voiceInputBar
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isListening)
        .animation(.easeInOut(duration: 0.2), value: showTextInput)
    }

    // MARK: - Voice-First Input (default)

    private var voiceInputBar: some View {
        HStack(spacing: 16) {
            // Keyboard toggle
            Button {
                showTextInput = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MilpaColor.ink3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Cambiar a escribir")

            Spacer()

            // Big mic button
            Button {
                if viewModel.permissionStatus == .unknown {
                    viewModel.requestPermissions(thenStart: true)
                } else {
                    speaker.stop()
                    startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(MilpaColor.green)
                        .frame(width: 64, height: 64)
                        .shadow(color: MilpaColor.green.opacity(0.3), radius: 12, y: 6)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .disabled(viewModel.isProcessing || viewModel.permissionStatus == .denied)
            .accessibilityLabel("Habla con Milpa")
            .accessibilityHint("Toca para empezar a hablar")

            Spacer()

            // Invisible spacer to balance the keyboard button
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Text Input (secondary)

    private var textInputBar: some View {
        VStack(spacing: 8) {
            TextField("Escribe tu pregunta...", text: $viewModel.inputText, axis: .vertical)
                .font(MilpaFont.sans(15))
                .foregroundStyle(MilpaColor.ink)
                .lineLimit(1...4)
                .focused($isTextFieldFocused)
                .onSubmit { sendTextAndReset() }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .accessibilityLabel("Escribe tu pregunta")

            HStack(spacing: 8) {
                // Back to mic mode
                Button {
                    isTextFieldFocused = false
                    showTextInput = false
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(MilpaColor.greenD)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Cambiar a voz")

                Spacer()

                // Send button
                Button {
                    sendTextAndReset()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            hasText ? MilpaColor.green : MilpaColor.ink3.opacity(0.25)
                        )
                }
                .disabled(!hasText || viewModel.isProcessing)
                .accessibilityLabel("Enviar mensaje")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.black.opacity(0.06)))
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
    }

    // MARK: - Recording Bar

    private var recordingBar: some View {
        HStack(spacing: 12) {
            Button {
                cancelRecording()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MilpaColor.ink2)
                    .frame(width: 36, height: 36)
                    .background(MilpaColor.cream2, in: Circle())
            }
            .accessibilityLabel("Cancelar grabación")

            HStack(spacing: 2.5) {
                ForEach(0..<30, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(MilpaColor.ink.opacity(0.7))
                        .frame(width: 2.5, height: waveHeight(for: i))
                        .animation(
                            .easeInOut(duration: 0.3 + Double.random(in: 0...0.3))
                                .repeatForever(autoreverses: true),
                            value: waveformPhase
                        )
                }
            }
            .frame(maxWidth: .infinity)

            Text(formattedTime(recordingTimer))
                .font(MilpaFont.mono(13))
                .foregroundStyle(MilpaColor.ink2)
                .monospacedDigit()

            Button {
                stopAndSendRecording()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(MilpaColor.green, in: Circle())
            }
            .accessibilityLabel("Enviar grabación")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.black.opacity(0.06)))
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        .onAppear {
            waveformPhase += 1
        }
    }

    // MARK: - Recording Helpers

    private func startRecording() {
        recordingTimer = 0
        viewModel.toggleListening(speaker: speaker)
        timerTask = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                recordingTimer += 1
            }
        }
    }

    private func cancelRecording() {
        timerTask?.invalidate()
        timerTask = nil
        recordingTimer = 0
        // Stop listening without sending
        viewModel.cancelListening()
    }

    private func stopAndSendRecording() {
        timerTask?.invalidate()
        timerTask = nil
        recordingTimer = 0
        viewModel.stopListening(speaker: speaker)
    }

    private func sendTextAndReset() {
        viewModel.sendTextMessage()
        isTextFieldFocused = false
        showTextInput = false
    }

    private func waveHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 4
        let maxExtra: CGFloat = 14
        let seed = sin(Double(index) * 0.7 + waveformPhase * 2.0)
        return base + CGFloat(abs(seed)) * maxExtra
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Helpers

    private var hasText: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }
}

// MARK: - Chat History Sheet

struct ChatHistorySheet: View {
    @Query(sort: \ChatMessage.timestamp, order: .reverse) private var allMessages: [ChatMessage]
    @Environment(\.dismiss) private var dismiss

    let onSelectConversation: (UUID) -> Void
    let onNewChat: () -> Void

    private var conversations: [(id: UUID, firstMessage: String, date: Date)] {
        var seen = Set<UUID>()
        var result: [(id: UUID, firstMessage: String, date: Date)] = []
        for msg in allMessages where msg.role == "user" {
            if !seen.contains(msg.conversationId) {
                seen.insert(msg.conversationId)
                result.append((id: msg.conversationId, firstMessage: msg.content, date: msg.timestamp))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MilpaColor.cream.ignoresSafeArea()

                if conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36))
                            .foregroundStyle(MilpaColor.ink3.opacity(0.4))
                        Text("No tienes conversaciones aún")
                            .font(MilpaFont.sans(15))
                            .foregroundStyle(MilpaColor.ink3)
                    }
                } else {
                    List {
                        ForEach(conversations, id: \.id) { convo in
                            Button {
                                onSelectConversation(convo.id)
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(convo.firstMessage)
                                            .font(MilpaFont.sans(14, weight: .medium))
                                            .foregroundStyle(MilpaColor.ink)
                                            .lineLimit(2)

                                        Text(relativeTime(convo.date))
                                            .font(MilpaFont.sans(11))
                                            .foregroundStyle(MilpaColor.ink3)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(MilpaColor.ink3.opacity(0.5))
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(MilpaColor.cream)
                            .listRowSeparatorTint(MilpaColor.ink.opacity(0.1))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Conversaciones")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(MilpaColor.ink2)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onNewChat()
                    } label: {
                        Image(systemName: "plus.message")
                            .foregroundStyle(MilpaColor.greenD)
                    }
                    .accessibilityLabel("Nueva conversación")
                }
            }
        }
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
