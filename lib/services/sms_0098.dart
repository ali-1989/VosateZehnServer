import 'package:dio/dio.dart';
import 'package:vosate_zehn_server/rest_api/AppHttpDio.dart';

class Sms0098 {
  static String baseUrl = 'http://www.0098sms.com/sendsmslink.aspx?domain=0098&username=zsms6621&password=hamed7983';
  static String fromNumber = '3000164545';//50002203198

  Sms0098._();

  static Future<bool> sendSms(String toNumber, String text){
    final url = '$baseUrl&from=$fromNumber&to=$toNumber&text=$text';

    final httpItem = HttpItem();
    httpItem.method = 'POST';
    httpItem.fullUrl = Uri.encodeFull(url);
    httpItem.headers['Accept'] = 'application/json';

    final res = AppHttpDio.send(httpItem);

    return res.response.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          return value.statusCode == 200;
          /*final js = JsonHelper.jsonToMap(value.data)!;
          final result = js['return'];
          final status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));*/
        }
      }
      else {
        return false;
      }
    });
  }
}