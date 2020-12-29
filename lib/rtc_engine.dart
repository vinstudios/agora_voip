import 'package:agora_rtc_engine/rtc_engine.dart';

import 'config.dart';

class Engine {

  static Future<RtcEngine> initialize({String token, String channelName, String uid, ClientRole role, Function(String channel, int uid, int elapsed) joinChannelSuccess, Function(ErrorCode code) error}) async {
    RtcEngine engine = await RtcEngine.create(Config.agoraAppId);
    await engine.enableAudio();
    await engine.setChannelProfile(ChannelProfile.Communication);
    await engine.setClientRole(role);

    engine.setEventHandler(RtcEngineEventHandler(
      error: error,
      joinChannelSuccess: joinChannelSuccess,
      leaveChannel: (stats) {
        print("#################################");
        print("Leave: $stats");
      },

      userJoined: (uid, elapsed) {
        print("#################################");
        print("User joined: $uid");
      },

      userOffline: (uid, elapsed) {
        print("#################################");
        print("User offline: $uid");
      },

      requestToken: () {
        print("#######REQUEST TOKEN#######");
      },
      tokenPrivilegeWillExpire: (token) {
        print("#######tokenPrivilegeWillExpire##########");
        print(token);
      },

    ));

    // await engine.enableWebSdkInteroperability(true);
    await engine.joinChannelWithUserAccount(token, channelName, uid);
    return engine;
  }

}