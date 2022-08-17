import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/publicAccess.dart';

class DatabaseAlters {
  DatabaseAlters._();

  static Future fireBeforeDatabase() async {
    final result = await PublicAccess.psql2.getColumsName(DbNames.T_SubBucket);

    if(result == null || result.isEmpty){
      return;
    }

    var found = false;

    for(final k in result.toList()){
      if(k[0] == 'cover_id'){
        found = true;
        break;
      }
    }

    if(!found) {
      await PublicAccess.psql2.deleteTableCascade(DbNames.T_SubBucket);
    }
  }

  static Future fireAfterDatabase() async {
    //test();
  }

  static Future test(){
    var q = '''
    DO \$\$ BEGIN
      ALTER TABLE #tb ADD COLUMN receive_program_date TIMESTAMP DEFAULT NULL;
     EXCEPTION WHEN others THEN
      IF SQLSTATE = '42701' THEN null;
      ELSE RAISE EXCEPTION '> % , %', SQLERRM, SQLSTATE;
      END IF;
     END \$\$;      
    '''
    .replaceFirst('#tb', DbNames.T_BadWords);

    return PublicAccess.psql2.queryCall(q);
  }


}