import 'dart:async';
import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/webSite/webFileHandler.dart';
import 'package:vosate_zehn_server/webSite/webHandler.dart';

class WebNs {

  static Alfred prepareServer(){
    var server = Alfred(logLevel: LogType.info);

    //server.all('/*', (req, res) {
    //   PublicAccess.logInDebug('====== method: ${req.method}, uri: ${req.uri}');
    //});


    //server.all('/echo', echoResponse);
    server.get('/admin/*', WebFileHandler.fileResponse);
    server.get('/admin/*', WebHandler.adminResponse);
    server.get('/*', WebFileHandler.fileResponse);
    server.get('/*', WebHandler.publicResponse);

    server.logWriter = (fn, type){
      var res = fn.call();

      if(type == LogType.info){
        if(res?.startsWith(RegExp('(GET|POST|PUT|OPTION)\.*'))?? false) {
          PublicAccess.logInDebug(res);
        }
      }
      else if(type == LogType.error){
        PublicAccess.logInDebug(res);
      }

      if((res is String) && res == 'Web Response sent to browser') {
        PublicAccess.logInDebug('>>>>>>>>>>>>>>>>>>>>>>>>>>> $res');
      }
    };

    server.onInternalError = (HttpRequest req, HttpResponse res){
      PublicAccess.logger.logToAll('>>> Web Internal Error: ${req.method}, ${req.uri}');

      //get error: res.statusCode = HttpStatus.internalServerError;// 500
      return {'message': 'Internal Error, not handled web'};
    };

    server.onNotFound = (HttpRequest req, HttpResponse res) {
      PublicAccess.logger.logToAll('>>> Web Error [NotFound] uri: ${req.uri} ');

      res.statusCode = HttpStatus.notFound;// 404
      return {'message': 'not found'};
    };

    return server;
    //await server.listen(6060);
  }
  ///------------------------------------------------------------------------------------------------
  static FutureOr echoResponse(HttpRequest req, HttpResponse res) async {
    if(req.method.toLowerCase() == 'get'){
      return 'Echo [GET]: ${req.uri}';
    }

    return 'Echo [POST|PUT]: ${(await req.body)}';
  }
}