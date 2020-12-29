import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'login_view.dart';
import 'users_view.dart';


class Loader extends StatefulWidget {

  @override
  _LoaderState createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {

  void initializeApp() async {
    await Config.init();
    if (FirebaseAuth.instance.currentUser != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UsersView()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginView()));
    }

  }
  @override
  void initState() {
    initializeApp();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: SizedBox.expand(
        child: Center(
          child: Container(
            height: 100,
            width: 100,
            alignment: Alignment.center,
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),
          ),
        ),
      ),
    );
  }
}
