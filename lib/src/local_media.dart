import 'package:flutter/material.dart';
import 'basic_media/video.dart' show MyVideo;
import 'basic_media/get_user_media_page.dart' show MediaVideoPlayer;

Widget redBox = new DecoratedBox(decoration: BoxDecoration(color: Colors.red));

class LocalMedia extends StatefulWidget {
  @override
  LocalMediaState createState() => new LocalMediaState();
}

class LocalMediaState extends State<LocalMedia> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: new AppBar(
        title: new Center(
          child: new Text("音视频通信"),
        ),
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Container(
//                  margin: EdgeInsets.all(2.0),
                  /*
                  * 这里显示聊天文本消息，应该生成一个ListView组件
                  * */
                  child: MediaVideoPlayer(),
                  constraints: BoxConstraints(),
                  decoration: BoxDecoration(
                    color: Colors.red
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  /*
                  * 这里显示聊天文本消息，应该生成一个ListView组件
                  * */
                  child: MediaVideoPlayer(),
                  constraints: BoxConstraints(),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  alignment: Alignment.center,
                  margin: EdgeInsets.all(2.0),
                  /*
                  * 这里放入一个文本输入框
                  * */
                  constraints: BoxConstraints(),
                  child: Text('asdsad'),
                  decoration: BoxDecoration(
                    color: Colors.yellow
                  ),
                ),
              )
            ],
          ),
          ),
        ),
      );
  }
}
