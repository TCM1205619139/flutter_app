## 基于webRtc的flutter应用（二）------客户端篇

#### 一、flutter客户端的搭建

基本的flutter、dart、java、SDK和AS的下载与配置就不做赘述，直入主题

1. 需要安装的依赖------pubspec.yaml文件

   ```yaml
   dependencies:
     flutter:
       sdk: flutter
   
     english_words: ^3.1.0
     video_player: ^0.10.0
     flutter_gallery_assets: 0.1.6
     connectivity: 0.3.2
     flutter_webrtc: ^0.2.0
     web_socket_channel: ^1.1.0
   
     shared_preferences:
     shared_preferences_macos:
     shared_preferences_web:
     http: ^0.12.0+4
     
     cupertino_icons: ^0.1.3
   
   dev_dependencies:
     flutter_test:
       sdk: flutter
   
   ```

2. 需要显示本地与对端的音视频肯定是需要创建有状态的Widget类

   ```dart
   class Room extends StatefulWidget {
     @override
     State<Room> createState() {
       return RoomState();
     }
   }
   ```

3. 创建Room的状态子类，并重写build方法、initState和dispose方法

   ```dart
   class RoomState extends State<Room> {
     var channel;	// 
     RTCVideoRenderer _localRender = RTCVideoRenderer();
     RTCVideoRenderer _remoteRender = RTCVideoRenderer();
     Map<String, RTCPeerConnection> _peerConnections = {};
     String _selfId;
     MediaStream _localStream;
     bool _isCalling = false;
     bool _joined = false;
       
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
                   onPressed: () {	// 这里我使用三元表达式莫名其妙地就是不行，唉
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
   ```
   
4. 在build中的onpress方法中通过_isCalling的状态执行__makeCall和 _hangUp方法

   ```dart
   void _makeCall() async {
       try {
           // 与服务器建立socket连接，并监听socket信息监听，最后改变_isCalling，重新渲染画面
           channel = IOWebSocketChannel.connect(MyApp.websocketUrl);
           navigator.getUserMedia(mediaConstraints).then((stream) {
               _localStream = stream;
               _localRender.srcObject = _localStream;
           });
   
           channel.stream.listen((message) {	// 监听连接的消息
               var data = json.decode(message);
               // 接收信息的状态机
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
   ```

5. 收到监听信息时判断数据头title，通过状态机执行不同的方法，通过服务器的代码可以看到客户端建立连接之后，收到的最开始的信息肯定是当前服务器的建立连接的数量（客户端数量）。_joined为是否已经加入服务器的标志位，收到clientsNumber分为几种情况：

   * 是当前客户端加入服务器：需要获取自己在服务器中的ID，改变_joined状态，如果服务器只有一个当前这个客户端（当前客户端为第一个加入服务器的客户端）：直接返回不做任何事情；如果当前客户端加入服务器时已经有其他客户端存在，就需要通过获取到服务器中的已存在客户端信息给每个客户端（除自己外）建立peerconnection连接并且发送offer、并且setLocalDescription，给每条peerconnection添加一系列的事件监听，并将建立好的的peer添加到 _peerConnections中进行统一管理。

   * 当前客户端收到其他客户端加入的信息，有两种情况：

      * 收到其他客户端新加入的消息：
        等待新加入的客户端发送offer，再建立peer，这里统一用状态机进行管理，再这里不需要处理。

      * 收到其他客户端退出的消息：
        通过传输过来的clients的key与 _peerConnections进行比较，删除不存在的peer

   ```dart
   void _getClientsNumber(dynamic data) async {
       if(!_joined) { /* 当前客户端加入房间 */
           _selfId = data["owner"];
           _joined = true;
           if(data["clientsNumber"] <= 1) {
               return;
           } else {  /* 有多个在线客户端时与每个客户端建立peerConnection连接， 发送offer */
               await data["data"].forEach((key, value) {
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
   ```

6. 收到的title是sdp类型的数据，状态机通过 _getSDP方法进行处理。这里也有两种情况

   * 收到的SDP为offer类型

     * 如果收到了offer类型的sdp，说明是其他客户端加入了服务器，这时还没有建立与之相对应的peer，就通过传输过来的"sponsor"属性获取到对端的id，建立一条新的peer，完毕之后再通过对端的id发送answe数据，并且setLocal，再setRemote
   
   * 收到的SDP为answer类型，说明是当前客户端发送的offer，收到的回应的answe，在 _peerConnections中已经有了对应的peer，就只需要在 _peerConnections中找到这条peer再setRemote。
   
     **这里有个比较坑的东西：虽然 SDP（offer或者answer）会在发送candidate之前进行发送，candidate需要添加在对应的 peer上，但是有可能会出现 peer还未创建好就已经收到 candidate的情况，candidate就无法添加上去而报错，这里我用的比较偷懒的方法处理的（自己猜）**
   
   ```dart
   void _getSDP(dynamic data) async {
       switch(data["data"]["type"]) {
           case "offer":
           /*
           1. 收到offer，与发送offer方建立连接
           2. 设置localSdp与remoteSdp
           3. 将创建的peer加入本地管理
           */
               var sdp = RTCSessionDescription(data["data"]["sdp"], data["data"]["type"]);
               // 一定要使用RTCSessionDescription方法进行构造sdp
               var _peerConnection = await createPeerConnection(configuration, loopbackConstraints);
               _peerConnection.onRemoveStream = _onRemoveStream;
               _peerConnection.onAddStream = _onAddStream;
   
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
               var sdp = RTCSessionDescription(data["data"]["sdp"], data["data"]["type"]);
               _peerConnections[data["sponsor"]].setRemoteDescription(sdp);
               break;
       }
   }
   ```
   
7. 最后是处理收到title为candidate类型的数据，就只需要进行找到对应的peer进行添加上去就好了

   ```dart
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
   
   // 还有就是要定义onAddStream与onRemoteStream方法
   void _onRemoveStream(MediaStream stream) {
       _remoteRender.srcObject = null;
   }
   void _onAddStream(MediaStream stream) {
       _remoteRender.srcObject = stream;
   }
   ```

   

