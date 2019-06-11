import Foundation


class PluginRTCPeerConnection : NSObject, RTCPeerConnectionDelegate {
	
	var rtcPeerConnectionFactory: RTCPeerConnectionFactory
	var rtcPeerConnection: RTCPeerConnection!
	var pluginRTCPeerConnectionConfig: PluginRTCPeerConnectionConfig
	var pluginRTCPeerConnectionConstraints: PluginRTCPeerConnectionConstraints
	// PluginRTCDataChannel dictionary.
	var pluginRTCDataChannels: [Int : PluginRTCDataChannel] = [:]
	// PluginRTCDTMFSender dictionary.
	var pluginRTCDTMFSenders: [Int : PluginRTCDTMFSender] = [:]
	var eventListener: (_ data: NSDictionary) -> Void
	var eventListenerForAddStream: (_ pluginMediaStream: PluginMediaStream) -> Void
	var eventListenerForRemoveStream: (_ id: String) -> Void

	var onCreateLocalDescriptionSuccessCallback: ((_ rtcSessionDescription: RTCSessionDescription) -> Void)!
	var onCreateLocalDescriptionFailureCallback: ((_ error: Error) -> Void)!
	var onCreateRemoteDescriptionSuccessCallback: ((_ rtcSessionDescription: RTCSessionDescription) -> Void)!
	var onCreateRemoteDescriptionFailureCallback: ((_ error: Error) -> Void)!
	var onSetDescriptionSuccessCallback: (() -> Void)!
	var onSetDescriptionFailureCallback: ((_ error: Error) -> Void)!
	var onGetStatsCallback: ((_ array: NSArray) -> Void)!

	init(
		rtcPeerConnectionFactory: RTCPeerConnectionFactory,
		pcConfig: NSDictionary?,
		pcConstraints: NSDictionary?,
		eventListener: @escaping (_ data: NSDictionary) -> Void,
		eventListenerForAddStream: @escaping (_ pluginMediaStream: PluginMediaStream) -> Void,
		eventListenerForRemoveStream: @escaping (_ id: String) -> Void
	) {
		NSLog("PluginRTCPeerConnection#init()")

		self.rtcPeerConnectionFactory = rtcPeerConnectionFactory
		self.pluginRTCPeerConnectionConfig = PluginRTCPeerConnectionConfig(pcConfig: pcConfig)
		self.pluginRTCPeerConnectionConstraints = PluginRTCPeerConnectionConstraints(pcConstraints: pcConstraints)
		self.eventListener = eventListener
		self.eventListenerForAddStream = eventListenerForAddStream
		self.eventListenerForRemoveStream = eventListenerForRemoveStream
	}

	
	deinit {
		NSLog("PluginRTCPeerConnection#deinit()")
		self.pluginRTCDTMFSenders = [:]
	}


	func run() {
		NSLog("PluginRTCPeerConnection#run()")

		self.rtcPeerConnection = self.rtcPeerConnectionFactory.peerConnection(
			with: self.pluginRTCPeerConnectionConfig.getConfiguration(),
			constraints: self.pluginRTCPeerConnectionConstraints.getConstraints(),
			delegate: self
		)
	}


