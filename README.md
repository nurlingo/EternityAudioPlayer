# EternityAudioPlayer

An audio player reused in several projects.

# Delegates

```swift
protocol PlayerContentDelegate: class {
    func highlightPlaying(previousIndex: IndexPath, currentIndex: IndexPath)
    func scrollTo(_ indexPath: IndexPath)
    func didPause()
    func didContinue()
    func displayProgress(_ miliseconds: Int)
}

protocol PlayerPanelDelegate: class {
    func setPlayButton(_ imageName: String)
    func togglRepeatButton(_ activated: Bool)
    func setSpeedButton(_ speed: String)
    func setProgress(_ progress: Float)
}
```
