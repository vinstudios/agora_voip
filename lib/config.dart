
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Config {

  static final String agoraAppId = "1e07b11b17db4d6894b36f29e96d849a";
  static final String agoraCertificate = "3c69958967004bcfbc3958ca718db228";

  static final String apiKey = 'AIzaSyCyLTI0FvRRanUQGGVvoeeNxHFVpxZxib0';
  static FirebaseAuth auth;
  static FirebaseFirestore database;
  static FirebaseStorage storage;

  static Future<void> init() async {
    FirebaseApp app = await Firebase.initializeApp();
    auth = FirebaseAuth.instance;
    database = FirebaseFirestore.instance;
    storage = FirebaseStorage(app: app, storageBucket: 'gs://jexmov.appspot.com/');
  }

}