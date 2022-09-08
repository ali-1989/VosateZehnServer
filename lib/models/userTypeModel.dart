
class UserTypeModel {
  static const UserType simpleUser = UserType.simpleUser;
  static const UserType managerUser = UserType.managerUser;
  static const String vosateZehnApp = 'VosateZehn';
  static const String vosateZehnManagerApp = 'VosateZehn Manager';
  static const int managerUserTypeNumber = 9;

  UserTypeModel();

  static UserType getUserTypeByAppName(String? appName) {
    if(appName == vosateZehnApp) {
      return simpleUser;
    }

    if(appName == vosateZehnManagerApp) {
      return managerUser;
    }

    return simpleUser;
  }

  static int getUserTypeNumByType(UserType? type) {
    if(type == null || type == simpleUser) {
      return 1;
    }

    if(type == managerUser) {
      return managerUserTypeNumber;
    }

    return 0;
  }

  static int getUserTypeNumByAppName(String? appName) {
    if(appName == vosateZehnApp) {
      return 1;
    }

    if(appName == vosateZehnManagerApp) {
      return managerUserTypeNumber;
    }

    return 0;
  }
}
///====================================================================================
enum UserType {
  managerUser,
  simpleUser,
}

extension UserTypeExtention on UserType {
  UserType getByName(String s){
    try {
      return UserType.values.firstWhere((element) => element.name == s);
    }
    catch (e){
      return UserType.simpleUser;
    }
  }
}