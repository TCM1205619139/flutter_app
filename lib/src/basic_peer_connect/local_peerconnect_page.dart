import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/enums.dart';
import 'package:flutter_webrtc/get_user_media.dart';
import 'package:flutter_webrtc/media_stream.dart';
import 'package:flutter_webrtc/rtc_ice_candidate.dart';
import 'package:flutter_webrtc/rtc_peerconnection.dart';
import 'package:flutter_webrtc/rtc_peerconnection_factory.dart';
import 'package:flutter_webrtc/rtc_session_description.dart';
import 'package:flutter_webrtc/rtc_video_view.dart';

class PeerConnectSample extends StatefulWidget {
  @override
  State<PeerConnectSample> createState() {
    return _PeerConnectSampleState();
  }
}

class _PeerConnectSampleState extends State<PeerConnectSample> {
  RTCVideoRenderer _localRender = RTCVideoRenderer();
  RTCVideoRenderer _remoteRender = RTCVideoRenderer();
  MediaStream _localStream;
  RTCPeerConnection _peerConnection;
  bool _isCall = false;
  Timer _timer;

  @override
  void initState() {
    super.initState();
    _localRender.initialize();
    _remoteRender.initialize();
  }

  @override
  void deactivate() {
    super.deactivate();
    _hangUp();
  }

  void _makeCall() async {
    const Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth": "480",
//          "minHeight": "400",
          "minFrameRate": "30"
        },
        "facingMode": 'user',
        "optional": []
      }};
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };
    const Map<String, dynamic> offer_sdp_constraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true
      },
      "optional": []
    };

    const Map<String, dynamic> loopback_constraints = {
      "mandatory": {},
      "optional": [
        {"DtlsSrtpKeyAgreement": false},
      ],
    };

    if(_peerConnection != null) return;

    try {
      _localStream = null;
      _localStream = await navigator.getUserMedia(mediaConstraints);
      _localRender.srcObject = _localStream;

      _peerConnection = await createPeerConnection(configuration, loopback_constraints);

      _peerConnection.onSignalingState = _onSignalingState;
      _peerConnection.onIceGatheringState = _onIceGatheringState;
      _peerConnection.onIceConnectionState = _onIceConnectionState;
      _peerConnection.onAddStream = _onAddStream;
      _peerConnection.onRemoveStream = _onRemoveStream;
      _peerConnection.onIceCandidate = _onIceCandidate;

      _peerConnection.addStream(_localStream);
      RTCSessionDescription offer = await _peerConnection.createOffer(offer_sdp_constraints);
      _peerConnection.setLocalDescription(offer);
      offer.type = "answer";
      _peerConnection.setRemoteDescription(offer);

    } catch(e) {
      throw e.toString();
    }

    if(!mounted) return;

//    _timer = Timer.periodic(Duration(seconds: 1), handleStatsReport);
    setState(() {
      _isCall = true;
    });
  }

  void _hangUp () async {
    try {
      await _localStream.dispose();
      await _peerConnection.close();
//      _localRender.srcObject = null;
//      _remoteRender.srcObject = null;

    } catch(e) {
      print(e.toString());
    }
    setState(() {
      _isCall = false;
    });
  }

  void _onSignalingState(RTCSignalingState state) => print(state);
  void _onIceGatheringState(RTCIceGatheringState state) => print(state);
  void _onIceConnectionState(RTCIceConnectionState state) => print(state);
  void _onAddStream(MediaStream stream) {
    print('addStream' + stream.id);
    _remoteRender.srcObject = stream;
  }
  void _onRemoveStream(MediaStream stream) {
    print('remove stream');
    _remoteRender.srcObject = null;
  }
  void _onIceCandidate(RTCIceCandidate candidate) {
    print('onCandidate: ' + candidate.candidate);
    _peerConnection.addCandidate(candidate);
  }
  void handleStatsReport(Timer timer) async {
    if (_peerConnection != null) {
      var reports = await _peerConnection.getStats();
      reports.forEach((report) {
        print("report => { ");
        print("    id: " + report.id + ",");
        print("    type: " + report.type + ",");
        print("    timestamp: ${report.timestamp},");
        print("    values => {");
        report.values.forEach((key, value) {
          print("        " + key + " : " + value + ", ");
        });
        print("    }");
        print("}");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: Scaffold(
              body: RTCVideoView(_localRender),
              floatingActionButton: FloatingActionButton(
                onPressed: _isCall ? _hangUp : _makeCall,
                tooltip: _isCall ? "HangUp" : "Calling",
                child: _isCall ? Icon(Icons.pause) : Icon(Icons.phone),
              ),
            )
          ),
          Expanded(
            flex: 1,
            child: RTCVideoView(_remoteRender),
          )
        ],
      ),
    );
  }

}











