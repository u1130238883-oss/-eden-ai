import CoreML
import EchoCore
import Foundation
import StableDiffusion

/// 在手機上畫圖（Apple 的 Core ML Stable Diffusion）。只畫文字描述的圖，不能放照片進來改（不做真人換臉）。
/// 畫圖和大腦都很吃記憶體：畫之前先放掉大腦。
final class Painter {
    static let shared = Painter()

    enum Failure: Error, CustomStringConvertible {
        case noModel, crossesLine, nothing
        var description: String {
            switch self {
            case .noModel: return "還沒下載畫圖的模型"
            case .crossesLine: return "這個我不畫。只畫成年人（18 歲以上），不畫小孩或看起來像小孩的角色。"
            case .nothing: return "這次沒有畫出東西，再試一次"
            }
        }
    }

    private let queue = DispatchQueue(label: "ninesun.paint", qos: .userInitiated)
    private var pipeline: StableDiffusionPipeline?
    private var loadedPath: String?
    private let lock = NSLock()
    private var cancelled = false

    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    /// 記憶體不夠、離開畫室時放掉
    func unload() {
        queue.async {
            self.pipeline?.unloadResources()
            self.pipeline = nil
            self.loadedPath = nil
        }
    }

    /// 畫圖時不能出現的（加上 AdultGuard 的未成年詞）
    static let youngWords = ["teen", "teenage", "teenager", "schoolgirl", "schoolboy", "little girl", "young girl", "little boy", "young boy",
                             "toddler", "infant", "baby", "petite child", "jk", "少女", "少男", "學生妹", "女學生", "男學生", "女高中生", "國中生", "小女孩", "小男孩"]

    static func crossesLine(_ text: String) -> Bool {
        let t = text.lowercased()
        if AdultGuard.crosses(t) { return true }
        return youngWords.contains { w in
            w.allSatisfy({ $0.isASCII })
                ? t.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: w) + #"\b"#, options: .regularExpression) != nil
                : t.contains(w)
        }
    }

    static let qualityNegative = "lowres, bad anatomy, bad hands, extra fingers, missing fingers, extra limbs, deformed, disfigured, blurry, worst quality, low quality, jpeg artifacts, watermark, signature, text"
    /// 一定加在不要的內容裡：不要畫小孩
    static let minorNegative = "child, children, kid, teen, teenager, underage, loli, shota, young, childlike, baby face, flat chest, school uniform"
    static let nsfwNegative = "nsfw, nude, naked, nipples, sex, genitals, pussy, penis"

    /// 畫一張。adult：成人模式打開了才可以畫成人內容。onStep：第幾步／總共幾步（背景執行緒）
    func paint(modelURL: URL, gpu: Bool = false, prompt: String, adult: Bool, steps: Int = 25, seed: UInt32? = nil,
               onStep: @escaping (Int, Int) -> Void, done: @escaping (Result<CGImage, Error>) -> Void) {
        queue.async {
            self.lock.lock(); self.cancelled = false; self.lock.unlock()
            guard !Self.crossesLine(prompt) else { done(.failure(Failure.crossesLine)); return }
            do {
                // 先放掉大腦，記憶體才夠
                LocalBrain.shared.unloadNow()
                if self.loadedPath != modelURL.path {
                    self.pipeline?.unloadResources()
                    self.pipeline = nil
                    let cfg = MLModelConfiguration()
                    cfg.computeUnits = gpu ? .cpuAndGPU : .cpuAndNeuralEngine
                    let p = try StableDiffusionPipeline(resourcesAt: modelURL, controlNet: [], configuration: cfg,
                                                        disableSafety: true, reduceMemory: true)
                    try p.loadResources()
                    self.pipeline = p
                    self.loadedPath = modelURL.path
                }
                guard let p = self.pipeline else { throw Failure.noModel }
                var c = StableDiffusionPipeline.Configuration(prompt: "masterpiece, best quality, " + (adult ? "adult, mature, " : "") + prompt)
                c.negativePrompt = [Self.qualityNegative, Self.minorNegative, adult ? "" : Self.nsfwNegative].filter { !$0.isEmpty }.joined(separator: ", ")
                c.stepCount = steps
                c.seed = seed ?? UInt32.random(in: 0...UInt32.max)
                c.guidanceScale = 7.0
                c.schedulerType = .dpmSolverMultistepScheduler
                c.imageCount = 1
                c.disableSafety = true
                let images = try p.generateImages(configuration: c) { progress in
                    onStep(progress.step + 1, progress.stepCount)
                    return !self.isCancelled
                }
                guard let img = images.compactMap({ $0 }).first else { throw Failure.nothing }
                done(.success(img))
            } catch {
                done(.failure(error))
            }
        }
    }
}
