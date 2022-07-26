import 'dart:async';
import 'package:assistance_kit/api/generator.dart';
import 'package:vosate_zehn_server/database/models/devicesCellar.dart';
import 'package:vosate_zehn_server/database/models/emailModel.dart';
import 'package:vosate_zehn_server/database/models/mobileNumber.dart';
import 'package:vosate_zehn_server/database/models/userBlockList.dart';
import 'package:vosate_zehn_server/database/models/userConnection.dart';
import 'package:vosate_zehn_server/database/models/users.dart';
import 'package:vosate_zehn_server/database/models/userNameId.dart';
import 'package:vosate_zehn_server/database/models/userPlace.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/models/userTypeModel.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/commonMethods.dart';
import 'package:vosate_zehn_server/rest_api/graphHandler.dart';
import 'package:vosate_zehn_server/rest_api/httpCodes.dart';

class LoginZone {
  LoginZone._();

  static String generateToken(){
    return Generator.generateKey(100);
  }

  static Future<Map<String, dynamic>> loginByUserName(GraphHandlerWrap wrapper) async {
    final js = wrapper.bodyJSON;

    var userName = js[Keys.userName]?? '';
    final deviceId = js[Keys.deviceId];
    final languageIso = js[Keys.languageIso];
    //final appName = js[Keys.appName];

    int? userId = await UserNameModelDb.getUserIdByUserName(userName);

    if (userId == null) {
      return GraphHandler.generateResultError(HttpCodes.error_userNotFound);
    }

    js[Keys.userId] = userId;
    final hashPassword = js['hash_password']?? '-';

    final map = await UserNameModelDb.fetchMapBy(userName, hashPassword);

    if (map == null) {
      return GraphHandler.generateResultError(HttpCodes.error_userNamePassIncorrect);
    }

    if (await UserModelDb.isDeletedUser(userId)) {
      return GraphHandler.generateResultError(HttpCodes.error_userNotFound);
    }

    /*if (!(await UserModelDb.checkUserIsMatchWithApp(userId, appName))) {
      return GraphHandler.generateResultError(HttpCodes.error_userNamePassIncorrect);
    }*/

    if (await UserBlockListModelDb.isBlockedUser(userId)) {
      return GraphHandler.generateResultError(HttpCodes.error_userIsBlocked);
    }

    //.......upsert device id........................
    final deviceCaller = DeviceCellarModelDb.fromMap(js);
    await DeviceCellarModelDb.upsertModel(deviceCaller);
    //.......upsert place........................
    var userPlace = UserPlaceModelDb.fromMap(js);
    await UserPlaceModelDb.upsertModel(userPlace);
    //...............................................
    final token = generateToken();
    await UserConnectionModelDb.upsertUserActiveTouch(userId, deviceId, langIso: languageIso, token: token);

    return _completeLogin(userId, token);
  }
  ///---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> loginByPhoneNumber(GraphHandlerWrap wrapper) async {

    final phoneCode = wrapper.bodyJSON[Keys.phoneCode];
    final mobileNumber = wrapper.bodyJSON[Keys.mobileNumber];
    final deviceId = wrapper.bodyJSON[Keys.deviceId];
    final languageIso = wrapper.bodyJSON[Keys.languageIso];
    //final appName = wrapper.bodyJSON[Keys.appName];


    //final countryCode = CountryModel.getCountryCodeByIso(countryIso);
    final userType = 1;//UserTypeModel.getUserTypeNumByAppName(appName);
    final userId = await MobileNumberModelDb.getUserIdByMobile(userType, phoneCode, mobileNumber);

    if (userId == null) {
      return GraphHandler.generateResultError(HttpCodes.error_userNotFound);
    }

    //final userName = await UserNameModelDb.getUserNameByUserId(userId);

    wrapper.bodyJSON[Keys.userId] = userId;
    /*final hashPassword = js['hash_password']?? '-';

    final map = await UserNameModelDb.fetchMapBy(userName, hashPassword);

    if (map == null) {
      return GraphHandler.generateResultError(HttpCodes.error_userNamePassIncorrect);
    }*/

    if (await UserModelDb.isDeletedUser(userId)) {
      return GraphHandler.generateResultError(HttpCodes.error_userIsBlocked);
    }

    /*if (!(await UserModelDb.checkUserIsMatchWithApp(userId, appName))) {
      return GraphHandler.generateResultError(HttpCodes.error_userNamePassIncorrect);
    }*/

