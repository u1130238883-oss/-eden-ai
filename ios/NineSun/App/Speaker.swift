import AVFoundation

/// 把翻譯念出來（iOS 內建語音，不用網路）。靜音模式下也聽得到。
final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    /// lang：語音語言代號（zh-TW、en-US、es-ES、it-IT…）
    func say(_ text: String, lang: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        DispatchQueue.main.async {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            if self.synth.isSpeaking { self.synth.stopSpeaking(at: .immediate) }
            let u = AVSpeechUtterance(string: t)
            u.voice = AVSpeechSynthesisVoice(language: lang)
                ?? AVSpeechSynthesisVoice(language: String(lang.prefix(2)))
            u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
            self.synth.speak(u)
        }
    }
}
