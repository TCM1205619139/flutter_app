//import 'package:flutter/material.dart';
//import 'dart:math';
//import 'package:english_words/english_words.dart';
//
//class TipRoute extends StatelessWidget {
//  final String text;
//  final int id;
//
//  TipRoute({Key key, @required this.text, @required this.id}) : super(key: key);
//
//  @override
//  Widget build(BuildContext context) {
//    return new Scaffold(
//      appBar: new AppBar(title: new Text('提示')),
//      body: Padding(
//          padding: EdgeInsets.all(18.0),
//          child: Column(
//            children: <Widget>[
//              Text(text),
//              Text(id.toString()),
//              RaisedButton(
//                onPressed: () {
//                  Navigator.of(context).pop();
//                },
//                child: Text('返回'),
//              )
//            ],
//          )),
//    );
//  }
//}
//
//class RouterTestRoute extends StatelessWidget {
//  @override
//  Widget build(BuildContext context) {
//    return Scaffold(
//        appBar: AppBar(
//          title: new Text('初始化界面'),
//        ),
//        body: Center(
//          child: RaisedButton(
//            onPressed: () async {
//              await Navigator.of(context).push(new MaterialPageRoute(builder: (context) {
//                return TipRoute(text: '这是传入的参数', id: Random().nextInt(100000));
//              })).then((value) => print('await收到了参数'));
//              print('sync收到了参数');
//            },
//            child: Text('进入'),
//          ),
//        ));
//  }
//}
//
//class RandomWords extends StatefulWidget {
//  @override
//  RandomWordsState createState() => new RandomWordsState();
//}
//
//class RandomWordsState extends State<RandomWords> {
//  final _suggestions = <WordPair>[];
//  final _biggerFont = const TextStyle(fontSize: 18);
//  final _save = new Set<WordPair>();
//
//  @override
//  Widget build(BuildContext context) {

import 'package:flutter/material.dart';
import './src/local_media.dart';
import './src/utils/route_item.dart';
import './src/create_peer_connect.dart';

void main() {
  runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  static final String websocketUrl = 'ws://192.168.101.112:3000';

  @override
  _MyAppState createState() {
    return _MyAppState();
  }
}

class _MyAppState extends State<MyApp> {
  static String barTag = '音视频通信';
  List<RouteItem> items;

  @override
  void initState() {
    super.initState();
    _initItem();
    _initData();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(_MyAppState.barTag),
        ),
        body: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(0.0),
          itemCount: items.length,
          itemBuilder: (context, i) {
            return _buildRow(context, items[i]);
          })
//        body: MyPeerConnect(),
      ),
    );
  }

  _buildRow(context, item) {
    return ListBody(
      children: <Widget>[
        ListTile(
          title: Text(item.name),
          onTap: () => item.callback(context),
          trailing: Icon(Icons.arrow_right),
        ),
        Divider()
      ],
    );
  }

  _initItem() {
    items = <RouteItem>[
      RouteItem(
        name: "basic get_user_media stream",
        path: "getUserMedia",
        callback: (BuildContext context) {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return LocalMedia();
          }));
        }),
      RouteItem(
        name: 'p2p peerConnection test',
        path: 'peerConnection',
        callback: (BuildContext context) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) {
            return MyPeerConnect();
          }));
        }
      )
    ];
  }

  _initData() {

  }
}
