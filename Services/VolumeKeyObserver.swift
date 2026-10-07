import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// Obserwator fizycznych przycisków głośności na iOS.
/// Wykrywa dwukrotne naciśnięcie głośności w dół (AI Solve) oraz w górę (Panic Mode).
public class VolumeKeyObserver: ObservableObject {
    public static let shared = VolumeKeyObserver()
    
    @Published public var lastTriggeredAction: ActionType? = nil
    
    public enum ActionType {
        case triggerAI
        case triggerPanic
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var lastVolume: Float = 0.5
    private var volumeDownTimestamps: [Date] = []
    private var volumeUpTimestamps: [Date] = []
    
    private init() {
        setupAudioSession()
    }
    
    public func startObserving() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        
        lastVolume = audioSession.outputVolume
        
        // Obserwacja właściwości outputVolume
        audioSession.publisher(for: \.outputVolume)
            .sink { [weak self] newVolume in
                self?.handleVolumeChange(newVolume: newVolume)
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            consoleLog("Błąd audio session: \(error)")
        }
    }
    
    private func handleVolumeChange(newVolume: Float) {
        let now = Date()
        let delta = newVolume - lastVolume
        lastVolume = newVolume
        
        // Zmniejszenie głośności (Volume Down)
        if delta < -0.001 {
            cleanOldTimestamps(&volumeDownTimestamps, now: now)
            volumeDownTimestamps.append(now)
            
            if volumeDownTimestamps.count >= 2 {
                volumeDownTimestamps.removeAll()
                DispatchQueue.main.async {
                    self.lastTriggeredAction = .triggerAI
                    print("[Makarena Volume] Wykryto dwukrotne kliknięcie GŁOŚNOŚĆ W DÓŁ -> Włączam AI Solve")
                }
            }
        }
        // Zwiększenie głośności (Volume Up)
        else if delta > 0.001 {
            cleanOldTimestamps(&volumeUpTimestamps, now: now)
            volumeUpTimestamps.append(now)
            
            if volumeUpTimestamps.count >= 2 {
                volumeUpTimestamps.removeAll()
                DispatchQueue.main.async {
                    self.lastTriggeredAction = .triggerPanic
                    print("[Makarena Volume] Wykryto dwukrotne kliknięcie GŁOŚNOŚĆ W GÓRĘ -> Włączam PANIC MODE")
                }
            }
        }
    }
    
    private func cleanOldTimestamps(_ array: inout [Date], now: Date) {
        // Zliczamy naciśnięcia z ostatnich 1.2 sekundy
        array = array.filter { now.timeIntervalSince($0) < 1.2 }
    }
    
    private func consoleLog(_ message: String) {
        print("[VolumeKeyObserver] \(message)")
    }
}
