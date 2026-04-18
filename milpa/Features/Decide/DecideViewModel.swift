import Foundation
import Combine
import SwiftUI
import SwiftData
import Speech
import AVFoundation

@MainActor
final class DecideViewModel: ObservableObject {

    enum InputMode { case idle, recording, processing }
    enum PermissionStatus { case unknown, granted, denied }

    // MARK: - Published State

    @Published var messages: [ChatMessage] = []
    @Published var inputMode: InputMode = .idle
    @Published var inputText: String = ""
    @Published var transcribedText: String = ""
    @Published var permissionStatus: PermissionStatus = .unknown
    @Published var errorMessage: String = ""

    // MARK: - Conversation

    private(set) var conversationId: UUID = UUID()
    private let foundationModels = FoundationModelManager.shared
    private var modelContext: ModelContext?

    // MARK: - Speech Recognition

    private let speechRecognizer: SFSpeechRecognizer? = {
        let preferred = ["es-MX", "es-419", "es", "es-ES"]
        for id in preferred {
            if let r = SFSpeechRecognizer(locale: Locale(identifier: id)), r.isAvailable {
                return r
            }
        }
        return SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    }()

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var userWantsToListen = false
    private var accumulatedText: String = ""

    var isListening: Bool { inputMode == .recording }
    var isProcessing: Bool { inputMode == .processing }

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadConversation()
    }

    private func loadConversation() {
        guard let modelContext else { return }
        let cid = conversationId
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.conversationId == cid },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        messages = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Permissions

    func checkExistingPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        guard speechStatus == .authorized else { return }
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                self.permissionStatus = granted ? .granted : .denied
            }
        }
    }

    func requestPermissions(thenStart: Bool = false) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            Task { @MainActor in
                switch authStatus {
                case .authorized:
                    AVAudioApplication.requestRecordPermission { granted in
                        Task { @MainActor in
                            self.permissionStatus = granted ? .granted : .denied
                            if granted && thenStart { self.startListening() }
                        }
                    }
                default:
                    self.permissionStatus = .denied
                }
            }
        }
    }

    // MARK: - Send Message (text or voice)

    func sendTextMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendMessage(text)
    }

    func sendMessage(_ text: String) {
        // Add user message
        let userMsg = ChatMessage(role: "user", content: text, conversationId: conversationId)
        messages.append(userMsg)
        modelContext?.insert(userMsg)
        try? modelContext?.save()

        // Process with AI
        inputMode = .processing
        Task {
            do {
                let response = try await foundationModels.sendChatMessage(text)
                let assistantMsg = ChatMessage(role: "assistant", content: response, conversationId: conversationId)
                messages.append(assistantMsg)
                modelContext?.insert(assistantMsg)
                try? modelContext?.save()
                inputMode = .idle
            } catch {
                errorMessage = "No pude responder: \(error.localizedDescription)"
                inputMode = .idle
            }
        }
    }

    // MARK: - Voice Input

    func toggleListening(speaker: Speaker) {
        if isListening {
            stopListening(speaker: speaker)
        } else {
            startListening()
        }
    }

    private func startListening() {
        guard permissionStatus == .granted else {
            requestPermissions()
            return
        }
        guard speechRecognizer != nil else {
            errorMessage = "Reconocedor de voz no disponible."
            return
        }

        errorMessage = ""

        if !userWantsToListen {
            transcribedText = ""
            accumulatedText = ""
        }
        userWantsToListen = true

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Error configurando audio: \(error.localizedDescription)"
            return
        }
        #endif

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            inputMode = .recording
        } catch {
            errorMessage = "Error iniciando audio: \(error.localizedDescription)"
            return
        }

        recognitionTask = speechRecognizer!.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.userWantsToListen || result?.isFinal == false else { return }

                if let result {
                    let newText = result.bestTranscription.formattedString
                    if !newText.isEmpty {
                        let combined = self.accumulatedText.isEmpty
                            ? newText
                            : "\(self.accumulatedText) \(newText)"
                        self.transcribedText = combined
                    }
                }

                let isCancellation: Bool = {
                    guard let error else { return false }
                    let nsError = error as NSError
                    return (nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216)
                        || (nsError.domain == "kLSRErrorDomain" && nsError.code == 301)
                }()

                if let error, !isCancellation {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.inputMode = .idle
                    return
                }

                let ended = (result?.isFinal == true) || (error != nil)
                if ended && self.userWantsToListen {
                    self.accumulatedText = self.transcribedText
                    self.startListening()
                }
            }
        }
    }

    func stopListening(speaker: Speaker) {
        userWantsToListen = false
        let command = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        // Restaurar sesión de audio a playback para que AVSpeechSynthesizer funcione
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error restaurando sesión de audio a playback: \(error)")
        }
        #endif

        inputMode = .idle

        guard !command.isEmpty else { return }
        transcribedText = ""
        sendMessage(command)
    }

    /// Cancel recording without sending anything
    func cancelListening() {
        userWantsToListen = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error restaurando sesión de audio: \(error)")
        }
        #endif

        inputMode = .idle
        transcribedText = ""
        accumulatedText = ""
    }

    // MARK: - New Conversation

    func startNewConversation() {
        conversationId = UUID()
        messages = []
        foundationModels.resetSession()
        inputText = ""
        transcribedText = ""
        errorMessage = ""
    }

    // MARK: - Load Existing Conversation

    func loadExistingConversation(_ id: UUID) {
        conversationId = id
        foundationModels.resetSession()
        inputText = ""
        transcribedText = ""
        errorMessage = ""
        loadConversation()
    }
}
