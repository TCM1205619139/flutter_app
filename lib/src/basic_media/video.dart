import 'dart:core';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MyVideo extends StatefulWidget {
  @override
  MyVideoState createState() {
    return new MyVideoState();
  }
}

class MyVideoState extends State<MyVideo> {
  VideoPlayerController _controller;
  bool _isPlaying = true;
  String _videoUrl = 'https://www.runoob.com/try/demo_source/mov_bbb.mp4';
  IconData _playingIcon = Icons.play_arrow;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(_videoUrl)
    ..addListener(() {
      final bool isPlaying = _controller.value.isPlaying;
      if(isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    })
    ..initialize().then((_) {
      setState(() {});
    });
    _controller.setLooping(true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: _controller.value.initialized
              ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
              : Container(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
            setState(() {
              _playingIcon = (_controller.value.isPlaying ? Icons.pause : Icons.play_arrow);
            });
          },
          child: Icon(_playingIcon),
        ),
      ),
    );
  }
}
