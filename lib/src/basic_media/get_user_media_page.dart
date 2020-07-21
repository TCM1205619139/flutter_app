import 'dart:core';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
/*
* Flutter WebRtc
* */
import 'package:flutter_webrtc/media_stream.dart';
import 'package:flutter_webrtc/utils.dart';
import 'package:flutter_webrtc/enums.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;

class MediaVideoPlayer extends StatefulWidget {
  static String tag = 'get_usermedia_sample';

  @override
  MediaVideoPlayerState createState() {
    return new MediaVideoPlayerState();
  }
}

class MediaVideoPlayerState extends State<MediaVideoPlayer> {
  MediaStream _localStream;
  var _localRender = RTCVideoRenderer();
  bool _isCalling = false;

  @override
  void initState() {
    super.initState();
    if(WebRTC.platformIsDesktop) {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    }
    initRenderers();
  }

  @override
  void deactivate() {
    super.deactivate();
    if(_isCalling) {
      _hangUp();
    }
    _localRender.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Center(
            child: Container(
//              margin: EdgeInsets.all(2.0),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: RTCVideoView(_localRender),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: _isCalling ? _hangUp : _makeCall,
          tooltip: _isCalling ? "HangUp" : "Call",
          child: Icon(_isCalling ? Icons.call_end : Icons.phone)
      ),
    );
  }

  void initRenderers() async {
    await _localRender.initialize();
  }

  void _makeCall() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth": 400,
          "minFrameRate": 30
        },
        "facingMode": "user",
        "optional": []
      }
    };

    try {
      navigator.getUserMedia(mediaConstraints).then((stream) {
        _localStream = stream;
        _localRender.srcObject = _localStream;
      });
    } catch(e) {
      throw e.toString();
    }
    if(!mounted) return;
    setState(() {
      _isCalling = true;
    });
  }

  void _hangUp() async {
    try {
      await _localStream.dispose();
      _localRender.srcObject = null;
    } catch(e) {
      throw e.toString();
    }
    setState(() {
      _isCalling = false;
    });
  }


}
