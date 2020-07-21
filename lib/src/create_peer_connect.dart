import 'package:flutter/material.dart';
import './basic_peer_connect/e2e_peerconnection.dart';

class MyPeerConnect extends StatefulWidget {
  @override
  State<MyPeerConnect> createState() {
    return _MyPeerConnectState();
  }
}

class _MyPeerConnectState extends State<MyPeerConnect> {
  static String tag = "测试本地信令服务器peerConnection连接";

  @override
  void initState() {
    super.initState();
    print('----------------------------connect start ---------------------------------');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Room()
    );
  }
}