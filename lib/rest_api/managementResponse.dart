import 'dart:async';
import 'package:alfred/alfred.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/httpCodes.dart';
import 'package:vosate_zehn_server/rest_api/wsServerNs.dart';

class ManagementResponse {
  ManagementResponse._();

  static Map<String, dynamic> generateResultOk() {
    return HttpCodes.generateResultOk();
  }

  static Map<String, dynamic> generateResultError(int causeCode, {String? cause}) {
    return HttpCodes.generateJsonError(causeCode, cause: cause);
  }

  static Map<String, dynamic> generateResultBy(String result) {
    return HttpCodes.generateResultJson(result);
  }
  //===============================================================================================
  static FutureOr response(HttpRequest req, HttpResponse res) async {
    var bJSON = await req.bodyAsJsonMap;
    String request = bJSON[Keys.requestZone]?? '';

    if(request == 'set_domain') {
      return setDomain(req, bJSON);
    }

    if(request == 'is_ws_online') {
      final userId = bJSON[Keys.userId]?? 0;
      return await isWsOnline(userId);
    }
  }
  ///----------------------------------------------------------------------------------------------------------
  static dynamic setDomain(HttpRequest req, Map<String, dynamic> json) async {
    var adr = json['domain_address'];
    PublicAccess.domain = adr;

    return generateResultOk();
  }

  static Future<String> isWsOnline(int userId) async {
    final list = await WsServerNs.getAllUserSessionsIfLogin(userId);
    var res = '';

    for(var u in list) {
      res += 'userId: ${u.userId},   deviceId: ${u.deviceId},    lastTouch: ${u.lastTouch} \n';
    }

    return res;
  }
}