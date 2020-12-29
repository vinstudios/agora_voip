import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:slide_to_confirm/slide_to_confirm.dart';

import 'config.dart';

class RiderView extends StatefulWidget {
  @override
  _RiderViewState createState() => _RiderViewState();
}

class _RiderViewState extends State<RiderView> {

  String imageUrl;
  Map user;
  bool online = true;
  final MarkerId riderId = MarkerId("rider");
  final CircleId radiusId = CircleId("radius");

  Marker marker(LatLng latlng) => Marker(markerId: riderId, position: latlng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), onTap: null);
  Circle circle(LatLng center) => Circle(circleId: radiusId, center: center, strokeWidth: 1, strokeColor: Colors.white, radius: 500, onTap: null, fillColor: Colors.blue.withOpacity(0.20));

  GoogleMapController mapController;
  static final LatLng center = LatLng(16.6915754, 121.5495982);
  Map<CircleId, Circle> circles = <CircleId, Circle>{};
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  LatLng latlng = center;

  BitmapDescriptor markerIcon;
  MapType mapType = MapType.normal;
  double zoom = 15.5;
  double tilt = 0;
  bool zooming = false;
  String address;
  bool enabledCircle = true;

  Timer timer;
  final int time = 28800;
  int start = 0;

  void startTimer() {
    const oneSec = const Duration(seconds: 1);
    timer = new Timer.periodic(
        oneSec, (Timer timer) {
      if (mounted) setState(() {
        if (start < 1) {
          timer.cancel();
          setState(() {
            online = false;
            start = time;
          });
        } else {
          start = start - 1;
        }
      });
    });
  }

  String formatTime(int time) {
    Duration duration = Duration(seconds: time);
    return [duration.inHours, duration.inMinutes, duration.inSeconds].map((seg) => seg.remainder(60).toString().padLeft(2, '0')).join(':');
  }

  static final CameraPosition _food99 = CameraPosition(
    target: center,
    zoom: 14.4746,
  );

  void _onMapCreated(GoogleMapController controller) {
    this.mapController = controller;
    startTimer();
  }

  void onCameraMove(CameraPosition camPos) {
    latlng = camPos.target;
    tilt = camPos.tilt;
    zoom = camPos.zoom;
  }

  void onCameraMoveStarted() {
    if (!zooming) {
    }
  }

  void onCameraIdle() {
    if (zooming) {
      zooming = false;
    } else {

    }
  }

  Future<String> getAddressFromLatLng(LatLng latLng) async {
    try {
      http.Response response = await http.get('https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}&key=${Config.apiKey}');
      if (response.statusCode == 200) {
        var result = json.decode(response.body);
        if (result['status'] == 'OK') {
          return result['results'][0]['formatted_address'];
        } else {
          return "Status unkwnown: Unnamed place";
        }
      } else {
        return "Unexpected error. Status code: " + response.statusCode.toString();
      }
    } on Error catch (e) {
      print("############################## ERROR ############################");
      print(e.toString());
    }

    return null;
  }

  StreamSubscription<Position> getCurrentPositionStream() {
    return Geolocator.getPositionStream().listen((pos) {
      try {
        latlng = LatLng(pos.latitude, pos.longitude);
        if (mounted) setState(() {
          mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
            target: latlng,
            zoom: zoom,
          )));

          markers[riderId] = marker(latlng);
          if (enabledCircle) circles[radiusId] = circle(latlng);
        });

      } catch (e) {
        setState((){
          markers.clear();
          circles.clear();
        });
        print(e.toString());
      }
    });
  }

  void init() async {

    UserCredential result = await Config.auth.signInWithEmailAndPassword(email: "darvs@gmail.com", password: '123123').catchError((error){
      print("############################## ERROR ############################");
      print(error.toString());
    });

    if (result != null ) {
      Config.database.collection('users').doc(Config.auth.currentUser.uid).get().then((snapshot) {
        user = snapshot.data();
      }).catchError((error){
        print("############################## ERROR ############################");
        print(error.toString());
      });
    }
  }

  @override
  void initState() {
    start = time;
    init();
    getCurrentPositionStream();
    super.initState();
  }

  @override
  void dispose() {
    getCurrentPositionStream().cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        body: SizedBox.expand(
          child: Stack(
            children: [
              GoogleMap(
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: _onMapCreated,
                mapType: mapType,//mapType,
                initialCameraPosition: _food99,
                markers: Set<Marker>.of(markers.values),
                circles: Set<Circle>.of(circles.values),
                onCameraMove: onCameraMove,
                onCameraMoveStarted: onCameraMoveStarted,
                onCameraIdle: onCameraIdle,
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  width: MediaQuery.of(context).size.width - 20,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        spreadRadius: 0,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider("https://firebasestorage.googleapis.com/v0/b/jexmov.appspot.com/o/users%2FXMk90HBpt4QIiSZBG58onM8rPD43%2Fclient?alt=media&token=ab9b0a8d-3887-40df-ba9a-7ea37cf89e7f"),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DARVIN MAMANGON', style: TextStyle(color: Colors.black, fontSize: 16),),
                            Row(
                              children: [
                                Icon(Icons.star, size: 18, color: Colors.amber),
                                Icon(Icons.star, size: 18, color: Colors.amber),
                                Icon(Icons.star, size: 18, color: Colors.amber),
                                Icon(Icons.star, size: 18, color: Colors.amber),
                                Icon(Icons.star, size: 18, color: Colors.amber),
                              ],
                            ),
                            SizedBox(height: 3),
                            Row(
                              children: [
                                Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.moneyBillWaveAlt, size: 12, color: Colors.grey),
                                    SizedBox(width: 3),
                                    Text("₱450"),
                                  ],
                                ),
                                SizedBox(width: 10),
                                Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.hamburger, size: 12, color: Colors.grey),
                                    SizedBox(width: 3),
                                    Text("12"),
                                  ],
                                ),
                                SizedBox(width: 10),
                                Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.motorcycle, size: 12, color: Colors.grey),
                                    SizedBox(width: 3),
                                    Text("10km"),
                                  ],
                                ),
                                SizedBox(width: 10),
                                Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.cube, size: 12, color: Colors.grey),
                                    SizedBox(width: 3),
                                    Text("0"),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 100,
                left: 20,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 40,
                  child: Row(
                    children: [
                      Material(
                        shape: CircleBorder(),
                        elevation: 5,
                        color: Colors.white.withOpacity(0.85),
                        child: InkWell(
                          customBorder: CircleBorder(),
                          child: Container(
                            height: 40,
                            width: 40,
                            alignment: Alignment.center,
                            child: Icon(FontAwesomeIcons.layerGroup, size: 18, color: Colors.green,),
                          ),
                          onTap: (){
                            setState(() {
                              if (mapType == MapType.normal) {
                                mapType = MapType.hybrid;
                              } else {
                                mapType = MapType.normal;
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Material(
                        shape: CircleBorder(),
                        elevation: 5,
                        color: Colors.white.withOpacity(0.85),
                        child: InkWell(
                          customBorder: CircleBorder(),
                          child: Container(
                            height: 40,
                            width: 40,
                            alignment: Alignment.center,
                            child: Icon(FontAwesomeIcons.circle, size: 20, color: Colors.blue,),
                          ),
                          onTap: (){
                            setState(() {
                              if (enabledCircle) {
                                enabledCircle = false;
                                circles.clear();
                              } else {
                                enabledCircle = true;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 70,
                child: AppBar(
                  elevation: 0,
                  title: !online ? Text("Go Online") : Text(formatTime(start), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),),
                  actions: [
                    Switch(
                      value: online,
                      activeColor: Colors.white,
                      onChanged: (b) async {
                        if (!b) {
                          await showDialog<void>(
                            context: context,
                            barrierDismissible: true, // user must tap button!
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Going offline?"),
                                content: SingleChildScrollView(
                                  child: ListBody(
                                    children: <Widget>[
                                      Text('Would you like to continue going offline mode?'),
                                    ],
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text('Yes', style: TextStyle(color: Colors.red),),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      timer.cancel();
                                      start = time;
                                      setState(()=> online = b);
                                    },
                                  ),
                                  TextButton(
                                    child: Text('No'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),

                                ],
                              );
                            },
                          );
                        }
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
              !online ? Positioned(
                top: 0,
                left: 0,
                child: Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  color: Colors.black.withOpacity(0.35),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: Offset(0, 0),
                              spreadRadius: 0,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(FontAwesomeIcons.infoCircle, size: 14, color: Colors.orange.shade700),
                                SizedBox(width: 5),
                                Text('OFFLINE MODE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                              ],
                            ),
                            Divider(),
                            SizedBox(height: 5),
                            Text("It's looks like you're in offline mode. Any order by the customer will not notify to you.", style: TextStyle(color: Colors.grey),),

                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      ConfirmationSlider(
                          text: 'SLIDE TO ONLINE',
                          textStyle: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                          height: 60,
                          width: MediaQuery.of(context).size.width * 0.75,
                          foregroundColor: Colors.green,
                          backgroundColor: Colors.grey.shade50,
                          foregroundShape: BorderRadius.circular(10),
                          backgroundShape: BorderRadius.circular(15),
                          onConfirmation: (){
                            startTimer();
                            setState((){
                              online = true;
                            });
                          }),
                    ],
                  ),
                ),
              ) : SizedBox(),
            ],
          ),
        ),
      ),
    );
  }

  Future<BitmapDescriptor> getClusterMarker(
      int clusterSize,
      Color clusterColor,
      Color textColor,
      int width,
      ) async {
    final PictureRecorder pictureRecorder = PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = clusterColor;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    final double radius = width / 2;
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      paint,
    );
    textPainter.text = TextSpan(
      text: clusterSize.toString(),
      style: TextStyle(
        fontSize: radius - 5,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        radius - textPainter.width / 2,
        radius - textPainter.height / 2,
      ),
    );
    final image = await pictureRecorder.endRecording().toImage(
      radius.toInt() * 2,
      radius.toInt() * 2,
    );
    final data = await image.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
  }
}
