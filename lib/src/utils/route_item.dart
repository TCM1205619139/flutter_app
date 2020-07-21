import 'package:flutter/material.dart';
import 'dart:core';

typedef void RouteCallback(BuildContext context);

class RouteItem {
  final String name;
  final String path;
  final RouteCallback callback;

  RouteItem({
    @required this.name,
    @required this.path,
    @required this.callback
  });
}