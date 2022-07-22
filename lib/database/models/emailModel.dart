import 'package:vosate_zehn_server/database/models/dbModel.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/publicAccess.dart';

class UserEmailDb extends DbModel {
  late int user_id;
  int user_type = 1;
  String? email;

  UserEmailDb();

  static final String QTbl_userEmail = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      user_type SmallInt NOT NULL DEFAULT 1,
      email VARCHAR(120),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE)
      PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserEmail)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QIdx_userEmail$user_id = '''
		CREATE INDEX IF NOT EXISTS #tb_user_id_idx ON #tb
		USING BTREE (user_id);
		'''
      .replaceAll('#tb', DbNames.T_UserEmail);

  static final String QIdx_userEmail$email = '''
		CREATE INDEX IF NOT EXISTS #tb_user_email_idx ON #tb
		USING BTREE (email);
		'''
      .replaceAll('#tb', DbNames.T_UserEmail);

  static final String QTbl_userEmail$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserEmail);

  static final String QTbl_userEmail$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserEmail);

  static final String QAltUk1_userEmail$p1 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p1
 	    ADD CONSTRAINT uk1_#tb_p1 UNIQUE (user_type, email);
			 EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
			 ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserEmail);

  static final String QAltUk1_userEmail$p2 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p2
 	    ADD CONSTRAINT uk1_#tb_p2 UNIQUE (user_type, email);
			 EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
			 ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserEmail);


  @override
  UserEmailDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    email = map['email'];
    user_type = map[Keys.userType]?? 1;
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map['email'] = email;
    map[Keys.userType] = user_type;

    return map;
  }

  static Future<bool> existThisEmail(int userType, String email) async {
    final where = " user_type = $userType AND email = '$email'";

    return (await PublicAccess.psql2.exist(DbNames.T_UserEmail, where));
  }

  static Future<int?> getUserId(int userType, String email) async {
    final query = '''SELECT user_id FROM ${DbNames.T_UserEmail}
      WHERE user_type = $userType AND email = '$email';''';

    return (await PublicAccess.psql2.getColumn(query, Keys.userId));
  }

  static Future<bool> insertModel(UserEmailDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final x = await PublicAccess.psql2.insertKv(DbNames.T_UserEmail, userMap);

    return !(x == null || x < 1);
  }

  static Future<dynamic> getUserIdByEmail(int userType, String email) async {
    final query = '''SELECT user_id FROM ${DbNames.T_UserEmail} 
      WHERE user_type = $userType AND email = '$email'; ''';

    return PublicAccess.psql2.getColumn(query, Keys.userId);
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = 'SELECT * FROM ${DbNames.T_UserEmail} WHERE user_id = $userId;';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;
    //final res = MobileNumberDbModel.fromMap(m as Map<String, dynamic>);
    //return res.toMap();
  }
}
