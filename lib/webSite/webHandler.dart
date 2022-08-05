
import 'dart:async';
import 'dart:io';

import 'package:assistance_kit/api/helpers/pathHelper.dart';
import 'package:assistance_kit/dateFormatter/date_format.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/fileHandler.dart';

class WebHandler {
  WebHandler._();

  static final adminIndexPage = PathHelper.resolvePath(FileHandler.staticPath + 'www/admin/index.html')!;
  static final publicIndexPage = PathHelper.resolvePath(FileHandler.staticPath + 'www/public/index.html')!;

  static FutureOr adminResponse(HttpRequest req, HttpResponse res) async {

    try{
      //final wrapper = GraphHandlerWrap();

      final file = File(adminIndexPage);
      final exist = await file.exists();

      if(exist) {
        var modifier = await file.lastModified();
        modifier = modifier.toUtc();
        final formattedModified = formatDate(modifier, [D, ', ', d, ' ', M, ' ', yyyy, ' ', HH, ':', nn, ':', ss, ' ', z]);

        res.headers.add('Content-Type', 'text/html; charset=utf-8');
        res.headers.add('Content-Length', await file.length());
        res.headers.add('Last-Modified', formattedModified);
        return file;
      }
    }
    catch (e){
      PublicAccess.logInDebug('>>> Error in process Web: $e ');
    }
  }

  static FutureOr publicResponse(HttpRequest req, HttpResponse res) async {

    try{
      //final wrapper = GraphHandlerWrap();

      final file = File(publicIndexPage);
      final exist = await file.exists();

      if(exist) {
        var modifier = await file.lastModified();
        modifier = modifier.toUtc();
        final formattedModified = formatDate(modifier, [D, ', ', d, ' ', M, ' ', yyyy, ' ', HH, ':', nn, ':', ss, ' ', z]);

        res.headers.add('Content-Type', 'text/html; charset=utf-8');
        res.headers.add('Content-Length', await file.length());
        res.headers.add('Last-Modified', formattedModified);
        return file;
      }
    }
    catch (e){
      PublicAccess.logInDebug('>>> Error in process Web: $e ');
    }
  }
}