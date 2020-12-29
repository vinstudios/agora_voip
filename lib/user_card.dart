import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'user_model.dart';

class UserCard extends StatefulWidget {
  final UserModel user;
  final String uid;
  final Function call;
  UserCard({@required Key key, this.user, this.uid, this.call}) : super (key: key);
  @override
  _UserCardState createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {

  dynamic isOnline = false;
  dynamic lastChanged;
  String callingId = "";

  String lastSeen(int timestamp) {

    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp + 28800);
    DateTime now = DateTime.now();
    String date = "";
    String time = DateFormat(DateFormat.HOUR_MINUTE_SECOND).format(dateTime);

    if (dateTime.year == now.year) {
      if (dateTime.month == now.month) {

        if (dateTime.day == now.day){
          date = "Today";
        } else if (dateTime.day == now.day - 1) {
          date = "Yesterday";
        }
      }
    }

    if (date.isEmpty) {
      date = DateFormat(DateFormat.YEAR_MONTH_DAY).format(dateTime);
    }
    return date + " @ " + time;
}

  @override
  void initState() {
    FirebaseDatabase.instance.reference().child("/presence/" + widget.user.uid).onValue.listen((event) {
      if (event.snapshot.value != null) {
        dynamic call = event.snapshot.value["call"];
        if (call != null) {
          callingId = call["id"] ?? "";
        }
        isOnline = event.snapshot.value["online"];
        lastChanged = event.snapshot.value["last_changed"];
      }

      if (mounted) setState((){});

    });

    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 5,
                spreadRadius: 0,
                color: Colors.black.withOpacity(0.25),
              ),
            ],
          ),
          margin: EdgeInsets.symmetric(horizontal: 10),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Container(
                  height: 60,
                  width: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.person, color: Colors.grey,),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.user.name, style: TextStyle(fontWeight: FontWeight.bold),),
                      Text(widget.user.phone, style: TextStyle(fontSize: 12),),
                      isOnline == true ? Text(callingId.isEmpty ? "Online" : callingId == widget.uid ? "Calling..." : "Busy", style: TextStyle(color: callingId.isEmpty ? Colors.green : callingId == widget.uid ? Colors.grey : Colors.orange, fontWeight: FontWeight.bold)) :
                      lastChanged == null ? SizedBox() : Text(lastSeen(lastChanged), style: TextStyle(fontSize: 12)),
                      // Text(DateFormat(DateFormat.HOUR_MINUTE_SECOND).format(widget.user.logged), style: TextStyle(fontSize: 12),),
                    ],
                  ),
                ),
                widget.user.uid == widget.uid ? SizedBox() : Material(
                  color: isOnline == true ? callingId.isEmpty ? Colors.green : Colors.grey : Colors.grey,
                  elevation: isOnline == true ?  callingId.isEmpty ? 3 : 0 : 0,
                  shape: CircleBorder(),
                  child: InkWell(
                    customBorder: CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.call, color: Colors.white),
                    ),
                    onTap: () {
                      if (isOnline) {
                        if (callingId.isEmpty) {
                          widget.call(widget.user);
                        } else {
                          print("This user is busy with user: " + callingId);
                        }
                      } else {
                        print("You cannot call a user offline");
                      }

                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
