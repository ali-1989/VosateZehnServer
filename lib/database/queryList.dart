import 'package:assistance_kit/api/helpers/listHelper.dart';
import 'package:assistance_kit/database/psql2.dart';
import 'package:assistance_kit/dateSection/ADateStructure.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/queryFiltering.dart';
import 'package:vosate_zehn_server/rest_api/searchFilterTool.dart';

class QueryList {
  QueryList._();

  static String getBuckets(SearchFilterTool sf){
    var q = '''SELECT * FROM #tb WHERE (#w) AND
        bucket_type = #key
        order by date DESC
        limit #lim
        ''';

    q = q.replaceFirst('#tb', DbNames.T_Bucket);
    q = q.replaceFirst('#lim', '${sf.limit}');

    var w = 'true';

    if(sf.filters['is_hide'] == null){
      w = 'is_hide = false';
    }

    if(sf.searchText != null){
      final t = '\$t\$%${sf.searchText}%\$t\$';
      w += ' AND (title like $t OR description like $t)';
    }

    if(sf.lower != null){
      w += " AND (date < '${sf.lower}'::timestamp)";
    }

    q = q.replaceFirst('#w', w);
    return q;
  }

  static String getBucketsCount(SearchFilterTool sf){
    var q = '''SELECT count(id) as count FROM #tb WHERE (#w) AND
        bucket_type = #key
        ''';

    q = q.replaceFirst('#tb', DbNames.T_Bucket);

    var w = 'true';

    if(sf.filters['is_hide'] == null){
      w = 'is_hide = false';
    }

    if(sf.searchText != null){
      final t = '\$t\$%${sf.searchText}%\$t\$';
      w += ' AND (title like $t OR description like $t)';
    }

    if(sf.lower != null){
      w += " AND (date < '${sf.lower}'::timestamp)";
    }

    q = q.replaceFirst('#w', w);
    return q;
  }

  static String getMediasByIds(){
    //, screenshot_path as screenshot_uri
    final q = '''
    With c1 AS
         (SELECT id, title, file_name, extension,
                 volume, width, height, duration,
                 date, extra, media_path as url
            FROM media
             WHERE id in (@list)
         )

  SELECT * FROM c1;
    ''';

    return q;
  }










  static String advancedUsers_q1(List<int> ids){
    var q = '''
    SELECT 
       t1.user_id, t1.user_type, t1.birthdate, t1.name,
       t1.family, t1.register_date, t1.sex, t1.is_deleted,
       t2.user_name,
       t3.phone_code, t3.mobile_number,
        t4.blocker_user_id, t4.block_date, t4.extra_js AS block_extra_js,
       t5.image_path AS profile_image_uri,
       t6.user_name as blocker_user_name,
       t7.last_touch, t7.is_any_login as is_login
    FROM Users AS t1
         INNER JOIN UserNameId AS t2 
             ON t1.user_id = t2.user_id
         LEFT JOIN MobileNumber AS t3 
             ON t1.user_id = t3.user_id AND t1.user_type = t3.user_type
         LEFT JOIN UserBlockList AS t4 
             ON t1.user_id = t4.user_id
         LEFT JOIN UserImages AS t5
                ON t1.user_id = t5.user_id AND t5.type = 1
         LEFT JOIN UserNameId AS t6
                ON t4.blocker_user_id = t6.user_id
         LEFT JOIN
            (SELECT DISTINCT ON (user_id) bool_or(is_login) OVER (PARTITION BY user_id) as is_any_login,
                                   last_touch, user_id
            FROM UserConnections ORDER BY user_id, last_touch DESC NULLS LAST) AS t7
                ON t1.user_id = t7.user_id
         

  WHERE (@searchIds) AND (@searchFilter)
  ;
    ''';
  //ORDER BY @orderBy LIMIT x

    var searchIds = 't1.user_id IN(${ListHelper.listToSequence(ids)})';
    var search = 'true';
    //var orderBy = 'register_date DESC NULLS LAST';

    q = q.replaceFirst(RegExp('@searchIds'), searchIds);
    q = q.replaceFirst(RegExp('@searchFilter'), search);
    //q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String simpleUsers_q1(FilterRequest fq){
    var q = '''
    SELECT t1.user_id, t1.user_type, t1.birthdate, t1.name, t1.family, t1.register_date
        ,t1.sex, t1.is_deleted, t2.user_name, t3.phone_code, t3.mobile_number
        ,t4.blocker_user_id, t4.block_date, t4.extra_js AS block_extra_js,t7.user_name as blocker_user_name,
        t5.last_touch, t5.is_any_login as is_login, t6.image_path AS profile_image_uri
    FROM Users AS t1
     INNER JOIN UserNameId AS t2 ON t1.user_id = t2.user_id
     LEFT JOIN MobileNumber AS t3 ON t1.user_id = t3.user_id AND t1.user_type = t3.user_type
     LEFT JOIN UserBlockList AS t4 ON t1.user_id = t4.user_id
     LEFT JOIN
        (SELECT DISTINCT ON (user_id) bool_or(is_login) OVER (PARTITION BY user_id) as is_any_login, last_touch, user_id
            FROM UserConnections ORDER BY user_id, last_touch DESC NULLS LAST) AS t5
        ON t1.user_id = t5.user_id
     LEFT JOIN UserImages AS t6 ON t1.user_id = t6.user_id AND t6.type = 1
     LEFT JOIN UserNameId AS t7 ON t4.blocker_user_id = t7.user_id
     
    WHERE t1.user_type != 2 AND (@searchAndFilter)
      ORDER BY @orderBy 
    LIMIT x OFFSET x;
    ''';

    var search = 'true';
    var orderBy = 'register_date DESC NULLS LAST';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey  == SearchKeys.userNameKey){
          search = ' t2.user_name Like $value';
        }
        else if(se.searchKey == SearchKeys.name) {
          search = ' name ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.family) {
          search = ' family ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.mobile) {
          search = ' mobile_number Like $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND blocker_user_id IS NOT null';
          }
          else {
            search += ' AND blocker_user_id IS null';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }

