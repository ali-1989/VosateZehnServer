import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/publicAccess.dart';

class DatabaseAlters {
  DatabaseAlters._();

  // deprecate
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