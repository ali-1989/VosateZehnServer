import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/publicAccess.dart';

class StatisticsApis {
  StatisticsApis._();

  static Future<Map<String, dynamic>> getUserStatistics() async {
    final res = <String, dynamic>{};

    res['all_users'] = await getUsersCount();
    res['users_15_min'] = await getUsersOnlineLast15min();
    res['users_24_hor'] = await getUsersOnlineLast24hor();
    res['male_users'] = await getUsersMaleGender();
    res['female_users'] = await getUsersFeMaleGender();
    res['average_age'] = await getUsersAverageAge();
    res['register_with_email'] = await getUsersRegisterWithEmail();
    res['register_last_week'] = await getLastWeekUsersRegister();

    return res;
  }

  static Future<int> getUsersCount() async {
    var query = '''
    SELECT count(user_id) as count FROM #tb;
    ''';

    query = query.replaceFirst('#tb', DbNames.T_Users);

    final cursor = await PublicAccess.psql2.getColumn(query, 'count');

    if (cursor == null) {
      return 0;
    }

    return cursor as int;
  }

  static Future<int> getUsersOnlineLast15min() async {
    var query = '''
    SELECT count(user_id) as count FROM #tb WHERE (#w);
    ''';

    /// websocket_id is not null OR
    final where = '''
    (is_login = true)
      and last_touch >= (now() ) - interval '15 minutes'
    ''';
    query = query.replaceFirst('#tb', DbNames.T_UserConnections);
    query = query.replaceFirst('#w', where);

    final cursor = await PublicAccess.psql2.queryCall(query);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<int> getUsersOnlineLast24hor() async {
    var query = '''
    SELECT count(user_id) as count FROM #tb WHERE (#w);
    ''';

    /// websocket_id is not null OR
    final where = '''
    (is_login = true)
      and last_touch >= (now() ) - interval '24 hours'
    ''';
    query = query.replaceFirst('#tb', DbNames.T_UserConnections);
    query = query.replaceFirst('#w', where);

    final cursor = await PublicAccess.psql2.queryCall(query);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<int> getUsersMaleGender() async {
    var query = '''
    SELECT count(user_id) as count FROM #tb WHERE (#w);
    ''';

    final where = '''
    sex = 1
    ''';

    query = query.replaceFirst('#tb', DbNames.T_Users);
    query = query.replaceFirst('#w', where);

    final cursor = await PublicAccess.psql2.queryCall(query);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<int> getUsersFeMaleGender() async {
    var query = '''
    SELECT count(user_id) as count FROM #tb WHERE (#w);
    ''';

    final where = '''
    sex = 2
    ''';

    query = query.replaceFirst('#tb', DbNames.T_Users);
    query = query.replaceFirst('#w', where);

    final cursor = await PublicAccess.psql2.queryCall(query);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<double> getUsersAverageAge() async {
    var query = '''
    select avg((SELECT extract(year FROM age(birthdate)))) from #tb;
    ''';

    query = query.replaceFirst('#tb', DbNames.T_Users);

    final cursor = await PublicAccess.psql2.queryCall(query);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    final avg = cursor.elementAt(0).toList()[0];
    return avg ?? 0.0;
  }

  static Future<int> getOlderAge() async {
    var query = '''
    SELECT extract(year FROM age(min(birthdate))) from #tb;
    ''';

    query = query.replaceFirst('#tb', DbNames.T_Users);

    final cursor = await PublicAccess.psql2.queryCall(query);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    final avg = cursor.elementAt(0).toList()[0];
    return avg ?? 0.0;
  }

  static Future<int> getUsersRegisterWithEmail() async {
    var query = '''
    SELECT count(user_id) as count FROM #tb;
    ''';

    query = query.replaceFirst('#tb', DbNames.T_UserEmail);

    final cursor = await PublicAccess.psql2.getColumn(query, 'count');

    if (cursor == null) {
      return 0;
    }

    return cursor as int;
  }

  static Future<List<int>> getLastWeekUsersRegister() async {
    var query = '''
    SELECT count(user_id) AS count FROM #tb WHERE register_date >= CURRENT_DATE - interval '1 day'
UNION all
SELECT count(user_id) AS count FROM #tb WHERE register_date BETWEEN CURRENT_DATE - interval '2 days' AND CURRENT_DATE - interval '1 day'
UNION all
SELECT count(user_id) AS count FROM #tb WHERE register_date BETWEEN CURRENT_DATE - interval '3 days' AND CURRENT_DATE - interval '2 days'
UNION all
SELECT count(user_id) AS count FROM #tb WHERE register_date BETWEEN CURRENT_DATE - interval '4 days' AND CURRENT_DATE - interval '3 days'
UNION all
SELECT count(user_id) AS count FROM #tb WHERE register_date BETWEEN CURRENT_DATE - interval '5 days' AND CURRENT_DATE - interval '4 days'
UNION all
SELECT count(user_id) AS count FROM #tb WHERE register_date BETWEEN CURRENT_DATE - interval '6 days' AND CURRENT_DATE - interval '5 days'
UNION all
SELECT count(user_id) AS count FROM #tb WHERE register_date BETWEEN CURRENT_DATE - interval '7 days' AND CURRENT_DATE - interval '6 days';
    ''';

    query = query.replaceAll('#tb', DbNames.T_Users);

    final cursor = await PublicAccess.psql2.queryCall(query);

    if (cursor == null || cursor.isEmpty) {
      return [];
    }

    return cursor.map((e) => e.toList()[0] as int).toList();
  }
}