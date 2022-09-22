import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/database/psql.dart';
import 'package:assistance_kit/database/psql2.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:assistance_kit/api/logger/logger.dart';
import 'package:vosate_zehn_server/services/sms_0098.dart';
import 'package:vosate_zehn_server/app/pathNs.dart';
import 'package:vosate_zehn_server/constants.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';

class PublicAccess {
  PublicAccess._();

  static late Alfred server;
  static late Alfred wsServer;
  static late Alfred webServer;
  static late Psql psql;
  static late Psql2 psql2;
  static Map<WebSocket, String> webSockets = <WebSocket, String>{};
  static late Logger logger;
  static final developerMobileNumber = '09139277303';
  static final adminMobileNumber = '09364299984';
  static int systemUserId = 90;
  static int adminUserId = 89;
  static String otpHackCode = '6800';
  static String domain = 'http://vosatezehn.com:${Constants.port}';

  static bool isReleaseMode() {
    var isInReleaseMode = true;

    bool fn(){
      isInReleaseMode = false;
      return true;
    }

    assert(fn(), 'isInDebugMode');
    return isInReleaseMode;

    //return const bool.fromEnvironment('dart.vm.product');
  }

  static void setDomain() {
    if(isReleaseMode()) {
      domain = 'http://vosatezehn.com:${Constants.port}';
    }
    else {
      domain = 'http://192.168.43.140:${Constants.port}'; //1.103 , 43.140
    }
  }

  static void logInDebug(dynamic txt) {
    if(!isReleaseMode()) {
      PublicAccess.logger.logToAll(txt);
    }
  }

  static String getVerifySmsTemplate() {
    return '${Constants.appName} code:\n';
  }

  static Future<dynamic> loadAssets(String name, {bool asString = true}) async {
    var path = PathsNs.getAssetsDir() + Platform.pathSeparator + name;

    var file = File(path);
    var exist = await file.exists();

    if(exist){
      if(asString) {
        return file.readAsString();
      }
      else {
        return file.readAsBytes();
      }
    }
  }

  static void insertEncodedPathToJunkFile(String path) {
    psql2.insertIgnore(DbNames.T_CandidateToDelete, ['path'], [path]);
  }

  static void sendReportToDeveloper(String report) {
    try {
      report = TextHelper.subByCharCountSafe(report, 120);
      Sms0098.sendSms(developerMobileNumber, report);
    }
    catch (e) {
      //Main.logToAll("!!! sendReportToDeveloper: " + e.toString(), true);
    }
  }

  static void sendReportToAdmin(String report) {
    try {
      report = TextHelper.subByCharCountSafe(report, 120);
      Sms0098.sendSms(adminMobileNumber, report);
    }
    catch (e) {
      //Main.logToAll("!!! sendReportToDeveloper: " + e.toString(), true);
    }
  }
}