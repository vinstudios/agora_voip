import 'package:flutter/material.dart';
import 'loader.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    home: Loader(),
  ));
}
