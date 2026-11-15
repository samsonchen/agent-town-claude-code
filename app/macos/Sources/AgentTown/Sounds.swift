import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// The three sounds and how each is chosen and played (docs/spec.md: Sounds → Sound settings).
enum SoundKind: String, CaseIterable, Identifiable {
    case dispatch, completion, approval
    var id: String { rawValue }

    /// On/off, default on.
    var enabledKey: String { "\(rawValue)Sound" }
    /// The chosen sound: a system sound's name, or the path of the user's own file. Absent: the default.
    var choiceKey: String { "\(rawValue)SoundName" }

    var defaultName: String {
        switch self {
        case .dispatch: "Pop"
        case .completion: "Glass"
        case .approval: "Ping"
        }
    }

    var label: String {
        switch self {
        case .dispatch: Labels.text("Ticket dispatched")
        case .completion: Labels.text("Work done")
        case .approval: Labels.text("Approval needed")
        }
    }
}

@MainActor enum SoundPlayer {
    /// Kept until they finish: NSSound stops when its last reference goes.
    private static var playing: [NSSound] = []

    static let systemFolder = URL(filePath: "/System/Library/Sounds")

    /// The names of the sounds in /System/Library/Sounds, sorted.
    static let systemSounds: [String] = {
        let names = (try? FileManager.default.contentsOfDirectory(at: systemFolder, includingPropertiesForKeys: nil))?
            .map { $0.deletingPathExtension().lastPathComponent } ?? []
        return Array(Set(names)).sorted()
    }()

    static func choice(_ kind: SoundKind) -> String {
        let c = UserDefaults.standard.string(forKey: kind.choiceKey) ?? ""
        return c.isEmpty ? kind.defaultName : c
    }

    /// A choice that is a path names the user's own file; anything else names a system sound.
    static func isFile(_ choice: String) -> Bool { choice.hasPrefix("/") }

    /// 0...1, default 1. Only agent-town's sounds, not the system volume.
    static var volume: Double {
        let v = UserDefaults.standard.object(forKey: Prefs.soundVolume) as? Double ?? 1
        return v.isFinite ? min(1, max(0, v)) : 1
    }

    private static func load(_ choice: String) -> NSSound? {
        if isFile(choice) { return NSSound(contentsOf: URL(filePath: choice), byReference: true) }
        let url = systemFolder.appending(path: "\(choice).aiff")
        if let s = NSSound(contentsOf: url, byReference: true) { return s }
        return NSSound(named: choice)?.copy() as? NSSound
    }

    /// The chosen sound, or the default when it cannot be played, or nil when neither can.
    static func sound(for kind: SoundKind) -> NSSound? { load(choice(kind)) ?? load(kind.defaultName) }

    /// Plays a sound from the office, if the menu's Sound item and the sound's own switch allow it.
    static func play(_ kind: SoundKind) {
        guard Prefs.isOn(Prefs.sound), Prefs.isOn(kind.enabledKey) else { return }
        preview(kind)
    }

    // Waking the output (macOS only). After the output has been idle for a while, some devices (a USB
    // speaker, for one) drop the start of the next sound: the first sound after a long idle came out
    // silent while the second was fine, with afplay too. So when no sound has played for `wakeAfter`
    // seconds, `wakeLead` seconds of silence play first and the sound follows. `-soundWakeLead N` and
    // `-soundWakeAfter N` change them (N of 0 for the lead turns this off, 0 for the idle time wakes
    // the output before every sound).
    private static var lastSound: Date?
    private static var wakeEnds = Date.distantPast
    private static var silence: AVAudioPlayer?

    private static func setting(_ key: String, _ fallback: Double) -> Double {
        let d = UserDefaults.standard
        return d.object(forKey: key) == nil ? fallback : max(0, d.double(forKey: key))
    }
    static var wakeLead: Double { setting("soundWakeLead", 0.7) }
    static var wakeAfter: Double { setting("soundWakeAfter", 60) }

