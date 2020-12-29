import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'users_view.dart';

class LoginView extends StatefulWidget {
  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {

  String errorMessage;
  String verificationId;
  String phoneNumber;
  bool sent = false;
  bool sending = false;
  TextEditingController textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {

        if (sent) {
          return false;
        } else {
          return true;
        }

      },
      child: Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: SizedBox.expand(
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.white,
              ),
              width: double.infinity,
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black54)),
                  SizedBox(height: 20,),
                  sent ?
                  TextField(
                    controller: textEditingController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 50, letterSpacing: 5),
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "000000",
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                    )
                  ) :
                  TextField(
                    maxLength: 10,
                    keyboardType: TextInputType.phone,
                    controller: textEditingController,
                    style: TextStyle(fontSize: 18, letterSpacing: 1, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Mobile Number",
                      labelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                      prefixText: "+63 ",
                      counterText: "",
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.blue.shade900,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.blue.shade900,
                          width: 1.5,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  errorMessage == null ? SizedBox(height: 50,) :
                  Column(
                    children: [
                      SizedBox(height: 20,),
                      Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.red),),
                      SizedBox(height: 20,),
                    ],
                  ),
                  Material(
                    color: sent ? Colors.green : Colors.blue.shade900,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      child: Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            sending ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),
                            ) :
                            Text(sent ? "Verify Code" : "Send Code", style: TextStyle(color: Colors.white),),
                          ],
                        ),
                      ),
                      onTap: sending ? null : () async {
                        FocusScope.of(context).unfocus();
                        setState((){
                          errorMessage = null;
                          sending = true;
                        });

                        if (sent) {

                          PhoneAuthCredential phoneAuthCredential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: textEditingController.text);
                          UserCredential result = await FirebaseAuth.instance.signInWithCredential(phoneAuthCredential).catchError((error) => setState(() {
                            errorMessage = error.message;
                            sending = false;
                          }));

                          if (result != null ) {
                            textEditingController.clear();
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UsersView()));
                          }

                        } else {
                          await FirebaseAuth.instance.verifyPhoneNumber(
                            phoneNumber: '+63${textEditingController.text}',
                            verificationCompleted: (PhoneAuthCredential credential) async {
                              UserCredential result = await FirebaseAuth.instance.signInWithCredential(credential);
                              if (result != null) {
                                textEditingController.clear();
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UsersView()));
                              }
                            },

                            codeSent: (String id, int resendToken) {
                              verificationId = id;
                              setState(() {
                                phoneNumber = textEditingController.text;
                                textEditingController.clear();
                                sending = false;
                                sent = true;
                              });
                            },

                            codeAutoRetrievalTimeout: (String verificationId) {
                              print("##########Auto-resolution timed out################");
                              // Auto-resolution timed out...
                            },
                            verificationFailed: (FirebaseAuthException e) {
                              if (e.code == 'invalid-phone-number') {
                                errorMessage = 'The provided phone number is not valid.';
                              } else {
                                errorMessage = e.toString();
                              }
                              setState(() => sending = false);
                            },
                          ).catchError((error){
                            print("#########################");
                            print(error.toString());
//                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()),));
                            setState(() {
                              errorMessage = error.toString();
                              sending = false;
                            });
                          });
                        }

                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
