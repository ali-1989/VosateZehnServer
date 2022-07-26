import 'package:vosate_zehn_server/database/models/dbModel.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/models/currencyModel.dart';
import 'package:vosate_zehn_server/publicAccess.dart';

class UserCurrencyModelDb extends DbModel {
  late int user_id;
  late String country_iso;
  String? currency_code;
  
  
  static final String QTbl_UserCurrency = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      country_iso varchar(3) NOT NULL,
      currency_code varchar(5) DEFAULT NULL,
      CONSTRAINT pk_#tb PRIMARY KEY (user_id),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
     )
      PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserCurrency)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QTbl_UserCurrency$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserCurrency);

  static final String QTbl_UserCurrency$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserCurrency);

  static final String crIdx_UserCurrency$country_iso = '''
      CREATE INDEX IF NOT EXISTS ${DbNames.T_UserCurrency}_country_iso_idx
      ON ${DbNames.T_UserCurrency} USING BTREE (country_iso);
      ''';


  @override
  UserCurrencyModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    country_iso = map[Keys.countryIso];
    currency_code = map['currency_code'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map[Keys.countryIso] = country_iso;
    map['currency_code'] = currency_code;

    return map;
  }

  Map<String, dynamic> toUserCurrencyJs() {
    var res = <String, dynamic>{};

    res['user_currency_js'] = CurrencyModel.getCurrencyModelByIso(country_iso).toMap();

    return res;
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = '''SELECT * FROM  ${DbNames.T_UserCurrency} WHERE user_id = $userId;''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> getUserCurrencyJs(int userId) async {
    final m = await UserCurrencyModelDb.fetchMap(userId);

    if(m == null){
      return null;
    }

    final res = UserCurrencyModelDb.fromMap(m);

    return res.toUserCurrencyJs();
  }

  static Future<bool> insertModel(UserCurrencyModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final effected = await PublicAccess.psql2.insertKv(DbNames.T_UserCurrency, userMap);

    return !(effected == null || effected < 1);
  }

  static Future<bool> upsertUserCurrency(int userId, String countryIso, String currencyCode) async{
    final value = <String, dynamic>{};
    value[Keys.userId] = userId;
    value[Keys.countryIso] = countryIso;
    value['currency_code'] = currencyCode;

    final effected = await PublicAccess.psql2.upsertWhereKv(DbNames.T_UserCurrency, value, where: ' user_id = $userId');

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

}
