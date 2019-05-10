import Foundation
import AVFoundation


class PluginGetUserMedia {
	var rtcPeerConnectionFactory: RTCPeerConnectionFactory


	init(rtcPeerConnectionFactory: RTCPeerConnectionFactory) {
		NSLog("PluginGetUserMedia#init()")

		self.rtcPeerConnectionFactory = rtcPeerConnectionFactory
	}


	deinit {
		NSLog("PluginGetUserMedia#deinit()")
	}


	func call(
		_ constraints: NSDictionary,
		callback: (_ data: NSDictionary) -> Void,
		errback: (_ error: String) -> Void,
		eventListenerForNewStream: (_ pluginMediaStream: PluginMediaStream) -> Void
	) {
		NSLog("PluginGetUserMedia#call()")

		var	videoRequested: Bool = false
		var	audioRequested: Bool = false

		if (constraints.object(forKey: "video") != nil) {
			videoRequested = true
		}
		
		if constraints.object(forKey: "audio") != nil {
			audioRequested = true
		}

		var rtcMediaStream: RTCMediaStream
		var pluginMediaStream: PluginMediaStream?
		var rtcAudioTrack: RTCAudioTrack?
		var rtcVideoTrack: RTCVideoTrack?
		var rtcVideoSource: RTCVideoSource?
		
		if videoRequested {
			switch AVCaptureDevice.authorizationStatus(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.video))) {
			case AVAuthorizationStatus.notDetermined:
				NSLog("PluginGetUserMedia#call() | video authorization: not determined")
			case AVAuthorizationStatus.authorized:
				NSLog("PluginGetUserMedia#call() | video authorization: authorized")
			case AVAuthorizationStatus.denied:
				NSLog("PluginGetUserMedia#call() | video authorization: denied")
				errback("video denied")
				return
			case AVAuthorizationStatus.restricted:
				NSLog("PluginGetUserMedia#call() | video authorization: restricted")
				errback("video restricted")
				return
			}
		}
		
		if audioRequested {
			switch AVCaptureDevice.authorizationStatus(for: AVMediaType(rawValue: convertFromAVMediaType(AVMediaType.audio))) {
			case AVAuthorizationStatus.notDetermined:
				NSLog("PluginGetUserMedia#call() | audio authorization: not determined")
			case AVAuthorizationStatus.authorized:
				NSLog("PluginGetUserMedia#call() | audio authorization: authorized")
			case AVAuthorizationStatus.denied:
				NSLog("PluginGetUserMedia#call() | audio authorization: denied")
				errback("audio denied")
				return
			case AVAuthorizationStatus.restricted:
				NSLog("PluginGetUserMedia#call() | audio authorization: restricted")
				errback("audio restricted")
				return
			}
		}

		rtcMediaStream = self.rtcPeerConnectionFactory.mediaStream(withStreamId: UUID().uuidString)

		if videoRequested {
			let videoConstraints = constraints.object(forKey: "video") as! NSDictionary

			NSLog("PluginGetUserMedia#call() | chosen video constraints: %@", videoConstraints)

			rtcVideoSource = self.rtcPeerConnectionFactory.videoSource()

			// If videoSource state is "ended" it means that constraints were not satisfied so
			// invoke the given errback.
			if (rtcVideoSource!.state == RTCSourceState.ended) {
				NSLog("PluginGetUserMedia() | rtcVideoSource.state is 'ended', constraints not satisfied")

				errback("constraints not satisfied")
				return
			}

			rtcVideoTrack = self.rtcPeerConnectionFactory.videoTrack(with: rtcVideoSource!,
																	 trackId: UUID().uuidString)
			
#if !TARGET_IPHONE_SIMULATOR
			let videoCapturer: RTCCameraVideoCapturer = RTCCameraVideoCapturer(delegate: rtcVideoSource!)
			let videoCaptureController: PluginVideoCaptureController =
				PluginVideoCaptureController(capturer: videoCapturer, constraints: videoConstraints)
			rtcVideoTrack!.videoCaptureController = videoCaptureController
			videoCaptureController.startCapture()
#endif

			rtcMediaStream.addVideoTrack(rtcVideoTrack!)
		}

		if audioRequested {
			NSLog("PluginGetUserMedia#call() | audio requested")

			rtcAudioTrack = self.rtcPeerConnectionFactory.audioTrack(withTrackId: UUID().uuidString)

			rtcMediaStream.addAudioTrack(rtcAudioTrack!)
		}

		pluginMediaStream = PluginMediaStream(rtcMediaStream: rtcMediaStream)
		pluginMediaStream!.run()

		// Let the plugin store it in its dictionary.
		eventListenerForNewStream(pluginMediaStream!)

		callback([
			"stream": pluginMediaStream!.getJSON()
		])
	}
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVMediaType(_ input: AVMediaType) -> String {
	return input.rawValue
}
