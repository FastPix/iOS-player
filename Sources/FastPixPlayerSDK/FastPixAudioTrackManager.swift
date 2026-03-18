
import AVFoundation

public struct AudioTrack {
    
    public let id: String
    public let languageCode: String
    public let languageName: String
    public let label: String
    public let isSelected: Bool
    public let isDefault: Bool
    
}

public enum AudioTrackError: Error {
    
    case playerNotReady
    case noTracksAvailable
    case trackNotFound
    case switchingFailed
    
}

public protocol FastPixAudioTrackDelegate: AnyObject {
    
    func onAudioTracksUpdated(tracks: [AudioTrack])
    
    func onAudioTrackChange(selectedTrack: AudioTrack)
    
    func onAudioTrackFailed(error: AudioTrackError)
    
    func onAudioTrackSwitching(isSwitching: Bool)
}

public class FastPixAudioTrackManager {
    
    private weak var player: AVPlayer?
    
    public weak var delegate: FastPixAudioTrackDelegate?
    
    private var preferredLanguageName: String?
    
    public func setPreferredAudioTrack(languageName: String?) {
        preferredLanguageName = languageName
    }
    
    private var didApplyInitialSelection = false
    
    init(player: AVPlayer?) {
        self.player = player
    }
    
    func attach(player: AVPlayer?) {
        self.player = player
        didApplyInitialSelection = false
        fetchAudioTracks()
    }
    
    // Detect all tracks
    func fetchAudioTracks() -> [AudioTrack] {
        
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        else { return [] }
        
        let currentOption = item.currentMediaSelection.selectedMediaOption(in: group)
        
        let tracks = group.options.map { option in
            
            AudioTrack(
                id: option.extendedLanguageTag ?? option.displayName,
                languageCode: option.extendedLanguageTag ?? "",
                languageName: option.displayName,
                label: option.displayName,
                isSelected: option == currentOption,
                isDefault: option == currentOption
            )
        }
        
        delegate?.onAudioTracksUpdated(tracks: tracks)
        
        applyDefaultTrack(from: tracks)
        
        return tracks
    }
    
    func getCurrentTrack() -> AudioTrack? {
        
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        else { return nil }
        
        let currentOption = item.currentMediaSelection.selectedMediaOption(in: group)
        
        guard let option = currentOption else { return nil }
        
        return AudioTrack(
            id: option.extendedLanguageTag ?? option.displayName,
            languageCode: option.extendedLanguageTag ?? "",
            languageName: option.displayName,
            label: option.displayName,
            isSelected: true,
            isDefault: true
        )
    }
    
    // Switch track
    func selectTrack(trackId: String) throws {
        
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        else {
            delegate?.onAudioTrackFailed(error: .playerNotReady)
            throw AudioTrackError.playerNotReady
        }
        
        // Notify switching started
        delegate?.onAudioTrackSwitching(isSwitching: true)
        
        // Find requested track
        guard let option = group.options.first(where: {
            ($0.extendedLanguageTag ?? $0.displayName) == trackId
        }) else {
            delegate?.onAudioTrackFailed(error: .trackNotFound)
            delegate?.onAudioTrackSwitching(isSwitching: false)
            throw AudioTrackError.trackNotFound
        }
        
        // Select track in AVPlayer
        item.select(option, in: group)
        
        // Get currently selected option AFTER selection
        let currentSelection = item.currentMediaSelection
        let currentOption = currentSelection.selectedMediaOption(in: group)
        
        // Build AudioTrack list
        let tracks = group.options.map { opt in
            
            let isCurrentlySelected = (opt == currentOption)
            
            return AudioTrack(
                id: opt.extendedLanguageTag ?? opt.displayName,
                languageCode: opt.extendedLanguageTag ?? "",
                languageName: opt.displayName,
                label: opt.displayName,
                isSelected: isCurrentlySelected,
                isDefault: isCurrentlySelected
            )
        }
        
        // Find selected track model
        if let selectedTrack = tracks.first(where: { $0.isSelected }) {
            delegate?.onAudioTrackChange(selectedTrack: selectedTrack)
        }
        
        // Notify switching finished
        delegate?.onAudioTrackSwitching(isSwitching: false)
    }
    
    private func applyDefaultTrack(from tracks: [AudioTrack]) {
        guard !tracks.isEmpty else { return }
        guard !didApplyInitialSelection else { return }
        didApplyInitialSelection = true
        
        // 1️⃣ Match by languageName
        if let preferredName = preferredLanguageName,
           let preferredTrack = tracks.first(where: {
               $0.languageName.lowercased() == preferredName.lowercased()  // case-insensitive match
           }) {
            try? selectTrack(trackId: preferredTrack.id)
            return
        }
        
        // 2️⃣ Otherwise do nothing — AVPlayer already selected manifest default
    }
}
