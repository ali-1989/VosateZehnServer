import 'dart:io';
import 'package:assistance_kit/cronJob/cronJob.dart';
import 'package:assistance_kit/cronJob/job.dart';
import 'package:assistance_kit/extensions.dart';
import 'package:assistance_kit/api/system.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:assistance_kit/dateSection/ADateStructure.dart';
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/api/helpers/fileHelper.dart';
import 'package:assistance_kit/api/helpers/pathHelper.dart';
import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:assistance_kit/api/logger/logger.dart';
import 'package:assistance_kit/shellAssistance.dart';
import 'package:vosate_zehn_server/app/pathNs.dart';
import 'package:vosate_zehn_server/constants.dart';
import 'package:vosate_zehn_server/publicAccess.dart';

class CronAssistance {
  CronAssistance._();
  static int OneMin = 1000 * 60;
  static int OneHour = 1000 * 60 * 60;

  //------------------------------------------------------------------------------------
  static JobTask jFun_deleteJunkFile = JobTask()..call = () async {
    final query = '''SELECT * FROM ${DbNames.T_CandidateToDelete}
     WHERE (register_date + interval '1 hour') < (now() at time zone 'utc')::timestamp; ''';

    final cursor = await PublicAccess.psql2.queryCall(query);
    var now = DateTime.now().toUtc().millisecondsSinceEpoch;

    if (cursor != null && cursor.isNotEmpty) {
      final basePath = PathsNs.getCurrentPath();

      for (var i = 0; i < cursor.length; i++) {
        try {
          final rMap = cursor.elementAt(i).toMap();

          final path = UrlHelper.decodePathFromDataBase(rMap['Path'.L]);
          var f = File(PathHelper.normalize(basePath + PathHelper.getSeparator() + path!)!);

          if (!f.existsSync()) {
            f = File(path);
          }

          if (!f.existsSync()) {
            final q2 = 'DELETE FROM ${DbNames.T_CandidateToDelete} WHERE id = ${rMap['id']};';
            await PublicAccess.psql2.execution(q2);

            continue;
          }

          final last = FileHelper.lastModifiedSync(f.path).millisecondsSinceEpoch;

          if (last < (now - OneHour)) {
            FileHelper.deleteSync(f.path);

            if (!f.existsSync()) {
              final q2 = 'DELETE FROM ${DbNames.T_CandidateToDelete} WHERE Id = ${rMap['id']};';
              await PublicAccess.psql2.execution(q2);
            }
          }
        }
        catch (e) {/**/}
        //---- temp dir ----------------------------------------------------
        final list = await FileHelper.getDirFiles(PathsNs.getTempDir());

        now = DateTime.now().millisecondsSinceEpoch;

        for (final f in list) {
          try {
            final last = FileHelper.lastModifiedSync(f).millisecondsSinceEpoch;

            if (last < now - OneHour) {
              FileHelper.deleteSync(f);
            }
          }
          catch (e) {/**/}
        }
      }
    }
  };
  //------------------------------------------------------------------------------------
  static JobTask jFun_clearSystemCache = JobTask()..call = () async {
    /// must set permission: (chmod +x ClearBuffer.sh)
    //String res = ShellAssistance.shell(".", "ClearBuffer.sh", String[]{});
    final res = await ShellAssistance.shell('${PathsNs.getCurrentPath()}/ClearBuffer.sh', []);

    final now = DateTime.now().toUtc();
    final out = res.stdout;
    Logger.L.logToAll('>>> cleared SystemCache[${now.toString()}]: $out ');
  };
  //------------------------------------------------------------------------------------
  static JobTask jFun_backupDB = JobTask()..call = () {
    try {
      final d = GregorianDate();
      d.moveLocalToUTC();

      final p = PathsNs.getBackupPath() + PathHelper.getSeparator() + Constants.dbName;
      // pg_dump -U aliAdmin -f /backup/file.sql DbName
      final args = ['-U',
        Constants.dbUserName,
        '-f',
        '${p}__${d.format('YYYY-MM-DD@HH-mm_UTC', 'en')}.sql'
        , Constants.dbName
     ];

      ShellAssistance.shell('pg_dump', args);
    }
    catch (e) {
      final code = Generator.generateKey(5);
      Logger.L.logToAll('CronBackup: $code _ $e');
    }
  };
  //------------------------------------------------------------------------------------
  static JobTask jFun_vacuumDB = JobTask()..call = () {
    try {
      final q = 'VACUUM(FULL);'; // VACUUM(FULL, ANALYZE)
      PublicAccess.psql2.execution(q);
    }
    catch (e) {
      final code = Generator.generateKey(5);
      Logger.L.logToAll('CronVacuum: $code _ $e');
    }
  };
  //------------------------------------------------------------------------------------
  /*static JobTask jFun_deleteNotVerify = JobTask()..call = () {
    PublicAccess.psql2.delete(DbNames.T_RegisteringUser, " (register_date + interval '3 day') < (now() at time zone 'utc') ;");
  };*/
  //------------------------------------------------------------------------------------
  /*static JobTask jFun_checkUnUsedSockets = JobTask()..call = () {
    try {
      ServerNS.httpServer.cleanLongConnections();
      ServerNS.WsServer.cleanLoseConnections();
    }
    catch (e) {
      final code = Generator.generateKey(5);
      Logger.L.logToAll('CronCheckClosedWs: ${code}_$e');
    }
  };*/
  //------------------------------------------------------------------------------------
  static JobTask jFun_checkAllDbWsSessions = JobTask()..call = (){
    try {
      //checkWsSessionOnDB();
      checkUserOnLineDB();
    }
    catch (e) {
      final code = Generator.generateKey(5);
      Logger.L.logToAll('Cron_checkAllDbWsSessions:' + code);
    }
  };

  /*static void checkWsSessionOnDB() {
    final q = 'SELECT * FROM \"TT1\" WHERE LastTouch < ##1 AND WebSocketId IS NOT NULL;';
  }*/

  static void checkUserOnLineDB() {
    //todo  check in T_UserConnections if lastTouch > 10 min: set login to false
    //String q = 'SELECT * FROM \"TT1\" WHERE LastTouch < ##1 AND WebSocketId IS NOT NULL;';
  }
  ///===================================================================================================
  static void startCronJobs() {
    var tehranTZ = 'Asia/Tehran';

    var deleteJunk = CronJob.createExactCronJob(tehranTZ, 2, 40, OneHour * 24, CronAssistance.jFun_deleteJunkFile, true);
    deleteJunk.start();

    var vacuumDBJob = CronJob.createExactCronJob(tehranTZ, 3, 10, OneHour * 24, CronAssistance.jFun_vacuumDB, false);
    vacuumDBJob.start();

    var backupDBJob = CronJob.createExactCronJob(tehranTZ, 3, 30, OneHour * 24, CronAssistance.jFun_backupDB, false);
    backupDBJob.start();

    var checkAllWsSession = CronJob.createCronJob(OneHour * 2, CronAssistance.jFun_checkAllDbWsSessions);
    checkAllWsSession.start();

    final clearSystemCache = CronJob.createCronJob(OneHour * 8, CronAssistance.jFun_clearSystemCache);

    if (System.isLinux()) {
      clearSystemCache.start();
    }

    //final deleteNotVerifyUser = CronJob.createCronJob(OneHour * 24, CronAssistance.jFun_deleteNotVerify);
    //deleteNotVerifyUser.start();
  }
}