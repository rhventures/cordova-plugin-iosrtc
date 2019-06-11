import Foundation
import AVFoundation

import func ObjectiveC.objc_getAssociatedObject
import func ObjectiveC.objc_setAssociatedObject
import enum ObjectiveC.objc_AssociationPolicy

public func objc_getx<TargetObject: AnyObject, AssociatedObject: AnyObject>
	(object getObject: @autoclosure () -> AssociatedObject,
	 associatedTo target:TargetObject,
	 withConstPtrKey ptr:UnsafeRawPointer)
	-> AssociatedObject
{
	var object = objc_getAssociatedObject(target, ptr) as? AssociatedObject
	if object == nil {
		object = getObject()
		objc_setAssociatedObject(target, ptr, object, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}
	return object!
}


extension RTCMediaStreamTrack {
	
	class PropClass {
		var videoCaptureController: PluginVideoCaptureController?
	}
	
	var _propClass : PropClass {
		get {
			let key: UnsafeRawPointer! = UnsafeRawPointer.init(bitPattern:self.hashValue)
			return objc_getx(object: PropClass(), associatedTo: self, withConstPtrKey: key)
		}
	}
	
	var videoCaptureController: PluginVideoCaptureController? {
		get {
			return _propClass.videoCaptureController
		}
		set {
			_propClass.videoCaptureController = newValue
		}
	}
}

extension RTCPeerConnection {
	func addVideoTrackAdapter(streamId: String, track: RTCVideoTrack) {
		
	}
	
	func removeVideoTrackAdapter(track: RTCVideoTrack) {
		
	}
}



class PluginVideoCaptureController : NSObject {
	
	var capturer: RTCCameraVideoCapturer
	var sourceId: String
	var usingFrontCamera: Bool
	var targetWidth: Int32
	var targetHeight: Int32
	var targetFrameRate: Int32
	var targetAspectRatio: Double
	
	init(capturer: RTCCameraVideoCapturer, constraints: NSDictionary) {
		self.capturer = capturer
		self.sourceId = ""
		// Default to the front camera.
		self.usingFrontCamera = true
		
		// Check the video contraints: examine facingMode and sourceId
		// and pick a default if neither are specified.
		let facingMode = constraints.object(forKey: "facingMode") as? String ?? ""
		if (facingMode.count > 0) {
			var position: AVCaptureDevice.Position
			if (facingMode == "environment") {
				position = AVCaptureDevice.Position.back
			} else if (facingMode == "user") {
				position = AVCaptureDevice.Position.front
			} else {
				// If the specified facingMode value is not supported, fall back
				// to the front camera.
				position = AVCaptureDevice.Position.front
			}
			
			self.usingFrontCamera = (position == AVCaptureDevice.Position.front)
		}
		
		self.sourceId = constraints.object(forKey: "deviceId") as? String ?? ""
		self.targetWidth = constraints.object(forKey: "width") as? Int32 ?? 1280
		self.targetHeight = constraints.object(forKey: "height") as? Int32 ?? 720
		self.targetFrameRate = constraints.object(forKey: "frameRate") as? Int32 ?? 30
		self.targetAspectRatio = constraints.object(forKey: "aspectRatio") as? Double ?? (16.0/9)
	}
	

	func startCapture() {
		var device: AVCaptureDevice?
		if (self.sourceId.count > 0) {
			device = AVCaptureDevice(uniqueID: self.sourceId)
			if (!device!.isConnected) {
				device = nil
			}
		}
		if (device == nil) {
			let position: AVCaptureDevice.Position = (self.usingFrontCamera) ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back
			device = findDeviceForPosition(position: position);
		}
		
		// TODO: Extract width and height from constraints.
		let format = selectFormatForDevice(device:device!,
										   withTargetWidth:self.targetWidth,
										   withTargetHeight:self.targetHeight)
		if (format == nil) {
			NSLog("PluginVideoCaptureController#startCapture No valid formats for device %@", device!);
			return
		}
		
		// TODO: Extract fps from constraints.
		self.capturer.startCapture(with: device!, format: format!, fps: Int(self.targetFrameRate))
		
		NSLog("PluginVideoCaptureController#startCapture Capture started, device:%@, format:%@", device!, format!);
	}
	
	func stopCapture() {
		self.capturer.stopCapture()
		
		NSLog("PluginVideoCaptureController#stopCapture Capture stopped");
	}
	
	
	func switchCamera() {
		self.usingFrontCamera = !self.usingFrontCamera;
		
		self.startCapture()
	}
	
	func findDeviceForPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
		let captureDevices: NSArray = RTCCameraVideoCapturer.captureDevices() as NSArray
		for device: Any in captureDevices {
			let avDevice = device as! AVCaptureDevice
			if (avDevice.position == position) {
				return avDevice
			}
		}
	
		return captureDevices[0] as? AVCaptureDevice
	}
	
	func selectFormatForDevice(device: AVCaptureDevice,
							   withTargetWidth targetWidth: Int32,
							   withTargetHeight targetHeight: Int32) -> AVCaptureDevice.Format? {
		var selectedFormat: AVCaptureDevice.Format? = nil
		var currentDiff: Int32 = Int32.max
		let formats: NSArray = RTCCameraVideoCapturer.supportedFormats(for: device) as NSArray
		for format: Any in formats {
			let devFormat: AVCaptureDevice.Format = format as! AVCaptureDevice.Format
			let dimension: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(devFormat.formatDescription)
			let pixelFormat: FourCharCode = CMFormatDescriptionGetMediaSubType(devFormat.formatDescription)
			let diff: Int32 = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
			if (diff < currentDiff) {
				selectedFormat = devFormat
				currentDiff = diff
			}else if (diff == currentDiff && pixelFormat == self.capturer.preferredOutputPixelFormat()) {
				selectedFormat = devFormat
			}
		}
	
		return selectedFormat
	}

}
