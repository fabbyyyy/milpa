//
//  Speaker.swift
//  MilpaApp
//
//  Created by Alumno on 17/04/26.
//


import Foundation
import AVFoundation
import Combine

@MainActor
final class Speaker: ObservableObject {
    @Published var speakingID: String? = nil
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String, id: String = UUID().uuidString) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        // Asegurar que la sesión de audio esté en modo playback
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if session.category != .playback {
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            }
        } catch {
            print("Speaker: Error configurando sesión de audio: \(error)")
        }
        #endif

        let utter = AVSpeechUtterance(string: text)
        utter.voice = AVSpeechSynthesisVoice(language: "es-MX")
            ?? AVSpeechSynthesisVoice(language: "es-ES")
        utter.rate = AVSpeechUtteranceDefaultSpeechRate * 0.98
        utter.pitchMultiplier = 1.0
        speakingID = id
        synth.speak(utter)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speakingID = nil
    }
}

// Reusable "Escuchar" button — icon or pill
import SwiftUI

struct ListenButton: View {
    let text: String
    var variant: Variant = .pill
    var label: String = "Escuchar"
    @EnvironmentObject var speaker: Speaker
    @State private var id = UUID().uuidString

    enum Variant { case pill, icon, onDark }

    var isPlaying: Bool { speaker.speakingID == id }

    var body: some View {
        Button {
            if isPlaying { speaker.stop() } else { speaker.speak(text, id: id) }
        } label: {
            switch variant {
            case .pill:
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "pause.fill" : "speaker.wave.2.fill")
                    Text(isPlaying ? "Detener" : label)
                }
                .font(MilpaFont.sans(13, weight: .medium))
                .foregroundStyle(MilpaColor.greenD)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(MilpaColor.greenBg, in: Capsule())
            case .icon:
                Image(systemName: isPlaying ? "pause.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MilpaColor.greenD)
                    .frame(width: 34, height: 34)
                    .background(MilpaColor.greenBg, in: Circle())
            case .onDark:
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                    Text(label).font(MilpaFont.sans(12, weight: .medium))
                }
                .foregroundStyle(MilpaColor.cream)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Color.white.opacity(0.16), in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("Lee el texto en voz alta")
    }
}