        if(fi.key == FilterKeys.byAge){
          int min = fi.v1;
          int max = fi.v2;
          var maxDate = GregorianDate();
          var minDate = GregorianDate();

          maxDate = maxDate.moveYear(-max, true);
          minDate = minDate.moveYear(-min, true);
          final u = maxDate.format('YYYY-MM-DD', 'en');
          final d = minDate.format('YYYY-MM-DD', 'en');

          search += ''' AND (birthdate < '$d'::date AND birthdate > '$u'::date) ''';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }

        else if(so.key == SortKeys.ageKey){
          if(so.isASC){
            orderBy = 'birthdate';
          }
          else {
            orderBy = 'birthdate DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchAndFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String users_q1(FilterRequest fq){
    var q = '''
    SELECT t1.user_id
    FROM Users AS t1
             INNER JOIN UserNameId AS t2
                 ON t1.user_id = t2.user_id
             LEFT JOIN MobileNumber AS t3
                 ON t1.user_id = t3.user_id AND t1.user_type = t3.user_type
    
    WHERE t1.user_type != 3 AND (@searchFilter)
    ORDER BY @orderBy
    LIMIT x;
    ''';

    var search = 'true';
    var orderBy = 'register_date DESC NULLS LAST';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.global){
          search = ' name ILIKE $value OR family ILIKE $value '
              'OR user_name ILIKE $value OR mobile_number ILIKE $value ';
        }
      }
    }

    /*if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }
      }
    }*/

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date NULLS LAST';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String userNotifiers_q1(FilterRequest fq, int userId){
    var q = '''
    SELECT * FROM userNotifier WHERE (@searchAndFilter)
      ORDER BY @orderBy 
    LIMIT x;
    ''';

    var search = 'user_id = $userId';
    var orderBy = 'register_date DESC NULLS LAST';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title Like $value';
        }
        else if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description Like $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchAndFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticket_q1(FilterRequest fq, int userId){
    var q = '''
    With c1 AS
         (SELECT id, title, start_date, starter_user_id, type,
                 is_close, is_deleted
          FROM ticket
            WHERE (@searchFilter)
             ORDER BY @orderBy
             LIMIT x
             ),
     c2 AS
         (SELECT t1.*, t2.last_message_ts
          FROM C1 AS t1 LEFT JOIN seenticketmessage AS t2
                ON t1.id = t2.ticket_id AND t2.user_id = @userId
         )

    SELECT * FROM c2 ORDER BY @orderBy;
    ''';

    var search = 'starter_user_id = $userId';
    var orderBy = 'start_date DESC NULLS LAST';

    if(fq.lastCase != null){
      search += " AND creation_date < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'start_date';
          }
          else {
            orderBy = 'start_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst('@userId', '$userId');
    q = q.replaceFirst('@searchFilter', search);
    q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticket_q2(FilterRequest fq, int userId){
    /*var q = '''
    SELECT id, title, start_date, starter_user_id, type,
       is_deleted, is_close, message_id,
       ticket_id, server_receive_ts, user_send_ts, user_id,
    CASE WHEN user_id = ${PublicAccess.adminUserId} THEN last_message_ts END AS last_message_ts
    FROM ticketsformanager1
    WHERE (@searchFilter)
    ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST
    LIMIT x;
    ''';*/

    var q = '''
    WITH C1 AS(
      SELECT id, title, start_date, starter_user_id, type,
             is_deleted, is_close, message_id,
             ticket_id, server_receive_ts, user_send_ts
      FROM ticketsformanager1
      WHERE (@searchFilter)
      ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST
      LIMIT x),
      C2 AS
          (SELECT t1.*, t2.last_message_ts, t2.user_id
                FROM C1 AS t1 LEFT JOIN seenticketmessage AS t2
                        ON t1.ticket_id = t2.ticket_id AND t2.user_id = @admin 
               )
      
      SELECT * FROM C2
      ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST;
    ''';

    var search = 'true';
    //var orderBy = 'start_date DESC NULLS LAST';

    if(fq.lastCase != null){
      search = " COALESCE(server_receive_ts, start_date) < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceFirst(RegExp('@admin'), '${PublicAccess.adminUserId}');
    //q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticket_q3(FilterRequest fq, int userId){
    var q = '''
    WITH C1 AS(
      SELECT id, title, start_date, starter_user_id, type,
             is_deleted, is_close, message_id,
             ticket_id, server_receive_ts, user_send_ts
      FROM ticketsformanager2
      WHERE (@searchFilter)
      ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST
      LIMIT 10),
      C2 AS
          (SELECT t1.*, t2.last_message_ts, t2.user_id
                FROM C1 AS t1 LEFT JOIN seenticketmessage AS t2
                        ON t1.ticket_id = t2.ticket_id
                  WHERE t2.user_id = @admin
               )
      
      SELECT * FROM C2
      ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST;
    ''';

    var search = 'true';
    //var orderBy = 'start_date DESC NULLS LAST';

    if(fq.lastCase != null){
      search += " AND COALESCE(server_receive_ts, start_date) < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
        else if(se.searchKey == SearchKeys.userNameKey) {
          search += ' AND user_name LIKE $value';
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    //q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticketMessage_q1(FilterRequest fq, int userId, List<int> ids, bool withDeleted){
    var q = '''
    With c1 AS
         (SELECT * FROM ticketmessage
             WHERE @con1 (@searchFilter)
         ORDER BY @orderBy
             LIMIT 100
         )

  SELECT * FROM c1;
    ''';

    if(withDeleted){
      q = q.replaceFirst('@con1', ' ');
    }
    else {
      q = q.replaceFirst('@con1', '(is_deleted = false) AND ');
    }

    var search = 'ticket_id IN (${Psql2.listToSequence(ids)})';
    var orderBy = 'server_receive_ts DESC NULLS LAST';

    if(fq.lastCase != null){
      search += ' AND id > ${fq.lastCase}';
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }
      }
    }


    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'start_date';
          }
          else {
            orderBy = 'start_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticketMessage_q2(FilterRequest fq, int ticketId, bool withDeleted){
    var q = '''
    With c1 AS
         (SELECT id, ticket_id, media_id, reply_id, message_type,
                 sender_user_id, is_deleted, is_edited, user_send_ts,
                 server_receive_ts, receive_ts, seen_ts,
                 message_text, extra_js, cover_data
          FROM ticketmessage
          WHERE @con1 (@searchFilter)
          ORDER BY @orderBy
            limit x
         )

  SELECT * FROM c1 ORDER BY @orderBy;
    ''';

    if(withDeleted){
      q = q.replaceFirst('@con1', ' ');
    }
    else {
      q = q.replaceFirst('@con1', '(is_deleted = false) AND ');
    }

    var search = 'ticket_id = $ticketId';
    var orderBy = 'server_receive_ts DESC NULLS LAST';

    if(fq.lastCase != null){
      search += " AND server_receive_ts < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String updateTicketMessageSeen(int ticketId, int userId, String ts){
    var q = '''
      UPDATE #tb
        SET seen_ts = '#ts'::timestamp,
            receive_ts = CASE
                 WHEN receive_ts IS NULL THEN '#ts'::timestamp
                 ELSE receive_ts
                END
    WHERE ticket_id = #ticketId AND sender_user_id != #userId;
    ''';

    q = q.replaceFirst(RegExp('#tb'), DbNames.T_TicketMessage);
    q = q.replaceFirst(RegExp('#ticketId'), '$ticketId');
    q = q.replaceFirst(RegExp('#userId'), '$userId');
    q = q.replaceAll(RegExp('#ts'), ts);

    return q;
  }

  static String request_course_q1(FilterRequest fq, int userId){
    var q = '''
    SELECT
    t1.id as request_id, t1.course_id, t1.requester_user_id,
    t1.answer_js, t1.answer_date,
    t1.request_date, t1.pay_date, t1.support_expire_date,

    t2.id, t2.title, t2.description, t2.duration_day,
    t2.has_food_program, t2.has_exercise_program,
    t2.currency_js, t2.price,
    t2.tags, t2.creation_date, t2.image_path as image_uri,
    t2.creator_user_id,

    (CASE WHEN
        EXISTS(SELECT id FROM foodprogram
            WHERE request_id = T1.id AND send_date IS NOT NULL)
        THEN TRUE ELSE FALSE END) AS is_send_program


FROM courseRequest AS t1
         JOIN course AS t2
              ON t1.course_id = t2.id
    WHERE (@searchFilter)
    ORDER BY @orderBy
    LIMIT x; 
    ''';

    var search = 'requester_user_id = $userId';
    var orderBy = 'pay_date NULLS last';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description ILIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byPrice){
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND is_block = true';
          }
          else {
            search += ' AND is_block = false';
          }
        }

        if(fi.key == FilterKeys.byExerciseMode){
          search += ' AND has_exercise_program = true';
        }

        if(fi.key == FilterKeys.byFoodMode){
          search += ' AND has_food_program = true';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'creation_date';
          }
          else {
            orderBy = 'creation_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), '$search');
    q = q.replaceFirst(RegExp('@orderBy'), '$orderBy');

    return q;
  }

  static String getAdvertisingListForUser(){
    final q = '''
    SELECT id, title, type, order_num, register_date,
       start_show_date, finish_show_date, click_link, path as image_uri
    FROM advertising

    WHERE can_show = true
      AND (start_show_date is null OR start_show_date <= (now() at time zone 'utc'))
      AND (finish_show_date is null OR finish_show_date > (now() at time zone 'utc'))
      AND (type is null OR type = '' OR type LIKE 'user')
    ORDER BY order_num NULLS last, start_show_date;
    ''';

    return q;
  }

  static String getAdvertisingList(FilterRequest fq){
    var q = '''SELECT t1.id, title, tag, type, can_show, creator_id,
       order_num, register_date, start_show_date,
       finish_show_date, click_link, path as image_uri, t2.user_name
    FROM advertising AS t1
    LEFT JOIN UserNameId AS t2 ON t1.creator_id = t2.user_id
     
    WHERE (@search)
      ORDER BY @orderBy 
    LIMIT x;
    ''';

    var search = 'TRUE';
    var orderBy = '';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey  == SearchKeys.userNameKey){
          search = ' user_name Like $value';
        }
        else if(se.searchKey == SearchKeys.titleKey) {
          search = ' title ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.tagKey) {
          search = ' tag ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.typeKey) {
          search = ' type Like $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byVisibleState){
          if (fi.value == FilterKeys.isVisibleOp) {
            search += ' AND can_show = true';
          }
          else if (fi.value == FilterKeys.isNotVisibleOp) {
            search += ' AND can_show = false';
          }
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }

        else if(so.key == SortKeys.showDateKey){
          if(so.isASC){
            orderBy = 'start_show_date NULLS LAST';
          }
          else {
            orderBy = 'start_show_date DESC NULLS LAST';
          }
        }

        else if(so.key == SortKeys.orderNumberKey){
          if(so.isASC){
            orderBy = 'order_num NULLS LAST';
          }
          else {
            orderBy = 'order_num DESC NULLS LAST';
          }
        }
      }
    }


    q = q.replaceFirst(RegExp('@search'), '$search');
    q = q.replaceFirst(RegExp('@orderBy'), '$orderBy');

    return q;
  }

}