    if (await UserBlockListModelDb.isBlockedUser(userId)) {
      return GraphHandler.generateResultError(HttpCodes.error_userIsBlocked);
    }

    //.......upsert device id........................
    final deviceCaller = DeviceCellarModelDb.fromMap(wrapper.bodyJSON);
    await DeviceCellarModelDb.upsertModel(deviceCaller);
    //.......upsert place........................
    var userPlace = UserPlaceModelDb.fromMap(wrapper.bodyJSON);
    await UserPlaceModelDb.upsertModel(userPlace);
    //...............................................
    final token = generateToken();

    await UserConnectionModelDb.upsertUserActiveTouch(userId, deviceId, langIso: languageIso, token: token);

    return _completeLogin(userId, token);
  }
  ///---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> loginByEmail(GraphHandlerWrap wrapper) async {
    final js = wrapper.bodyJSON;

    final email = js['email'];
    final deviceId = js[Keys.deviceId];
    final languageIso = js[Keys.languageIso];
    final appName = js[Keys.appName];


    //final countryCode = CountryModel.getCountryCodeByIso(countryIso);
    final userType = UserTypeModel.getUserTypeNumByAppName(appName);
    final userId = await UserEmailDb.getUserIdByEmail(userType, email);

    if (userId == null) {
      return GraphHandler.generateResultError(HttpCodes.error_userNotFound);
    }

    //final userName = await UserNameModelDb.getUserNameByUserId(userId);

    js[Keys.userId] = userId;
    /*final hashPassword = js['hash_password']?? '-';

    final userNameModel = await UserNameModelDb.fetchMapBy(userName, hashPassword);

    if (userNameModel == null) {
      return GraphHandler.generateResultError(HttpCodes.error_userNamePassIncorrect);
    }*/

    if (await UserModelDb.isDeletedUser(userId)) {
      return GraphHandler.generateResultError(HttpCodes.error_userIsBlocked);
    }

    /*if (!(await UserModelDb.checkUserIsMatchWithApp(userId, appName))) {
      return GraphHandler.generateResultError(HttpCodes.error_userNamePassIncorrect);
    }*/

    if (await UserBlockListModelDb.isBlockedUser(userId)) {
      return GraphHandler.generateResultError(HttpCodes.error_userIsBlocked);
    }

    //.......upsert device id........................
    final deviceCaller = DeviceCellarModelDb.fromMap(js);
    await DeviceCellarModelDb.upsertModel(deviceCaller);
    //.......upsert place........................
    var userPlace = UserPlaceModelDb.fromMap(js);
    await UserPlaceModelDb.upsertModel(userPlace);
    //...............................................
    final token = generateToken();
    await UserConnectionModelDb.upsertUserActiveTouch(userId, deviceId, langIso: languageIso, token: token);

    return _completeLogin(userId, token);
  }
  ///---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> loginAdmin(GraphHandlerWrap wrapper) async {
    final js = wrapper.bodyJSON;

    final userName = js[Keys.userName];
    final password = js[Keys.password];
    final appName = js[Keys.appName];
    final deviceId = js[Keys.deviceId];
    final languageIso = js[Keys.languageIso];

    final userType = UserTypeModel.getUserTypeNumByAppName(appName);
    final isAdmin = await UserNameModelDb.isAdmin(userName, password);

    if (!isAdmin || userType != UserTypeModel.managerUserTypeNumber) {
      return GraphHandler.generateResultError(HttpCodes.error_userNamePassIncorrect);
    }

    js[Keys.userId] = PublicAccess.adminUserId;
    //.......upsert device id........................
    final deviceCaller = DeviceCellarModelDb.fromMap(js);
    await DeviceCellarModelDb.upsertModel(deviceCaller);
    //.......upsert place........................
    var userPlace = UserPlaceModelDb.fromMap(js);
    await UserPlaceModelDb.upsertModel(userPlace);
    //...............................................
    final token = generateToken();
    await UserConnectionModelDb.upsertUserActiveTouch(PublicAccess.adminUserId, deviceId, langIso: languageIso, token: token);

    return _completeLogin(PublicAccess.adminUserId, token);
  }
  ///---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> _completeLogin(int userId, String token) async {
    final res = await CommonMethods.getUserLoginInfo(userId, false);

    res[Keys.status] = Keys.ok;
    res[Keys.token] = {Keys.token: token};

    return res;
  }
}