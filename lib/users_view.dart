import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';


import 'config.dart';
import 'login_view.dart';
import 'user_card.dart';
import 'user_model.dart';
import 'rtc_engine.dart';

class UsersView extends StatefulWidget {
  @override
  _UsersViewState createState() => _UsersViewState();
}


class _UsersViewState extends State<UsersView> with WidgetsBindingObserver {

  RtcEngine incomingRtcEngine;
  String incomingCallId = "";
  int incomingCallStatus = 0;
  bool incomingCall = false;
  User user;
  bool streamed = false;
  bool showDialogSetup = false;
  List<UserModel> userModels = [];
  DatabaseReference userStatusDatabaseRef;
  BuildContext dialogContext;
  Function incomingCallState;

  var userOfflineRef = {
    "online": false,
    "last_changed": ServerValue.timestamp,
    "call": {"id": "", "status": 0},
  };

  var userOnlineRef = {
    "online": true,
    "last_changed": ServerValue.timestamp,
  };

  void callBack(UserModel um) async {

    await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {

        List<String> statusText = [
          "Connecting...",
          "Calling...",
          "Connected",
          "Call rejected",
          "Call ended",
          "Call cancelled",
          "Call error",
        ];

        DatabaseReference ref = FirebaseDatabase.instance.reference().child("/presence/" + um.uid);

        RtcEngine engine;
        bool calling = false;
        bool cancel = false;
        bool end = false;
        bool speakerOn = false;
        bool micOff = false;
        int outgoingCallStatus = 0;
        StreamSubscription<Event> event;

        void call(Function outgoingCallState) {
          FirebaseFunctions.instance.httpsCallable("agoraRtc").call({"appId": Config.agoraAppId, "appCertificate": Config.agoraCertificate, "channelName": user.uid, "uid": user.uid}).then((result) async {
            print("TOKEN: " + result.data);

            if (cancel){
              print("Cancel before accepting permission");
              return;
            }

            await PermissionHandler().requestPermissions(
              [PermissionGroup.microphone],
            );

            if (cancel){
              print("Cancel after accepting permission");
              return;
            }

            engine = await Engine.initialize(
                token: result.data,
                channelName: user.uid,
                uid: user.uid,
                role: ClientRole.Broadcaster,

                error: (code) async {
                  print("#################################");
                  print("Error: $code");
                  await ref.update({"call": {"id": "", "status": 6},});
                },

                joinChannelSuccess: (channel, uid, elapsed) {
                  print("#################################");
                  print("Joined | channel: $channel, uid: $uid");

                  if (cancel){
                    print("Cancel after joining channel");
                    return;
                  }

                  ref.update({
                    "call": {"id": user.uid, "status": 1},
                  }).then((value) async {
                    event = ref.onValue.listen((result) async {
                      dynamic call = result.snapshot.value["call"];
                      if (call != null) {

                        outgoingCallStatus = call["status"] ?? -1;
                        outgoingCallState((){});

                        switch (outgoingCallStatus) {

                          case 3:
                            event.cancel();
                            await engine.destroy();
                            await Future.delayed(Duration(seconds: 4), (){});
                            Navigator.pop(context);
                            break;

                          case 4:
                            event.cancel();
                            engine.leaveChannel();
                            await engine.destroy();
                            await Future.delayed(Duration(seconds: 4), (){});
                            Navigator.pop(context);
                            break;

                          case 5:
                            event.cancel();
                            engine.leaveChannel();
                            await engine.destroy();
                            await Future.delayed(Duration(seconds: 4), (){});
                            Navigator.pop(context);
                            break;

                          case 6:
                            event.cancel();
                            await engine.destroy();
                            await Future.delayed(Duration(seconds: 4), (){});
                            Navigator.pop(context);
                            break;

                        }
                      }
                    });
                  });
            });

          });
        }

        return WillPopScope(
          onWillPop: () async => false,
          child: StatefulBuilder(
              builder: (context, setState){

                if (!calling) {
                  calling = true;
                  call(setState);
                }

                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Outgoing Call", style: TextStyle(fontSize: 16, color: Colors.grey)),
                        SizedBox(height: 20),
                        Container(
                          height: 70,
                          width: 70,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade300,
                          ),
                          child: Icon(Icons.person),
                        ),
                        SizedBox(height: 20),
                        Text(um.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        SizedBox(height: 10),
                        Text(statusText[outgoingCallStatus], style: TextStyle(fontSize: 16, color: Colors.grey)),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            outgoingCallStatus == 2 ? Row(
                              children: [
                                Material(
                                  color:  micOff ? Colors.red : Colors.grey,
                                  elevation: 3,
                                  shape: CircleBorder(),
                                  child: InkWell(
                                    customBorder: CircleBorder(),
                                    child: Container(
                                      height: 50,
                                      width: 50,
                                      alignment: Alignment.center,
                                      child: Icon(micOff ? Icons.mic : Icons.mic_off, color: Colors.white),
                                    ),
                                    onTap: () async {
                                      if (micOff) {
                                        await engine.muteLocalAudioStream(false).then((value) => setState(() => micOff = false));
                                      } else {
                                        await engine.muteLocalAudioStream(true).then((value) => setState(() => micOff = true));
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(width: 20),
                                Material(
                                  color: speakerOn ? Colors.blue : Colors.grey,
                                  elevation: 3,
                                  shape: CircleBorder(),
                                  child: InkWell(
                                    customBorder: CircleBorder(),
                                    child: Container(
                                      height: 50,
                                      width: 50,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.speaker_phone, color: Colors.white),
                                    ),
                                    onTap: () async {
                                      speakerOn = await engine.isSpeakerphoneEnabled();
                                      await engine.setEnableSpeakerphone(!speakerOn).then((value) async {
                                        speakerOn = await engine.isSpeakerphoneEnabled();
                                        setState((){});
                                      }
                                     );
                                    },
                                  ),
                                ),
                                SizedBox(width: 20),
                              ],
                            ) : SizedBox(),
                            Material(
                              color: cancel || end || outgoingCallStatus == 3 || outgoingCallStatus == 4 || outgoingCallStatus == 5 || outgoingCallStatus == 6 ? Colors.grey: Colors.red,
                              elevation: cancel || end || outgoingCallStatus == 3 || outgoingCallStatus == 4 || outgoingCallStatus == 5 || outgoingCallStatus == 6 ? 0 : 3,
                              shape: CircleBorder(),
                              child: InkWell(
                                customBorder: CircleBorder(),
                                child: Container(
                                  height: 50,
                                  width: 50,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.call_end, color: Colors.white),
                                ),
                                onTap: cancel || end || outgoingCallStatus == 3 || outgoingCallStatus == 5 || outgoingCallStatus == 6 ? null : () async {

                                  if (outgoingCallStatus == 1){
                                    await ref.update({"call": {"id": "", "status": 5},});
                                  } else if (outgoingCallStatus == 2 ) {
                                    setState(() => end = true);
                                    await ref.update({"call": {"id": "", "status": 4},});
                                  } else {
                                    setState(() => cancel = true);

                                    if (engine != null) {
                                      engine.leaveChannel();
                                      await engine.destroy();
                                      Navigator.pop(context);
                                    } else {
                                      Navigator.pop(context);
                                    }

                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
          ),
        );
      },
    );
  }

  StreamSubscription<Event> get checkUserPresenceStream {
    return userStatusDatabaseRef.onValue.listen((event) async {
      dynamic call = event.snapshot.value["call"];
      if (call != null) {

        incomingCallId = call["id"] ?? "";
        incomingCallStatus = call["status"] ?? -1;

        switch (incomingCallStatus) {
          case 1: //Ringing
            if (!incomingCall && incomingCallId.isNotEmpty) {
              incomingCall = true;
              await showDialog(
                barrierDismissible: false,
                context: context,
                builder: (context){

                  List<String> statusText = [
                    "Connecting...",
                    "Incoming call",
                    "Connected",
                    "Call rejected",
                    "Call ended",
                    "Call cancelled",
                    "Call error",
                  ];

                  bool connecting = false;
                  bool speakerOn = false;
                  bool micOff = false;
                  dialogContext = context;
                  int index = userModels.indexWhere((userModel) => userModel.uid == incomingCallId);
                  UserModel um = userModels[index];

                  return WillPopScope(
                    onWillPop: () async => false,
                    child: StatefulBuilder(
                      builder: (context, setState){
                        incomingCallState = setState;
                        return Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Incoming Call", style: TextStyle(fontSize: 16, color: Colors.grey)),
                                SizedBox(height: 20),
                                Container(
                                  height: 70,
                                  width: 70,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey.shade300,
                                  ),
                                  child: Icon(Icons.person),
                                ),
                                SizedBox(height: 20),
                                Text(um.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                Text(um.phone, style: TextStyle(fontSize: 16, color: Colors.blue)),
                                SizedBox(height: 10),
                                Text(connecting ? "Connecting..." : statusText[incomingCallStatus], style: TextStyle(fontSize: 16, color: Colors.grey)),
                                SizedBox(height: 20),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    incomingCallStatus == 2 ? Row(
                                      children: [
                                        Material(
                                          color: micOff ? Colors.red : Colors.grey,
                                          elevation: 3,
                                          shape: CircleBorder(),
                                          child: InkWell(
                                            customBorder: CircleBorder(),
                                            child: Container(
                                              height: 50,
                                              width: 50,
                                              alignment: Alignment.center,
                                              child: Icon(micOff ? Icons.mic : Icons.mic_off, color: Colors.white),
                                            ),
                                            onTap: () async {
                                              if (micOff) {
                                                await incomingRtcEngine.muteLocalAudioStream(false).then((value) => setState(() => micOff = false));
                                              } else {
                                                await incomingRtcEngine.muteLocalAudioStream(true).then((value) => setState(() => micOff = true));
                                              }
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 20),
                                      ],
                                    ) : SizedBox(),
                                    Material(
                                      color: connecting || incomingCallStatus == 3 || incomingCallStatus == 4 || incomingCallStatus == 5 || incomingCallStatus == 6 ? incomingCallStatus == 2 && speakerOn ? Colors.blue : Colors.grey : Colors.red,
                                      elevation: connecting ||  incomingCallStatus == 3 || incomingCallStatus == 4 || incomingCallStatus == 5 || incomingCallStatus == 6 ? 0 : 3,
                                      shape: CircleBorder(),
                                      child: InkWell(
                                        customBorder: CircleBorder(),
                                        child: Container(
                                          height: 50,
                                          width: 50,
                                          alignment: Alignment.center,
                                          child: Icon(incomingCallStatus == 2 ? Icons.speaker_phone : Icons.call_end, color: Colors.white),
                                        ),
                                        onTap: () async {
                                          if (incomingCallStatus == 1) {
                                            await userStatusDatabaseRef.update({"call": {"id": "", "status": 3}}); //Reject
                                          } else if (incomingCallStatus == 2){
                                            speakerOn = await incomingRtcEngine.isSpeakerphoneEnabled();
                                            await incomingRtcEngine.setEnableSpeakerphone(!speakerOn).then((value) async {
                                              speakerOn = await incomingRtcEngine.isSpeakerphoneEnabled();
                                              setState((){});
                                            });
                                          } else {
                                            print("What is this?");
                                          }
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 20),
                                    Material(
                                      color: incomingCallStatus == 2 ? Colors.red : connecting || incomingCallStatus == 3 || incomingCallStatus == 4 || incomingCallStatus == 5 || incomingCallStatus == 6 ? Colors.grey : Colors.green,
                                      elevation: connecting || incomingCallStatus == 3 || incomingCallStatus == 4 || incomingCallStatus == 5 || incomingCallStatus == 6 ? 0 : 3,
                                      shape: CircleBorder(),
                                      child: InkWell(
                                        customBorder: CircleBorder(),
                                        child: Container(
                                          height: 50,
                                          width: 50,
                                          alignment: Alignment.center,
                                          child: Icon(incomingCallStatus == 2 ? Icons.call_end : Icons.call, color: Colors.white),
                                        ),
                                        onTap: connecting ? null : () async {
                                          if (incomingCallStatus == 1) {
                                            setState(() => connecting = true);
                                            await FirebaseFunctions.instance.httpsCallable("agoraRtc").call({"appId": Config.agoraAppId, "appCertificate": Config.agoraCertificate, "channelName": incomingCallId, "uid": user.uid}).then((result) async {

                                              print("TOKEN: " + result.data);
                                              incomingRtcEngine = await Engine.initialize(
                                                  token: result.data,
                                                  channelName: incomingCallId,
                                                  uid: user.uid,
                                                  role: ClientRole.Audience,
                                                  error: (code) async {
                                                    await userStatusDatabaseRef.update({"call": {"id": "","status": 6}});
                                                  },

                                                  joinChannelSuccess:(channel, uid, elapsed) async {
                                                    print("#################################");
                                                    print("Joined | channel: $channel, uid: $uid");

                                                    userStatusDatabaseRef.update({"call": {"id": incomingCallId, "status": 2}});

                                                  }
                                              );

                                            });
                                            setState(() => connecting = false);
                                          } else if (incomingCallStatus == 2) {
                                            await userStatusDatabaseRef.update({"call": {"id": "","status": 4}});
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );

              dialogContext = null;
              incomingCallId = "";
              incomingCallStatus = 0;
              incomingCall = false;

            }
            break;
          case 2: //Acepted
            incomingCallState((){});
            break;
          default:
            if (incomingCall && dialogContext != null && incomingCallStatus != 0) {
              incomingCallState((){});
              if (incomingRtcEngine != null) {
                print("RTC engine Not null");
                try {
                  await incomingRtcEngine.leaveChannel();
                  await incomingRtcEngine.destroy();
                } catch (e) {
                  print("#################");
                  print(e.toString());
                }

              }

              Future.delayed(Duration(seconds: 3),(){}).then((value) {
                userStatusDatabaseRef.update({"call":{"id": "", "status": 0}}).then((value){
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                });
              });
            }
            break;
        }
      }
    });
  }

  StreamSubscription<QuerySnapshot> get usersStream {
    return FirebaseFirestore.instance.collection("calls").snapshots().listen((event) {
      if (event.size > 0) {
        for (var change in event.docChanges) {
          if (change.type == DocumentChangeType.added) {
            UserModel userModel = change.doc.data().toUserModel();
            userModels.insert(0, userModel);

          } else if (change.type == DocumentChangeType.modified) {
            int index = userModels.indexWhere((userModel) => userModel.uid == change.doc.id);
            if (index > -1) {
              UserModel userModel = change.doc.data().toUserModel();
              userModels[index] = userModel;
            }
          } else if (change.type == DocumentChangeType.removed) {
            int index = userModels.indexWhere((userModel) => userModel.uid == change.doc.id);
            if (index > -1) {
              userModels.removeAt(index);
            }
          }
        }
      } else {
        userModels.clear();
      }
      if (mounted) setState((){});
    });
  }

  StreamSubscription<DocumentSnapshot> get checkDataStream {
    return FirebaseFirestore.instance.collection("calls").doc(user.uid).snapshots().listen((event) async {
      if (!event.exists) {
        if (!showDialogSetup){
          showDialogSetup = true;
          await showSetupNameDialog();
          showDialogSetup = false;
        }
      }
    });
  }

  StreamSubscription<Event> get checkInfoStream {
    return FirebaseDatabase.instance.reference().child(".info/connected").onValue.listen((event) {
      if (event.snapshot.value == true) {
        userStatusDatabaseRef.onDisconnect().update(userOfflineRef).then((result){
          userStatusDatabaseRef.update(userOnlineRef);
        });
      }
    });
  }

  StreamSubscription<User> get authStream {
    return FirebaseAuth.instance.authStateChanges().listen((event) {
      user = event;
      if (user != null) {
        userStatusDatabaseRef = FirebaseDatabase.instance.reference().child("/presence/" + user.uid);
        if (!streamed) {
          streamed = true;
          checkDataStream;
          checkInfoStream;
          checkUserPresenceStream;
        }
      } else {
        if (userStatusDatabaseRef != null) {
          userStatusDatabaseRef.update(userOfflineRef);
          userStatusDatabaseRef = null;
        }

        if (streamed) {
          streamed = false;
          checkDataStream.cancel();
          checkInfoStream.cancel();
          checkUserPresenceStream.cancel();
        }
      }

      if(mounted) setState(() {});
    });
  }

  Future showSetupNameDialog() async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {

        String displayName = "";
        bool saving = false;
        String errorText;

        return StatefulBuilder(
          builder: (context, setState){
            return Dialog(
              child: WillPopScope(
                onWillPop: () async => false,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("COMPLETE PROFILE", style: TextStyle(fontWeight: FontWeight.bold),),
                      SizedBox(height: 10),
                      Divider(),
                      SizedBox(height: 10),
                      Text("Enter display name to enter."),
                      SizedBox(height: 40),
                      TextField(
                        decoration: InputDecoration(
                          labelText: "Display Name",
                        ),
                        onChanged: (value) => displayName = value,
                      ),
                      SizedBox(height: 20),
                      errorText == null ? SizedBox() : Column(
                        children: [
                          Text(errorText, style: TextStyle(color: Colors.red)),
                          SizedBox(height: 20),
                        ],
                      ),
                      saving ? CircularProgressIndicator() : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FlatButton(
                            onPressed: () => FirebaseAuth.instance.signOut().then((result) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginView()))),
                            child: Text("EXIT", style: TextStyle(color: Colors.white),),
                            color: Colors.grey,
                          ),
                          FlatButton(
                            onPressed: () async {

                              if (displayName.trim().isNotEmpty){
                                setState((){
                                  errorText = null;
                                  saving = true;
                                });

                                await FirebaseFirestore.instance.collection("calls").doc(user.uid).set({
                                  "uid": user.uid,
                                  "phone": user.phoneNumber,
                                  "name": displayName,
                                  "created": FieldValue.serverTimestamp(),
                                }).catchError((error){
                                  errorText = error.toString();
                                  setState((){
                                    errorText = error.toString();
                                    saving = false;
                                  });
                                }).then((value) async {

                                  await FirebaseDatabase.instance.reference().child("/presence/" + user.uid).set({
                                    "online": true,
                                    "last_changed": ServerValue.timestamp,
                                    "call": {"id": "", "status": 0},
                                  });

                                  Navigator.pop(context);
                                });
                              }
                            },
                            child: Text("ENTER", style: TextStyle(color: Colors.white),),
                            color: Colors.blue.shade900,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    authStream;
    usersStream;
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    usersStream.cancel();
    authStream.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // if (state == AppLifecycleState.resumed)
    // print("ONLINE");
    // else
    // print("OFFLINE");
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.blue.shade900,
        appBar: AppBar(
          backgroundColor: Colors.blue.shade900,
          title: Text("Users"),
          actions: [
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: (){
                FirebaseAuth.instance.signOut().then((result) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginView())));
              },
            ),
          ],
        ),

        body: Container(
          color: Colors.grey.shade200,
          child: SizedBox.expand(
            child: ListView(
              children: userModels.map((userModel) => UserCard(key: Key(userModel.uid), user: userModel, uid: user.uid, call: callBack)).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