    /// A mono 16-bit WAV of silence.
    private static func silentWAV(seconds: Double) -> Data {
        let rate = 44100
        let bytes = Int(seconds * Double(rate)) * 2
        var d = Data()
        func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes)
        d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        d.append(Data(count: bytes))
        return d
    }

    /// Plays the chosen sound once at the current volume, whatever the switches say (Settings → Play).
    static func preview(_ kind: SoundKind) {
        guard let s = sound(for: kind) else { return }
        s.volume = Float(volume)
        let now = Date()
        let lead = wakeLead
        if lead > 0, now >= wakeEnds, now.timeIntervalSince(lastSound ?? .distantPast) > wakeAfter,
           let quiet = try? AVAudioPlayer(data: silentWAV(seconds: lead)) {
            silence = quiet
            quiet.play()
            wakeEnds = now.addingTimeInterval(lead)
            if ProcessInfo.processInfo.environment["TOWN_DEBUG"] != nil { print("sound: waking the output, \(lead) s of silence first") }
        }
        let delay = max(0, wakeEnds.timeIntervalSince(now))
        lastSound = now.addingTimeInterval(delay)
        guard delay > 0 else { start(s); return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            start(s)
        }
    }

    private static func start(_ s: NSSound) {
        playing.removeAll { !$0.isPlaying }
        playing.append(s)
        s.play()
    }
}

/// Settings → Sounds: the volume, then for each sound a switch, the sound and Play; the
/// completion threshold under completion.
struct SoundSettingsView: View {
    @AppStorage(Prefs.soundVolume) private var volume = 1.0
    @AppStorage(Prefs.completionThreshold) private var threshold = 0.0

    var body: some View {
        Section(Labels.text("Sounds")) {
            LabeledContent(Labels.text("Volume")) {
                HStack {
                    Slider(value: Binding(get: { SoundPlayer.volume }, set: { volume = min(1, max(0, $0)) }), in: 0...1)
                        .labelsHidden()
                    Text(SoundPlayer.volume, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
            ForEach(SoundKind.allCases) { kind in
                SoundRow(kind: kind)
                if kind == .completion {
                    LabeledContent(Labels.text("Only when a task takes at least")) {
                        HStack(spacing: 6) {
                            TextField("", value: Binding(get: { Prefs.clampThreshold(threshold) },
                                                         set: { setThreshold($0) }),
                                      format: .number.precision(.fractionLength(0)))
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Stepper("", value: Binding(get: { Prefs.clampThreshold(threshold) }, set: { setThreshold($0) }),
                                    in: Prefs.thresholdRange, step: 5)
                                .labelsHidden()
                            Text(Labels.text("seconds (0: every task)"))
                        }
                    }
                }
            }
        }
    }

    private func setThreshold(_ v: Double) {
        threshold = Prefs.clampThreshold(v.rounded())
        TownApp.shared.store.sound.thresholdSeconds = threshold
    }
}

private struct SoundRow: View {
    let kind: SoundKind
    @AppStorage private var enabled: Bool
    @AppStorage private var stored: String

    /// The picker's tag for "Choose a file…"; never a sound name or a path.
    private static let chooseTag = "\u{1}choose"

    init(kind: SoundKind) {
        self.kind = kind
        _enabled = AppStorage(wrappedValue: true, kind.enabledKey)
        _stored = AppStorage(wrappedValue: "", kind.choiceKey)
    }

    private var current: String { stored.isEmpty ? kind.defaultName : stored }

    var body: some View {
        LabeledContent(kind.label) {
            HStack(spacing: 8) {
                Picker("", selection: Binding(get: { current }, set: { pick($0) })) {
                    Text(String(format: Labels.text("%@ (default)"), kind.defaultName)).tag(kind.defaultName)
                    ForEach(SoundPlayer.systemSounds.filter { $0 != kind.defaultName }, id: \.self) { Text($0).tag($0) }
                    if SoundPlayer.isFile(current) {
                        Divider()
                        Text(URL(filePath: current).lastPathComponent).tag(current)
                    }
                    Divider()
                    Text(Labels.text("Choose a file…")).tag(Self.chooseTag)
                }
                .labelsHidden()
                .frame(width: 180, alignment: .trailing)
                Button {
                    SoundPlayer.preview(kind)
                } label: {
                    Label(Labels.text("Play"), systemImage: "play.fill").labelStyle(.iconOnly)
                }
                .help(Labels.text("Play"))
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    private func pick(_ tag: String) {
        guard tag == Self.chooseTag else {
            stored = tag == kind.defaultName ? "" : tag
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = kind.label
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            stored = url.path(percentEncoded: false)
            SoundPlayer.preview(kind)
        }
    }
}