	func createOffer(
		_ options: NSDictionary?,
		callback: @escaping (_ data: NSDictionary) -> Void,
		errback: @escaping (_ error: Error) -> Void
	) {
		NSLog("PluginRTCPeerConnection#createOffer()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCPeerConnectionConstraints = PluginRTCPeerConnectionConstraints(pcConstraints: options)

		self.onCreateLocalDescriptionSuccessCallback = { (rtcSessionDescription: RTCSessionDescription) -> Void in
			NSLog("PluginRTCPeerConnection#createOffer() | success callback")

			let data = [
				"type": RTCSessionDescription.string(for: rtcSessionDescription.type),
				"sdp": rtcSessionDescription.sdp
			] as [String : Any]

			callback(data as NSDictionary)
		}
		
		self.onCreateLocalDescriptionFailureCallback = { (error: Error) -> Void in
			NSLog("PluginRTCPeerConnection#createOffer() | failure callback: %@", String(describing: error))
			
			errback(error)
		}

		self.rtcPeerConnection.offer(for: pluginRTCPeerConnectionConstraints.getConstraints(), completionHandler: {
			(sdp: RTCSessionDescription?, error: Error?) in
			if (error == nil) {
				self.onCreateLocalDescriptionSuccessCallback(sdp!);
			}else {
				self.onCreateLocalDescriptionFailureCallback(error!);
			}
		})
	}


	func createAnswer(
		_ options: NSDictionary?,
		callback: @escaping (_ data: NSDictionary) -> Void,
		errback: @escaping (_ error: Error) -> Void
	) {
		NSLog("PluginRTCPeerConnection#createAnswer()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCPeerConnectionConstraints = PluginRTCPeerConnectionConstraints(pcConstraints: options)

		self.onCreateRemoteDescriptionSuccessCallback = { (rtcSessionDescription: RTCSessionDescription) -> Void in
			NSLog("PluginRTCPeerConnection#createAnswer() | success callback")

			let data = [
				"type": RTCSessionDescription.string(for: rtcSessionDescription.type),
				"sdp": rtcSessionDescription.sdp
			] as [String : Any]

			callback(data as NSDictionary)
		}

		self.onCreateRemoteDescriptionFailureCallback = { (error: Error) -> Void in
			NSLog("PluginRTCPeerConnection#createAnswer() | failure callback: %@", String(describing: error))

			errback(error)
		}

		self.rtcPeerConnection.answer(for: pluginRTCPeerConnectionConstraints.getConstraints(), completionHandler: {
			(sdp: RTCSessionDescription?, error: Error?) in
			if (error == nil) {
				self.onCreateRemoteDescriptionSuccessCallback(sdp!)
			}else {
				self.onCreateRemoteDescriptionFailureCallback(error!)
			}
		})
	}


	func setLocalDescription(
		_ desc: NSDictionary,
		callback: @escaping (_ data: NSDictionary) -> Void,
		errback: @escaping (_ error: Error) -> Void
	) {
		NSLog("PluginRTCPeerConnection#setLocalDescription()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let type = desc.object(forKey: "type") as? String ?? ""
		let sdp = desc.object(forKey: "sdp") as? String ?? ""
		let sdpType = RTCSessionDescription.type(for: type)
		let rtcSessionDescription = RTCSessionDescription(type: sdpType, sdp: sdp)

		self.onSetDescriptionSuccessCallback = { [unowned self] () -> Void in
			NSLog("PluginRTCPeerConnection#setLocalDescription() | success callback")
			let data = [
				"type": RTCSessionDescription.string(for: self.rtcPeerConnection.localDescription!.type),
				"sdp": self.rtcPeerConnection.localDescription!.sdp
			] as [String : Any]

			callback(data as NSDictionary)
		}

		self.onSetDescriptionFailureCallback = { (error: Error) -> Void in
			NSLog("PluginRTCPeerConnection#setLocalDescription() | failure callback: %@", String(describing: error))

			errback(error)
		}

		self.rtcPeerConnection.setLocalDescription(rtcSessionDescription, completionHandler: {
			(error: Error?) in
			if (error == nil) {
				self.onSetDescriptionSuccessCallback();
			}else {
				self.onSetDescriptionFailureCallback(error!);
			}
		})
	}


	func setRemoteDescription(
		_ desc: NSDictionary,
		callback: @escaping (_ data: NSDictionary) -> Void,
		errback: @escaping (_ error: Error) -> Void
	) {
		NSLog("PluginRTCPeerConnection#setRemoteDescription()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let type = desc.object(forKey: "type") as? String ?? ""
		let sdp = desc.object(forKey: "sdp") as? String ?? ""
		let sdpType = RTCSessionDescription.type(for: type)
		let rtcSessionDescription = RTCSessionDescription(type: sdpType, sdp: sdp)

		self.onSetDescriptionSuccessCallback = { [unowned self] () -> Void in
			NSLog("PluginRTCPeerConnection#setRemoteDescription() | success callback")

			let data = [
				"type": RTCSessionDescription.string(for: self.rtcPeerConnection.remoteDescription!.type),
				"sdp": self.rtcPeerConnection.remoteDescription!.sdp
			]

			callback(data as NSDictionary)
		}

		self.onSetDescriptionFailureCallback = { (error: Error) -> Void in
			NSLog("PluginRTCPeerConnection#setRemoteDescription() | failure callback: %@", String(describing: error))

			errback(error)
		}

		self.rtcPeerConnection.setRemoteDescription(rtcSessionDescription, completionHandler: {
			(error: Error?) in
			if (error == nil) {
				self.onSetDescriptionSuccessCallback();
			}else {
				self.onSetDescriptionFailureCallback(error!);
			}
		})
	}


	func addIceCandidate(
		_ candidate: NSDictionary,
		callback: (_ data: NSDictionary) -> Void,
		errback: () -> Void
	) {
		NSLog("PluginRTCPeerConnection#addIceCandidate()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let sdpMid = candidate.object(forKey: "sdpMid") as? String ?? ""
		let sdpMLineIndex = candidate.object(forKey: "sdpMLineIndex") as? Int32 ?? 0
		let candidate = candidate.object(forKey: "candidate") as? String ?? ""

		let result = true
		self.rtcPeerConnection!.add(RTCIceCandidate(
			sdp: candidate,
			sdpMLineIndex: sdpMLineIndex,
			sdpMid: sdpMid
		))

		var data: NSDictionary

		if result == true {
			if self.rtcPeerConnection.remoteDescription != nil {
				data = [
					"remoteDescription": [
						"type": RTCSessionDescription.string(for: self.rtcPeerConnection.remoteDescription!.type),
						"sdp": self.rtcPeerConnection.remoteDescription!.sdp
					]
				]
			} else {
				data = [
					"remoteDescription": false
				]
			}

			callback(data)
		} else {
			errback()
		}
	}


	func addStream(_ pluginMediaStream: PluginMediaStream) -> Bool {
		NSLog("PluginRTCPeerConnection#addStream()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return false
		}

		self.rtcPeerConnection.add(pluginMediaStream.rtcMediaStream)
		return true
	}


	func removeStream(_ pluginMediaStream: PluginMediaStream) {
		NSLog("PluginRTCPeerConnection#removeStream()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		self.rtcPeerConnection.remove(pluginMediaStream.rtcMediaStream)
	}


	func createDataChannel(
		_ dcId: Int,
		label: String,
		options: NSDictionary?,
		eventListener: @escaping (_ data: NSDictionary) -> Void,
		eventListenerForBinaryMessage: @escaping (_ data: Data) -> Void
	) {
		NSLog("PluginRTCPeerConnection#createDataChannel()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDataChannel = PluginRTCDataChannel(
			rtcPeerConnection: rtcPeerConnection,
			label: label,
			options: options,
			eventListener: eventListener,
			eventListenerForBinaryMessage: eventListenerForBinaryMessage
		)

		// Store the pluginRTCDataChannel into the dictionary.
		self.pluginRTCDataChannels[dcId] = pluginRTCDataChannel

		// Run it.
		pluginRTCDataChannel.run()
	}


	func RTCDataChannel_setListener(
		_ dcId: Int,
		eventListener: @escaping (_ data: NSDictionary) -> Void,
		eventListenerForBinaryMessage: @escaping (_ data: Data) -> Void
	) {
		NSLog("PluginRTCPeerConnection#RTCDataChannel_setListener()")

		let pluginRTCDataChannel = self.pluginRTCDataChannels[dcId]

		if pluginRTCDataChannel == nil {
			return;
		}

		// Set the eventListener.
		pluginRTCDataChannel!.setListener(eventListener,
			eventListenerForBinaryMessage: eventListenerForBinaryMessage
		)
	}


	func createDTMFSender(
		_ dsId: Int,
		track: PluginMediaStreamTrack,
		eventListener: @escaping (_ data: NSDictionary) -> Void
	) {
		NSLog("PluginRTCPeerConnection#createDTMFSender()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDTMFSender = PluginRTCDTMFSender(
			rtcPeerConnection: self.rtcPeerConnection,
			track: track.rtcMediaStreamTrack,
			streamId: String(dsId), //TODO
			eventListener: eventListener
		)

		// Store the pluginRTCDTMFSender into the dictionary.
		self.pluginRTCDTMFSenders[dsId] = pluginRTCDTMFSender

		// Run it.
		pluginRTCDTMFSender.run()
	}

	func getStats(
		_ pluginMediaStreamTrack: PluginMediaStreamTrack?,
		callback: @escaping (_ data: NSArray) -> Void,
		errback: (_ error: NSError) -> Void
	) {
		NSLog("PluginRTCPeerConnection#getStats()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		self.onGetStatsCallback = { (array: NSArray) -> Void in
			callback(array)
		}

		self.rtcPeerConnection.stats(for: pluginMediaStreamTrack?.rtcMediaStreamTrack, statsOutputLevel: RTCStatsOutputLevel.standard, completionHandler:  {
			(reports: [RTCLegacyStatsReport]) in
			self.onGetStatsCallback(reports as NSArray)
		})
    }

	func close() {
		NSLog("PluginRTCPeerConnection#close()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		self.rtcPeerConnection.close()
	}


	func RTCDataChannel_sendString(
		_ dcId: Int,
		data: String,
		callback: (_ data: NSDictionary) -> Void
	) {
		NSLog("PluginRTCPeerConnection#RTCDataChannel_sendString()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDataChannel = self.pluginRTCDataChannels[dcId]

		if pluginRTCDataChannel == nil {
			return;
		}

		pluginRTCDataChannel!.sendString(data, callback: callback)
	}


	func RTCDataChannel_sendBinary(
		_ dcId: Int,
		data: Data,
		callback: (_ data: NSDictionary) -> Void
	) {
		NSLog("PluginRTCPeerConnection#RTCDataChannel_sendBinary()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDataChannel = self.pluginRTCDataChannels[dcId]

		if pluginRTCDataChannel == nil {
			return;
		}

		pluginRTCDataChannel!.sendBinary(data, callback: callback)
	}


	func RTCDataChannel_close(_ dcId: Int) {
		NSLog("PluginRTCPeerConnection#RTCDataChannel_close()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDataChannel = self.pluginRTCDataChannels[dcId]

		if pluginRTCDataChannel == nil {
			return;
		}

		pluginRTCDataChannel!.close()

		// Remove the pluginRTCDataChannel from the dictionary.
		self.pluginRTCDataChannels[dcId] = nil
	}


	func RTCDTMFSender_insertDTMF(
		_ dsId: Int,
		tones: String,
		duration: Double,
		interToneGap: Double
	) {
		NSLog("PluginRTCPeerConnection#RTCDTMFSender_insertDTMF()")

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		let pluginRTCDTMFSender = self.pluginRTCDTMFSenders[dsId]
		if pluginRTCDTMFSender == nil {
			return
		}

		pluginRTCDTMFSender!.insertDTMF(tones, duration: duration as TimeInterval, interToneGap: interToneGap as TimeInterval)
	}


	/**
	 * Methods inherited from RTCPeerConnectionDelegate.
	 */


	func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
		let state_str = PluginRTCTypes.signalingStates[stateChanged.rawValue]

		NSLog("PluginRTCPeerConnection | onsignalingstatechange [signalingState:%@]", String(describing: state_str))

		self.eventListener([
			"type": "signalingstatechange",
			"signalingState": state_str as Any
		])
	}

	func peerConnection(_ rtcPeerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
		NSLog("PluginRTCPeerConnection | onaddstream")
		
		let pluginMediaStream = PluginMediaStream(rtcMediaStream: stream)
		
		pluginMediaStream.run()
		
		// Let the plugin store it in its dictionary.
		self.eventListenerForAddStream(pluginMediaStream)
		
		// Fire the 'addstream' event so the JS will create a new MediaStream.
		self.eventListener([
			"type": "addstream",
			"stream": pluginMediaStream.getJSON()
			])
	}
	
	
	func peerConnection(_ rtcPeerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
		NSLog("PluginRTCPeerConnection | onremovestream")
		
		// Let the plugin remove it from its dictionary.
		self.eventListenerForRemoveStream(stream.streamId)
		
		self.eventListener([
			"type": "removestream",
			"streamId": stream.streamId
			])
	}

	func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
		NSLog("PluginRTCPeerConnection | onnegotiationeeded")
		
		self.eventListener([
			"type": "negotiationneeded"
		])
	}

	func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
		let state_str = PluginRTCTypes.iceConnectionStates[newState.rawValue]
		
		NSLog("PluginRTCPeerConnection | oniceconnectionstatechange [iceConnectionState:%@]", String(describing: state_str))
		
		self.eventListener([
			"type": "iceconnectionstatechange",
			"iceConnectionState": state_str as Any
			])
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
		let state_str = PluginRTCTypes.iceGatheringStates[newState.rawValue]

		NSLog("PluginRTCPeerConnection | onicegatheringstatechange [iceGatheringState:%@]", String(describing: state_str))

		self.eventListener([
			"type": "icegatheringstatechange",
			"iceGatheringState": state_str as Any
		])

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		// Emit an empty candidate if iceGatheringState is "complete".
		if newState.rawValue == RTCIceGatheringState.complete.rawValue && self.rtcPeerConnection.localDescription != nil {
			self.eventListener([
				"type": "icecandidate",
				// NOTE: Cannot set null as value.
				"candidate": false,
				"localDescription": [
					"type": RTCSessionDescription.string(for: self.rtcPeerConnection.localDescription!.type),
					"sdp": self.rtcPeerConnection.localDescription!.sdp
				] as [String : Any]
			])
		}
	}

	func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
		NSLog("PluginRTCPeerConnection | onicecandidate [sdpMid:%@, sdpMLineIndex:%@, candidate:%@]",
			  String(candidate.sdpMid!), String(candidate.sdpMLineIndex), String(candidate.sdp))

		if self.rtcPeerConnection.signalingState == RTCSignalingState.closed {
			return
		}

		self.eventListener([
			"type": "icecandidate",
			"candidate": [
				"sdpMid": candidate.sdpMid as Any,
				"sdpMLineIndex": candidate.sdpMLineIndex,
				"candidate": candidate.sdp
			],
			"localDescription": [
				"type": RTCSessionDescription.string(for: self.rtcPeerConnection.localDescription!.type),
				"sdp": self.rtcPeerConnection.localDescription!.sdp
			] as [String : Any]
		])
	}

	func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
		NSLog("PluginRTCPeerConnection | removeicecandidates")
	}

	func peerConnection(_ peerConnection: RTCPeerConnection, didOpen rtcDataChannel: RTCDataChannel) {
		NSLog("PluginRTCPeerConnection | ondatachannel")

		let dcId = PluginUtils.randomInt(10000, max:99999)
		let pluginRTCDataChannel = PluginRTCDataChannel(
			rtcDataChannel: rtcDataChannel
		)

		// Store the pluginRTCDataChannel into the dictionary.
		self.pluginRTCDataChannels[dcId] = pluginRTCDataChannel

		// Run it.
		pluginRTCDataChannel.run()

		// Fire the 'datachannel' event so the JS will create a new RTCDataChannel.
		self.eventListener([
			"type": "datachannel",
			"channel": [
				"dcId": dcId,
				"label": rtcDataChannel.label,
				"ordered": rtcDataChannel.isOrdered,
				"maxPacketLifeTime": rtcDataChannel.maxPacketLifeTime,
				"maxRetransmits": rtcDataChannel.maxRetransmits,
				"protocol": rtcDataChannel.`protocol`,
				"negotiated": rtcDataChannel.isNegotiated,
				"id": rtcDataChannel.channelId,
				"readyState": PluginRTCTypes.dataChannelStates[rtcDataChannel.readyState.rawValue] as Any,
				"bufferedAmount": rtcDataChannel.bufferedAmount
			] as [String : Any]
		])
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection,
						didAdd rtpReceiver: RTCRtpReceiver,
						streams:[RTCMediaStream]) {
		NSLog("PluginRTCPeerConnection | onaddtrack")
		
		let track = PluginMediaStreamTrack(rtcMediaStreamTrack: rtpReceiver.track!)
		
		self.eventListener([
			"type": "addtrack",
			"track": track.getJSON()
		])
	}
	
}
