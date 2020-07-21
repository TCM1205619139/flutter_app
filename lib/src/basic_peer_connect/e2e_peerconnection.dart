import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import '../utils/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_webrtc/enums.dart';
import 'package:flutter_webrtc/get_user_media.dart';
import 'package:flutter_webrtc/media_stream.dart';
import 'package:flutter_webrtc/rtc_ice_candidate.dart';
import 'package:flutter_webrtc/rtc_peerconnection.dart';
import 'package:flutter_webrtc/rtc_peerconnection_factory.dart';
import 'package:flutter_webrtc/rtc_session_description.dart';
import 'package:flutter_webrtc/rtc_video_view.dart';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Room extends StatefulWidget {
  @override
  State<Room> createState() {
    return RoomState();
  }
}

class RoomState extends State<Room> {
  var channel;
  RTCVideoRenderer _localRender = RTCVideoRenderer();
  RTCVideoRenderer _remoteRender = RTCVideoRenderer();
  Map<String, RTCPeerConnection> _peerConnections = {};
//  Map<String, dynamic> _clients;
  String _selfId;
  MediaStream _localStream;
  bool _isCalling = false;
  bool _joined = false;

  Map<String, dynamic> mediaConstraints = {
    "audio": true,
    "video": {
      "mandatory": {
        "minWidth": "480",
        "minFrameRate": 30
      },
      "facingMode": 'user',
      "optional": []
    }};
  Map<String, dynamic> configuration = {
    "iceServers": [
      {"url": "stun:stun.l.google.com:19302"},
    ]
  };
  Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true
    },
    "optional": []};

  Map<String, dynamic> answerSdpConstraints = {
    "mandatory": {
      "AnswerToReceiveAudio": true,
      "AnswerToReceiveVideo": true
    },
    "optional": []};

  Map<String, dynamic> loopbackConstraints = {
    "audio": true,
    "video": {
      "mandatory": {
        "minWidth": "480",
        "minFrameRate": 30
      },
      "optional": [
        {"DtlsSrtpKeyAgreement": true},
      ],
    }
  };

  @override
  void initState() {
    super.initState();
    _localRender.initialize();
    _remoteRender.initialize();
  }
  @override
  void dispose() {
    super.dispose();
    print("================connect close====================");
    channel.sink.close();
  }

  void _onRemoveStream(MediaStream stream) {
    _remoteRender.srcObject = null;
  }
  void _onAddStream(MediaStream stream) {
    _remoteRender.srcObject = stream;
  }

  void _makeCall() async {
    try {
      channel = IOWebSocketChannel.connect(MyApp.websocketUrl);
      navigator.getUserMedia(mediaConstraints).then((stream) {
        _localStream = stream;
        _localRender.srcObject = _localStream;
      });

      channel.stream.listen((message) {
        var data = json.decode(message);
        print("=================get message: type is ${data["title"]}======================");
        switch(data["title"]) {
          case "sessionDescription":
            _getSDP(data);
            break;
          case "candidate":
            _getCandidate(data);
            break;
          case "clientsNumber":
            _getClientsNumber(data);
            break;
          default:
            _getOther(data);
        }
      });

    } catch (e) {
      print(e.toString());
    }
    if(!mounted) {
      return;
    }

    setState(() {
      _isCalling = true;
    });
  }

  void _hangUp() async {
    try {
      await channel.sink.close();
      await _localStream.dispose();
      _peerConnections.forEach((key, value) {
        _peerConnections[key].close();
      });
    } catch(e) {
      print(e.toString());
    }
    setState(() {
      _isCalling = false;
    });
  }

  void _getSDP(dynamic data) async {
    switch(data["data"]["type"]) {
      case "offer":
        /*
        1. 收到offer，与发送offer方建立连接
        2. 设置localSdp与remoteSdp
        3. 将创建的peer加入本地管理
        */
        print("=============================get Offer==================================");
        var sdp = RTCSessionDescription(data["data"]["sdp"], data["data"]["type"]);
        var _peerConnection = await createPeerConnection(configuration, loopbackConstraints);
        print("============================= create peer =====================================");
        _peerConnection.onRemoveStream = _onRemoveStream;
        _peerConnection.onAddStream = _onAddStream;

        _peerConnection.addStream(_localStream);
        _peerConnection.setRemoteDescription(sdp);
        _peerConnection.createAnswer(answerSdpConstraints).then((answer) {
          print("===================================send answer===================================");
          _peerConnection.setLocalDescription(answer);
          channel.sink.add(json.encode({
            "title": "sessionDescription",
            "sponsor": _selfId,
            "receive": data["sponsor"],
            "data": answer.toMap()
          }));
        });
        print("=========================================send ICECandidate===========================================");
        _peerConnection.onIceCandidate = (candidate) {
          channel.sink.add(json.encode({
            "title": "candidate",
            "sponsor": _selfId,
            "receive": data["sponsor"],
            "data": candidate.toMap(),
          }));
        };
        _peerConnections[data["sponsor"]] = _peerConnection;
        break;
      case "answer":
        /* 通过answer的receive属性匹配clients的peer，设置remoteSDP */
        print("=============================get Answer==================================");
        var sdp = RTCSessionDescription(data["data"]["sdp"], data["data"]["type"]);
        _peerConnections[data["sponsor"]].setRemoteDescription(sdp);
        break;
    }
  }
  void _getCandidate(dynamic data) {
    /*
    * 1. 通过数据构造candidate
    * 2. 通过sponsor属性找到对应的peer，进行添加
    * */
    var candidate = RTCIceCandidate(data["data"]["candidate"], data["data"]["sdpMid"], data["data"]["sdpMLineIndex"]);
    print("========${_peerConnections.length}=============get candidate ${candidate.toMap()}==sponsor client is ${data["sponsor"]}==========receive is ${data["receive"]}=======self is $_selfId==================");
    Timer(Duration(seconds: 3), () async {
      await _peerConnections[data["sponsor"]].addCandidate(candidate);
    });
    print("================================peer is ${_peerConnections[data["sponsor"]]}=====================================");
  }
  void _getClientsNumber(dynamic data) async {
    print("=============get clientsNumber====data is: $data===peer length is: ${_peerConnections.length}=============");
    if(!_joined) { /* 当前客户端加入房间 */
      _selfId = data["owner"];
      _joined = true;
      if(data["clientsNumber"] <= 1) {
        return;
      } else {  /* 有多个在线客户端时与每个客户端建立peerConnection连接， 发送offer */
        await data["data"].forEach((key, value) {
          print("===================value: $value======_selfId: $_selfId============================");
          if(value != _selfId) {
            createPeerAndOffer(key, value).then((_peerConnection) {
              _peerConnections[key] = _peerConnection;
            });
          }
        });
      }
    } else {
      /* 不是当前客户端加入房间，而是收到其他客户端加入房间的消息
      * 1. 判断收到的客户端数量与本地的比较，进行相应的增加peer或者删除
      * */
      print("============${_peerConnections.length}======${data["clientsNumber"]}==========================");
      if(_peerConnections.length > data["clientsNumber"] - 1) {
        // 删除peerConnection
        _peerConnections.forEach((key, value) {
          if(!data["data"].containsKey(key)) {
            _peerConnections.remove(key);
          }
        });
      }
    }
    print("==================selfId is $_selfId=========================");
  }

  Future createPeerAndOffer(key, value) async {
    print("================create peer and offer to $key========================");
    var _peerConnection = await createPeerConnection(configuration, loopbackConstraints);
    _peerConnection.onRemoveStream = _onRemoveStream;
    _peerConnection.onAddStream = _onAddStream;
    _peerConnection.addStream(_localStream);
    _peerConnection.createOffer(offerSdpConstraints).then((offer) {
      _peerConnection.setLocalDescription(offer);
      channel.sink.add(json.encode({
        "title": "sessionDescription",
        "receive": key,
        "sponsor": _selfId,
        "data": offer.toMap()
      }));
    });
    _peerConnection.onIceCandidate = (candidate) {
      _peerConnections.forEach((key, value) {
        channel.sink.add(json.encode({
          "title": 'candidate',
          "sponsor": _selfId,
          "receive": key,
          "data": candidate.toMap()
        }));
      });
    };

    return _peerConnection;
  }
  void _getOther(dynamic data) {

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
                child: _isCalling ? Icon(Icons.pause) : Icon(Icons.phone),
                onPressed: () {
                  if(_isCalling) {
                    _hangUp();
                  } else {
                    _makeCall();
                  }
                },
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