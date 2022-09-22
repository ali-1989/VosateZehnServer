import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:vosate_zehn_server/rest_api/AppHttpDio.dart';
import 'package:dio/dio.dart';

class SmsKaveh {
  SmsKaveh._();

  static String apiKey = '4D57474F596E425570704F64584661726B45587457344665565A784B424C68686C775577413473675758773D';
  static String smsUrl = 'https://api.kavenegar.com/v1/{API-KEY}/sms/send.json';
  static String verifyUrl = 'https://api.kavenegar.com/v1/{API-KEY}/verify/lookup.json';

  static void init(){
    smsUrl = smsUrl.replaceFirst(RegExp(r'\{API-KEY\}'), apiKey);
    verifyUrl = verifyUrl.replaceFirst(RegExp(r'\{API-KEY\}'), apiKey);
  }

  static Future sendOtpPost(String receiver, String token) async{
    final js = {};
    js['receptor'] = receiver;
    js['token'] = token;
    js['template'] = 'verify';

    final httpItem = HttpItem();
    httpItem.method = 'POST';
    httpItem.fullUrl = verifyUrl;
    httpItem.setBody(JsonHelper.mapToJson(js));

    final res = AppHttpDio.send(httpItem);

    return res.response.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          final js = JsonHelper.jsonToMap(value.data)!;
          final result = js['return'];
          final status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));
        }
      }
      else {
        return false;
      }
    });
  }

  static Future sendOtpGet(String receiver, String token) async{
    var js = {
      'receptor': receiver,
      'token': token,
      'template': 'verify',
    };

    var httpItem = HttpItem();
    httpItem.method = 'GET';
    httpItem.fullUrl = verifyUrl;
    httpItem.addPathQueryAsMap(js);

    var res = AppHttpDio.send(httpItem);

    return res.response.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          var js = JsonHelper.jsonToMap(value.data)!;
          var result = js['return'];
          var status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));
        }
      }
      else {
        return false;
      }
    });
  }

  static Future sendSmsGet(String receiver, String text) async{
    var js = {
      'receptor': receiver,
      'message': text,
    };

    var httpItem = HttpItem();
    httpItem.method = 'GET';
    httpItem.fullUrl = smsUrl;
    httpItem.addPathQueryAsMap(js);

    var res = AppHttpDio.send(httpItem);

    return res.response.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          var js = JsonHelper.jsonToMap<String, dynamic>(value.data)!;
          var result = js['return'];
          var status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));
        }
      }
      else {
        return false;
      }
    });
  }

  static Future sendSmsPost(String receiver, String text) async{
    var js = {
      'receptor': receiver,
      'message': text,
    };

    var httpItem = HttpItem();
    httpItem.method = 'POST';
    httpItem.fullUrl = smsUrl;
    httpItem.setBodyJson(js);

    var res = AppHttpDio.send(httpItem);

    return res.response.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          var js = JsonHelper.jsonToMap(value.data)!;
          var result = js['return'];
          var status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));
        }
      }
      else {
        return false;
      }
    });
  }
}