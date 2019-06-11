import Foundation


//class RTCMediaStreamTrack : React {
//	var videoCaptureController: VideoCaptureController?
//}


class PluginMediaStreamTrack : NSObject {
	var rtcMediaStreamTrack: RTCMediaStreamTrack
	var id: String
	var kind: String
	var eventListener: ((_ data: NSDictionary) -> Void)?
	var eventListenerForEnded: (() -> Void)?
	var lostStates = Array<String>()
	var renders: [String : PluginMediaStreamRenderer]


	init(rtcMediaStreamTrack: RTCMediaStreamTrack) {
		NSLog("PluginMediaStreamTrack#init()")

		self.rtcMediaStreamTrack = rtcMediaStreamTrack
		self.id = rtcMediaStreamTrack.trackId
		self.kind = rtcMediaStreamTrack.kind
		self.renders = [:]
	}


	deinit {
		NSLog("PluginMediaStreamTrack#deinit()")
	}


	func run() {
		NSLog("PluginMediaStreamTrack#run() [kind:%@, id:%@]", String(self.kind), String(self.id))

	}


	func getJSON() -> NSDictionary {
		return [
			"id": self.id,
			"kind": self.kind,
			"label": self.rtcMediaStreamTrack.trackId,
			"enabled": self.rtcMediaStreamTrack.isEnabled ? true : false,
			"readyState": PluginRTCTypes.mediaStreamTrackStates[self.rtcMediaStreamTrack.readyState.rawValue] as Any
		]
	}


	func setListener(
		_ eventListener: @escaping (_ data: NSDictionary) -> Void,
		eventListenerForEnded: @escaping () -> Void
	) {
		NSLog("PluginMediaStreamTrack#setListener() [kind:%@, id:%@]", String(self.kind), String(self.id))

		self.eventListener = eventListener
		self.eventListenerForEnded = eventListenerForEnded

		for readyState in self.lostStates {
			self.eventListener!([
				"type": "statechange",
				"readyState": readyState,
				"enabled": (self.rtcMediaStreamTrack.isEnabled ? true : false)
			])

			if readyState == "ended" {
				self.eventListenerForEnded!()
			}
		}
		self.lostStates.removeAll()
	}


	func setEnabled(_ value: Bool) {
		NSLog("PluginMediaStreamTrack#setEnabled() [kind:%@, id:%@, value:%@]",
			String(self.kind), String(self.id), String(value))

		if (self.rtcMediaStreamTrack.isEnabled != value) {
			self.rtcMediaStreamTrack.isEnabled = value
			if (value) {
				self.rtcMediaStreamTrack.videoCaptureController?.startCapture()
			}else {
				self.rtcMediaStreamTrack.videoCaptureController?.stopCapture()
			}
		}
	}
	
	func switchCamera() {
		self.rtcMediaStreamTrack.videoCaptureController?.switchCamera()
	}

	func registerRender(render: PluginMediaStreamRenderer) {
		if let exist = self.renders[render.uuid] {
			_ = exist
		} else {
			self.renders[render.uuid] = render
		}
	}
	
	func unregisterRender(render: PluginMediaStreamRenderer) {
		self.renders.removeValue(forKey: render.uuid);
	}

	// TODO: No way to stop the track.
	// Check https://github.com/BasqueVoIPMafia/cordova-plugin-iosrtc/issues/140
	func stop() {
		NSLog("PluginMediaStreamTrack#stop() [kind:%@, id:%@]", String(self.kind), String(self.id))

		NSLog("PluginMediaStreamTrack#stop() | stop() not implemented (see: https://github.com/BasqueVoIPMafia/cordova-plugin-iosrtc/issues/140")

		// NOTE: There is no setState() anymore
		// self.rtcMediaStreamTrack.setState(RTCTrackStateEnded)
		self.rtcMediaStreamTrack.videoCaptureController?.stopCapture();
		
		// Let's try setEnabled(false), but it also fails.
		self.rtcMediaStreamTrack.isEnabled = false
		
		for (_, render) in self.renders {
			render.stop()
		}
		self.renders.removeAll();
	}
}
