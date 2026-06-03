import AppKit

final class SoundManager {
    private var bundledSound: NSSound?

    init() {
        if let url = Bundle.main.url(forResource: "alert", withExtension: "aiff") {
            bundledSound = NSSound(contentsOf: url, byReference: false)
            bundledSound?.volume = 0.8
        }
    }

    func play() {
        if let bundledSound {
            if bundledSound.isPlaying {
                bundledSound.stop()
            }
            bundledSound.play()
        } else {
            NSSound(named: NSSound.Name("Glass"))?.play()
        }
    }
}
