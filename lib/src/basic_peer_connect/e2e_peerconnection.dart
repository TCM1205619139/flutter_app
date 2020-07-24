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
  Map<String, String> info = {
    "name": "Sweet",
    "age": "22",
    "country": "china"
  };
  RTCVideoRenderer _localRender = RTCVideoRenderer();
  var _remoteRenders = new Map<String, RTCVideoRenderer>();
  var _peerConnections = new Map<String, RTCPeerConnection>();
  Map<String, dynamic> test = {
    "name": "Sweet",
    "age": "51"
  };
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
//    _remoteRenders = ;
  }
  @override
  void dispose() {
    super.dispose();
    print("================connect close====================");
    this._hangUp();
    channel.sink.close();
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
        var render = RTCVideoRenderer();
        render.initialize();
        _peerConnection.onRemoveStream = (stream) {
          print("====================${data["sponsor"]}============================");
          setState(() {
            _remoteRenders[data["sponsor"]].srcObject = null;
            _remoteRenders[data["sponsor"]] = null;
          });
        };
        _peerConnection.onAddStream = (stream) {
          setState(() {
            test[data["sponsor"]] = render.toString();
            render.srcObject = stream;
            _remoteRenders[data["sponsor"]] = render;
          });
        };

        _peerConnection.addStream(_localStream);
        _peerConnection.setRemoteDescription(sdp);
        _peerConnection.createAnswer(answerSdpConstraints).then((answer) {
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
    Timer(Duration(seconds: 3), () async {
      await _peerConnections[data["sponsor"]].addCandidate(candidate);
    });
  }
  void _getClientsNumber(dynamic data) async {
    if(!_joined) { /* 当前客户端加入房间 */
      _selfId = data["owner"];
      _joined = true;
      if(data["clientsNumber"] <= 1) {
        return;
      } else {  /* 有多个在线客户端时与每个客户端建立peerConnection连接， 发送offer */
        await data["data"].forEach((key, value) {
          if(value != _selfId) {
            createPeerAndOffer(key, value, data).then((_peerConnection) {
              _peerConnections[key] = _peerConnection;
            });
          }
        });
      }
    } else {
      /* 不是当前客户端加入房间，而是收到其他客户端加入房间的消息
      * 1. 判断收到的客户端数量与本地的比较，进行相应的增加peer或者删除
      * */
      if(_peerConnections.length > data["clientsNumber"] - 1) {
        // 删除peerConnection
        _peerConnections.forEach((key, value) {
          if(!data["data"].containsKey(key)) {
            _peerConnections.remove(key);
          }
        });
      }
    }
  }

  Future createPeerAndOffer(String key, String value,dynamic data) async {
    var _peerConnection = await createPeerConnection(configuration, loopbackConstraints);
    var render = RTCVideoRenderer();
    render.initialize();
    _peerConnection.onRemoveStream = (stream) {
      setState(() {
        _remoteRenders[data["sponsor"]].srcObject = null;
        _remoteRenders[data["sponsor"]] = null;
      });
    };
    _peerConnection.onAddStream = (stream) {
      render.srcObject = stream;
      _remoteRenders[data["sponsor"]] = render;
      test["country1"] = "china1";
      print("+++++++++++${_remoteRenders.keys}++ ${_remoteRenders.values}+++++++++++++++");
    };
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

  List<Widget> _buildRemoteRenders() {
    List<Widget> listWidget = [];
    print("+++++++++++++++++++++++++ ${_remoteRenders.length} +++${_remoteRenders.values}+++++++++++++++++++++++++++");
    _remoteRenders.forEach((key, value) {
      listWidget.add(Expanded(flex: 1, child: RTCVideoView(value)));
    });
//    this.test.forEach((key, value) {
//      listWidget.add(Text("$key: $value"));
//    });
    print("add VideoView end");

    return listWidget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("多对多通信")),
      body: Column(
        children: <Widget>[
          Expanded(flex: 1, child: Scaffold(
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
          )),
          Expanded(
            flex: 1,
            child: Column(
              children: _buildRemoteRenders(),
            )
          ),
        ],
      ),
    );
  }
}