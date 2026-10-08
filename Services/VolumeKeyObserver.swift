import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

/// Obserwator fizycznych przycisków głośności na iOS.
/// Wykrywa naciśnięcia głośności w dół (AI Solve) oraz w górę (Panic Mode).
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
    private var volumeView: MPVolumeView?
    
    private init() {
        setupAudioSession()
    }
    
    public func startObserving() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        
        lastVolume = audioSession.outputVolume
        setupHiddenVolumeSlider()
        
        // Obserwacja właściwości outputVolume
        audioSession.publisher(for: \.outputVolume)
            .receive(on: DispatchQueue.main)
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
            print("[VolumeKeyObserver] Błąd audio session: \(error)")
        }
    }
    
    private func setupHiddenVolumeSlider() {
        DispatchQueue.main.async {
            if self.volumeView == nil {
                let view = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
                view.isHidden = false
                view.alpha = 0.01
                if let window = UIApplication.shared.windows.first {
                    window.addSubview(view)
                }
                self.volumeView = view
            }
        }
    }
    
    private func resetVolumeToCenter() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let volumeView = self.volumeView,
               let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                slider.value = 0.5
                self.lastVolume = 0.5
            }
        }
    }
    
    private func handleVolumeChange(newVolume: Float) {
        let now = Date()
        let delta = newVolume - lastVolume
        lastVolume = newVolume
        
        // Zmniejszenie głośności (Volume Down) -> AI Solve
        if delta < -0.001 || newVolume < 0.45 {
            cleanOldTimestamps(&volumeDownTimestamps, now: now)
            volumeDownTimestamps.append(now)
            
            if volumeDownTimestamps.count >= 1 { // Natychmiastowe reagowanie na kliknięcie głośności w dół
                volumeDownTimestamps.removeAll()
                self.lastTriggeredAction = .triggerAI
                print("[Makarena Volume] GŁOŚNOŚĆ W DÓŁ -> Włączam AI Solve")
                resetVolumeToCenter()
            }
        }
        // Zwiększenie głośności (Volume Up) -> Panic Mode
        else if delta > 0.001 || newVolume > 0.55 {
            cleanOldTimestamps(&volumeUpTimestamps, now: now)
            volumeUpTimestamps.append(now)
            
            if volumeUpTimestamps.count >= 1 { // Natychmiastowe reagowanie na kliknięcie głośności w górę
                volumeUpTimestamps.removeAll()
                self.lastTriggeredAction = .triggerPanic
                print("[Makarena Volume] GŁOŚNOŚĆ W GÓRĘ -> Włączam PANIC MODE")
                resetVolumeToCenter()
            }
        }
    }
    
    private func cleanOldTimestamps(_ array: inout [Date], now: Date) {
        array = array.filter { now.timeIntervalSince($0) < 1.5 }
    }
}
