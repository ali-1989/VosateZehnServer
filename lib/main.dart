import 'dart:async';
import 'dart:io';
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/database/psql2.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/logger/logger.dart';
import 'package:assistance_kit/net/netHelper.dart';
import 'package:assistance_kit/api/system.dart';
import 'package:vosate_zehn_server/app/cronAssistance.dart';
import 'package:vosate_zehn_server/app/pathNs.dart';
import 'package:vosate_zehn_server/constants.dart';
import 'package:vosate_zehn_server/database/databaseNs.dart';
import 'package:vosate_zehn_server/models/countryModel.dart';
import 'package:vosate_zehn_server/models/currencyModel.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/commonMethods.dart';
import 'package:vosate_zehn_server/rest_api/searchFilterTool.dart';
import 'package:vosate_zehn_server/rest_api/serverNs.dart';
import 'package:vosate_zehn_server/rest_api/statisticsApis.dart';
import 'package:vosate_zehn_server/webSocket/wsServerNs.dart';
import 'package:vosate_zehn_server/webSite/webNs.dart';

// db[bigint]   == dart[int]
// db[numeric]  == dart[bigint]


void main(List<String> arguments) async {
  await runZonedGuarded(() async {
    try{
      PathsNs.init();
      PublicAccess.logger = Logger(PathsNs.getLogPath());
      await PublicAccess.logger.isPrepare();

      mainApp();
    }
    catch (e){
      final finder = Generator.generateIntId(5);
      PublicAccess.logger.logToAll('UNHANDLED EXCEPTION [finder: $finder]:: $e');
      PublicAccess.sendReportToDeveloper('unhandled exception_$finder[${Constants.appName}]');
    }
  }, zonedGuardedCatch);
}

void mainApp() async {
  PublicAccess.setDomain();

  var startInfo = '''
    ====================================================================================
    ==== Name: ${Constants.serverName}
    ==== Ver: ${Constants.serverVersion}
    ====================================================================================
    start at: ${DateTime.now().toUtc()}  UTC | ${DateTime.now()}  Local
    execute path: ${PathsNs.getExecutePath()}
    current path: ${PathsNs.getCurrentPath()}
    Dart path: ${Platform.executable}
    Process: ${Platform.numberOfProcessors}
    OS: ${Platform.operatingSystem}  (${Platform.operatingSystemVersion})
    Locale: ${Platform.localeName}
    Domain: ${PublicAccess.domain}
    ports:  http > ${Constants.port}  |  WS > ${Constants.wsPort}
    IPs: ${await NetHelper.getIps()}
    *ram*
    #######################################################################''';

  if (System.isLinux()) {
    MemoryInfo.initial();
    var ramInfo = 'RAM:  all: ${MemoryInfo.mem_total_mb} MB,   free: ${MemoryInfo.mem_free_mb} MB';
    ramInfo += '\n    SWAP:  all: ${MemoryInfo.swap_total_mb} MB,   free: ${MemoryInfo.swap_free_mb} MB';
    startInfo = startInfo.replaceFirst(r'*ram*', ramInfo);
  }
  else {
    startInfo = startInfo.replaceFirst('*ram*', '');
  }

  // ignore: unawaited_futures
  PublicAccess.logger.logToAll(startInfo);

  //PublicAccess.psql = Psql();
  //PublicAccess.psql.open(dbName: Constants.dbName, user: Constants.dbUserName, pass: Constants.dbPassword);

  PublicAccess.psql2 = Psql2();
  await PublicAccess.psql2.open(dbName: Constants.dbName, user: Constants.dbUserName, pass: Constants.dbPassword);

  await DatabaseNs.initial();

  final countryJs = JsonHelper.jsonToMap<String, dynamic>(await PublicAccess.loadAssets('countries.json'))!;
  CountryModel.countries = countryJs;
  CurrencyModel.countries = countryJs;

  PublicAccess.server = ServerNs.prepareServer();
  await PublicAccess.server.listen(Constants.port);

  PublicAccess.wsServer = WsServerNs.prepareWsServer();
  await PublicAccess.wsServer.listen(Constants.wsPort);

  PublicAccess.webServer = WebNs.prepareServer();
  await PublicAccess.webServer.listen(80);


  CronAssistance.startCronJobs();

  // ignore: unawaited_futures
  PublicAccess.logger.logToAll('-------------| All things is Ok');
  codes();
}
///==============================================================================================
void zonedGuardedCatch(error, sTrace) {
  final finder = Generator.generateIntId(5);
  var txt = 'ZONED-GUARDED CAUGHT AN ERROR [finder: $finder]:: ${error.toString()}';

  if(PublicAccess.isReleaseMode()) {
    txt += '\n STACK TRACE:: $sTrace';
  }

  txt += '\n**************************************** [END ZONED-GUARDED]';
  PublicAccess.logger.logToAll(txt);
  PublicAccess.sendReportToDeveloper('zonedGuardedCatch_$finder[${Constants.appName}]');

  if(!PublicAccess.isReleaseMode()) {
    throw error;
  }
}
///==============================================================================================
void codes() async {
  //DatabaseAlters.simulate_addTicketMessage(ticketIds: [102,103,105]);
  //FakeAndHack.simulate_addTicketWithMessage(102, 102);

  /*final patch = 16;
  final minor = 20;
  final major = 50;

  print(major *10000 + minor *100 + patch);*/
}








/*
String text = stdin.readLineSync().toLowerCase();
  String capitalize(Match m) => m[0].substring(0, 1).toUpperCase() + m[0].substring(1);
  String skip(String s) => "";
  prin(text.splitMapJoin(new RegExp(r'[a-z]+'), onMatch: capitalize, onNonMatch: skip));
 */