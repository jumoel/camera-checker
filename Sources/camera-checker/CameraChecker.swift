//
//  CameraChecker.swift
//
//
//  Created by wouter.de.bie on 11/21/19.
//
import AVFoundation

class CameraChecker: NSObject, USBWatcherDelegate, URLSessionDelegate {
	private var cameras: [Camera] = []
	private var usbWatcher: USBWatcher!
	private var isInitialized: Bool = false
	private var ignoreCameras: [String] = []
	private var debug: Bool

	init(ignore: String?, debug: Bool) {
		self.debug = debug

		super.init()

		if ignore != nil {
			ignoreCameras = (ignore?.split(separator: ",").map { String($0) })!
		}

		usbWatcher = USBWatcher(delegate: self)
		initCameras()
		isInitialized = true
	}

	func initCameras() {
		if self.debug {
			logger.info("Camera(s) found:")
		}
		let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(
			deviceTypes: [
				AVCaptureDevice.DeviceType.builtInWideAngleCamera,
				AVCaptureDevice.DeviceType.externalUnknown,
			],
			mediaType: AVMediaType.video,
			position: AVCaptureDevice.Position.unspecified)

		for device in deviceDescoverySession.devices {
			let name = "\(device.manufacturer)/\(device.localizedName)"
			if ignoreCameras.contains(name) {
				if self.debug {
					logger.info(" - \(name) (ignored)")
				}
				continue
			}

			let camera = Camera(captureDevice: device, onChange: self.checkCameras)
			if self.debug {
				logger.info(" - \(camera)")
			}
			cameras.append(camera)

			if self.debug {
				for camera in cameras {
					camera.report()
				}
			}
		}
	}

	func checkCameras() {
		let onCameras = cameras.filter { $0.isOn() }.map { $0.description }
		let anyOn = !onCameras.isEmpty

		// Construct a JSON payload to print to stdout
		let payload: [String: Any] = [
			"on": anyOn,
			"cameras": onCameras,
		]

		// write to stdout directly
		let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
		FileHandle.standardOutput.write(data)
		FileHandle.standardOutput.write("\n".data(using: .utf8)!)
	}

	// If we're initialized and a device is added or removed, we crudely exit.
	// Since we're running in a sub process, everything will be reinitalized
	// anyway and we don't need to worry about removing listeners, traversing
	// devices, etc.
	func deviceAdded(_ device: io_object_t) {
		if isInitialized {
			logger.info("Device added: \(device.name() ?? "<unknown>")")
			exit(0)
		}
	}

	func deviceRemoved(_ device: io_object_t) {
		if isInitialized {
			logger.info("Device removed: \(device.name() ?? "<unknown>")")
			exit(0)
		}
	}
}

extension io_object_t {
	/// - Returns: The device's name.
	func name() -> String? {
		let buf = UnsafeMutablePointer<io_name_t>.allocate(capacity: 1)
		defer { buf.deallocate() }
		return buf.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<io_name_t>.size) {
			if IORegistryEntryGetName(self, $0) == KERN_SUCCESS {
				return String(cString: $0)
			}
			return nil
		}
	}
}
