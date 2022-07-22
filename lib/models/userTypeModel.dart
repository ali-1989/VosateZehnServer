
class UserTypeModel {
  static const UserType simpleUser = UserType.simpleUser;
  static const UserType managerUser = UserType.managerUser;
  static const String vosateZehnApp = 'vosate_zehn';
  static const String vosateZehnManagerApp = 'vosate_zehn Manager';

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
      return 9;
    }

    return 0;
  }

  static int getUserTypeNumByAppName(String? appName) {
    if(appName == vosateZehnApp) {
      return 1;
    }

    if(appName == vosateZehnManagerApp) {
      return 9;
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