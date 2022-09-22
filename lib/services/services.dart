import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:vosate_zehn_server/rest_api/AppHttpDio.dart';

class Services {

  Services._();

  //   https://detectlanguage.com/
  static Future<String> detectLanguage(String text) {
    var req = HttpItem();
    req.fullUrl = 'https://ws.detectlanguage.com/0.2/detect';
    req.options.headers ??= {};
    req.options.headers!['Content-Type'] = 'application/json';
    req.options.headers!['Authorization'] = 'Bearer 8f9e191c8ee073607f9356975d92282e';
    req.method = 'POST';
    req.body = JsonHelper.mapToJson({'q': text});

    var result = AppHttpDio.send(req);

    return result.response.then((value){
      if(result.isError()){
        return 'en';
      }

      if(result.isOk && value != null){
        var js = result.getBodyAsJson();

        Map? map = js!['data'];
        List list = map?['detections']?? [];

        return list[0]?['language']?? '-';
      }

      return '--';
    });
  }
}