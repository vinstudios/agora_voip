class UserModel {
  String uid, name, phone;
  DateTime created;
  UserModel({this.uid, this.name, this.created, this.phone});
}


extension ToUserModel on Map {
  UserModel toUserModel() {

    String name = this["name"] ?? "";
    String uid = this["uid"] ?? "";
    String phone = this["phone"] ?? "";
    DateTime created = DateTime.parse(this["created"].toDate().toString());

    return UserModel(name: name, uid: uid, created: created, phone: phone);
  }
}