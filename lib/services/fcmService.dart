
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/cronJob/job.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/AppHttpDio.dart';

class FcmService {
  FcmService._();

  static Future<bool> sendNotificationTopic(String topic, String? title, String text, Duration? expire) async {
    final js = {};
    js['to'] = '/topics/$topic';
    js['notification'] = {
      'title' : title,
      'body' : text,
    };

    js['apns'] = {};
    js['apns']['headers'] = {};

    js['android'] = {};

    if(expire != null){
      js['android']['ttl'] = '${expire.inSeconds}s';

      var ex = DateTime.now().toUtc();
      ex = ex.add(expire);
      js['apns']['headers']['apns-expiration'] = '${ex.millisecondsSinceEpoch/1000}'; //seconds of utc
    };

    final headers = <String, String>{};
    headers['Content-Type'] = 'application/json';
    headers['Authorization'] = 'key=AAAADCWdWB4:APA91bF7iFQi6Gphhdx_bllENIX28zdcqgJzOPdA11KC2NEVXWsF3Evf1pFkPKpsaYay_xf7nK60sgy_Tsf_kXfq1fR7b8WkkRctwmd7f5TfhPJj6eJBraTu8Y2pbIEMX3mT3W9b2F_y';

    final requester = HttpItem();
    requester.method = 'POST';
    requester.fullUrl = 'https://fcm.googleapis.com/fcm/send';
    requester.body = JsonHelper.mapToJson(js);
    requester.headers = headers;

    final send = AppHttpDio.send(requester);

    final res = await send.response;

    if(res == null){
      return false;
    }

    if(res.statusCode == 200){
      PublicAccess.logger.logToAll('@@@@@@@@@@@@@@ res  ${res.data}');
      return true;
    }

    return false;
  }
  //--------------------------------------------------------------------------------
  static JobTask jFun_DailyText = JobTask()..call = () async {
    PublicAccess.logger.logToAll('@@@@@@@@@@@@@@ jFun_DailyText  ${DateTime.now()}');

    try {
      final q = '''
        SELECT * FROM #tb WHERE date::date = (now())::date;
      '''.replaceFirst('#tb', DbNames.T_dailyText);

      final db = await PublicAccess.psql2.queryCall(q);

      if(db == null || db.isEmpty){
        return;
      }

      for(final k in db) {
        final r = k.toMap();
        // ignore: unawaited_futures
        sendNotificationTopic('daily_text', null, r['text'], Duration(days: 1));
      }
    }
    catch (e) {
      final code = Generator.generateKey(5);
      PublicAccess.logger.logToAll('EEE-> DailyText: $code _ $e');
    }
  };
}