import 'package:flutter_webrtc/rtc_ice_candidate.dart';

class Mycandidate {
  Map<String, dynamic> container;
  String candidate;
  int hashCode;
  Type runtimeType;
  String sdpMid;
  int sdpMlineIndex;

  Mycandidate(candidate, hashCode, runtimeType, sdpMid, sdpMlineIndex) {
    container["candidate"] = candidate;
    container["hashCode"] = hashCode;
    container["runtimeType"] = runtimeType;
    container["sdpMid"] = sdpMid;
    container["sdpMlineIndex"] = sdpMlineIndex;

  }

}