//import 'package:flutter/material.dart';
//import 'package:flutter_webrtc/webrtc.dart';
//import 'dart:core';
//import 'dart:async';
//
//
//class PeerConnectSample extends StatefulWidget {
//
//  static String tag = 'loopback_sample';
//
//  @override
//  _MyAppState createState() => _MyAppState();
//}
//
//class _MyAppState extends State<PeerConnectSample> {
//  MediaStream _localStream;
//  RTCPeerConnection _peerConnection;
//  final _localRenderer = RTCVideoRenderer();
//  final _remoteRenderer = RTCVideoRenderer();
//  bool _inCalling = false;
//  Timer _timer;
//
//  @override
//  initState() {
//    super.initState();
//    initRenderers();
//  }
//
//  @override
//  deactivate() {
//    super.deactivate();
//    if (_inCalling) {
//      _hangUp();
//    }
//    _localRenderer.dispose();
//    _remoteRenderer.dispose();
//  }
//
//  initRenderers() async {
//    await _localRenderer.initialize();
//    await _remoteRenderer.initialize();
//  }
//
//  void handleStatsReport(Timer timer) async {
//    if (_peerConnection != null) {
//      List<StatsReport> reports = await _peerConnection.getStats();
//      reports.forEach((report) {
//        print("report => { ");
//        print("    id: " + report.id + ",");
//        print("    type: " + report.type + ",");
//        print("    timestamp: ${report.timestamp},");
//        print("    values => {");
//        report.values.forEach((key, value) {
//          print("        " + key + " : " + value + ", ");
//        });
//        print("    }");
//        print("}");
//      });
//    }
//  }
//
//  _onSignalingState(RTCSignalingState state) {
//    print(state);
//  }
//
//  _onIceGatheringState(RTCIceGatheringState state) {
//    print(state);
//  }
//
//  _onIceConnectionState(RTCIceConnectionState state) {
//    print(state);
//  }
//
//  _onAddStream(MediaStream stream) {
//    print('addStream: ' + stream.id);
//    _remoteRenderer.srcObject = stream;
//  }
//
//  _onRemoveStream(MediaStream stream) {
//    _remoteRenderer.srcObject = null;
//  }
//
//  _onCandidate(RTCIceCandidate candidate) {
//    print('onCandidate: ' + candidate.candidate);
//    _peerConnection.addCandidate(candidate);
//  }
//
//  _onRenegotiationNeeded() {
//    print('RenegotiationNeeded');
//  }
//
//  // Platform messages are asynchronous, so we initialize in an async method.
//  _makeCall() async {
//    final Map<String, dynamic> mediaConstraints = {
//      "audio": true,
//      "video": {
//        "mandatory": {
//          "minWidth": '400', // Provide your own width, height and frame rate here
//          "minFrameRate": '30',
//        },
//        "facingMode": "user",
//        "optional": [],
//      }
//    };
//
//    Map<String, dynamic> configuration = {
//      "iceServers": [
//        {"url": "stun:stun.l.google.com:19302"},
////        {"url": "http://localhost:3000"}
//      ]
//    };
//
//    final Map<String, dynamic> offer_sdp_constraints = {
//      "mandatory": {
//        "OfferToReceiveAudio": true,
//        "OfferToReceiveVideo": true,
//      },
//      "optional": [],
//    };
//
//    final Map<String, dynamic> loopback_constraints = {
//      "mandatory": {},
//      "optional": [
//        {"DtlsSrtpKeyAgreement": false},
//      ],
//    };
//
//    if (_peerConnection != null) return;
//
//    try {
//      _localStream = await navigator.getUserMedia(mediaConstraints);
//      _localRenderer.srcObject = _localStream;
//
//      _peerConnection = await createPeerConnection(configuration, loopback_constraints);
//
//      _peerConnection.onSignalingState = _onSignalingState;
//      _peerConnection.onIceGatheringState = _onIceGatheringState;
//      _peerConnection.onIceConnectionState = _onIceConnectionState;
//      _peerConnection.onAddStream = _onAddStream;
//      _peerConnection.onRemoveStream = _onRemoveStream;
//      _peerConnection.onIceCandidate = _onCandidate;
//      _peerConnection.onRenegotiationNeeded = _onRenegotiationNeeded;
//
//      _peerConnection.addStream(_localStream);
//      RTCSessionDescription description = await _peerConnection.createOffer(offer_sdp_constraints);
//      print(description.sdp);
//      _peerConnection.setLocalDescription(description);
//      //change for loopback.
//      description.type = 'answer';
//      _peerConnection.setRemoteDescription(description);
//
//      _localStream.getAudioTracks()[0].setMicrophoneMute(false);
//    } catch (e) {
//      print(e.toString());
//    }
//    if (!mounted) return;
//
//    _timer = new Timer.periodic(Duration(seconds: 1), handleStatsReport);
//
//    setState(() {
//      _inCalling = true;
//    });
//  }
//
//  _hangUp() async {
//    try {
//      await _localStream.dispose();
//      await _peerConnection.close();
//      _peerConnection = null;
//      _localRenderer.srcObject = null;
//      _remoteRenderer.srcObject = null;
//    } catch (e) {
//      print(e.toString());
//    }
//    setState(() {
//      _inCalling = false;
//    });
//  }
//
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//      body: OrientationBuilder(
//        builder: (context, orientation) {
//          return Center(
//            child: Container(
//              decoration: BoxDecoration(color: Colors.white),
//              child: Stack(
//                children: <Widget>[
//                  Align(
//                    alignment: orientation == Orientation.portrait
//                        ? const FractionalOffset(0.5, 0.1)
//                        : const FractionalOffset(0.0, 0.5),
//                    child: Container(
//                      margin: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
//                      width: 320.0,
//                      height: 240.0,
//                      child: RTCVideoView(_localRenderer),
//                      decoration: BoxDecoration(color: Colors.black54),
//                    ),
//                  ),
//                  Align(
//                    alignment: orientation == Orientation.portrait
//                        ? const FractionalOffset(0.5, 0.9)
//                        : const FractionalOffset(1.0, 0.5),
//                    child: Container(
//                      margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
//                      width: 320.0,
//                      height: 240.0,
//                      child: RTCVideoView(_remoteRenderer),
//                      decoration: BoxDecoration(color: Colors.black54),
//                    ),
//                  ),
//                ],
//              ),
//            ),
//          );
//        },
//      ),
//      floatingActionButton: FloatingActionButton(
//        onPressed: _inCalling ? _hangUp : _makeCall,
//        tooltip: _inCalling ? 'Hangup' : 'Call',
//        child: Icon(_inCalling ? Icons.call_end : Icons.phone),
//      ),
//    );
//
//  }
//}
