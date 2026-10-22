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
            u.voice = Self.bestVoice(lang)
            u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
            self.synth.speak(u)
        }
    }

    /// 手機裡這個語言最好的聲音（有下載「增強／高品質」語音就用那個）
    static func bestVoice(_ lang: String) -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let exact = all.filter { $0.language == lang }
        let family = all.filter { $0.language.hasPrefix(String(lang.prefix(2))) }
        let pick = (exact.isEmpty ? family : exact).max { $0.quality.rawValue < $1.quality.rawValue }
        return pick ?? AVSpeechSynthesisVoice(language: lang)
    }
}
