import AppKit
import AudioToolbox
import CoreAudio
import IOKit.ps

private func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

final class VolumeMonitor {
    private let onChange: (Double) -> Void
    private var device = AudioObjectID(kAudioObjectUnknown)
    private var defaultDeviceAddress = address(kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal)
    private var volumeAddress = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
    private var muteAddress = address(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
    private lazy var deviceListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.attach() }
    private lazy var volumeListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.report() }

    init(onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, .main, deviceListener)
        attach()
    }

    private func read<T>(_ object: AudioObjectID, _ address: inout AudioObjectPropertyAddress, initial: T) -> T? {
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &value) { AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0.baseAddress!) }
        return status == noErr ? value : nil
    }

    private func attach() {
        for var address in [volumeAddress, muteAddress] where device != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(device, &address, .main, volumeListener)
        }
        device = read(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, initial: AudioObjectID(kAudioObjectUnknown))!
        for var address in [volumeAddress, muteAddress] {
            AudioObjectAddPropertyListenerBlock(device, &address, .main, volumeListener)
        }
    }

    private func report() {
        guard let volume = read(device, &volumeAddress, initial: Float32(0)) else { return }
        let muted = read(device, &muteAddress, initial: UInt32(0)) == 1
        onChange(muted ? 0 : Double(volume))
    }
}

/// Brightness has no public change notification, so the private DisplayServices getter is polled.
final class BrightnessMonitor {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private var timer: Timer?

    init(onChange: @escaping (Double) -> Void) {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        let getBrightness = unsafeBitCast(dlsym(handle, "DisplayServicesGetBrightness")!, to: GetBrightness.self)
        var last: Float?
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            var value: Float = 0
            guard getBrightness(CGMainDisplayID(), &value) == 0 else { return }
            if let last, abs(last - value) > 0.005 { onChange(Double(value)) }
            last = value
        }
    }
}

final class BatteryMonitor {
    /// level 0-100, charging, and whether the change deserves a HUD (power source flipped or hit a low threshold)
    private let onChange: (Int, Bool, Bool) -> Void
    private var last: (level: Int, charging: Bool)?

    init(onChange: @escaping (Int, Bool, Bool) -> Void) {
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ context in
            Unmanaged<BatteryMonitor>.fromOpaque(context!).takeUnretainedValue().update()
        }, context).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        update()
    }

    private func update() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        guard let source = sources.first,
              let description = IOPSGetPowerSourceDescription(info, source).takeUnretainedValue() as? [String: Any],
              let level = description[kIOPSCurrentCapacityKey] as? Int else { return }
        let charging = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

        let pluggedChanged = last.map { $0.charging != charging } ?? false
        let hitLow = !charging && [20, 10, 5].contains(level) && last?.level != level
        onChange(level, charging, pluggedChanged || hitLow)
        last = (level, charging)
    }
}
