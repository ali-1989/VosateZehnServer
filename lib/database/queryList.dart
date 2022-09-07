import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/rest_api/searchFilterTool.dart';

class QueryList {
  QueryList._();

  static String getTickets(SearchFilterTool sf){
    var q = '''SELECT * FROM #tb WHERE (#w)
        order by send_date DESC
        limit #lim
        ''';

    q = q.replaceFirst('#tb', DbNames.T_SimpleTicket);
    q = q.replaceFirst('#lim', '${sf.limit}');

    var w = 'is_deleted = false';

    /*if(sf.filters['x'] == null){
      w = 'is_hide = false';
    }*/

    if(sf.searchText != null){
      final t = '\$t\$%${sf.searchText}%\$t\$';
      w += ' AND (data like $t)';
    }

    if(sf.lower != null){
      w += " AND (send_date < '${sf.lower}'::timestamp)";
    }

    q = q.replaceFirst('#w', w);
    return q;
  }

  static String getTicketsCount(SearchFilterTool sf){
    var q = '''SELECT count(id) as count FROM #tb WHERE (#w) 
        ''';

    q = q.replaceFirst('#tb', DbNames.T_SimpleTicket);

    var w = 'is_deleted = false';

    if(sf.searchText != null){
      final t = '\$t\$%${sf.searchText}%\$t\$';
      w += ' AND (data like $t)';
    }

    if(sf.lower != null){
      w += " AND (send_date < '${sf.lower}'::timestamp)";
    }

    q = q.replaceFirst('#w', w);
    return q;
  }

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

  static String getSubBuckets(SearchFilterTool sf){
    var q = '''SELECT * FROM #tb WHERE (#w) AND
        parent_id = #pId
        order by date DESC
        limit #lim
        ''';

    q = q.replaceFirst('#tb', DbNames.T_SubBucket);
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

  static String getSubBucketsCount(SearchFilterTool sf){
    var q = '''SELECT count(id) as count FROM #tb WHERE (#w) AND
        parent_id = #pId
        ''';

    q = q.replaceFirst('#tb', DbNames.T_SubBucket);

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

  static String getSpeaker(int id){
    var q = '''SELECT * FROM #tb WHERE id = #id 
        ''';

    q = q.replaceFirst('#tb', DbNames.T_speaker);
    q = q.replaceFirst('#id', '$id');

    return q;
  }

  static String getSpeakers(SearchFilterTool sf){
    var q = '''SELECT * FROM #tb WHERE (#w) 
        order by date DESC
        limit #lim
        ''';

    q = q.replaceFirst('#tb', DbNames.T_speaker);
    q = q.replaceFirst('#lim', '${sf.limit}');

    var w = 'true';

    if(sf.searchText != null){
      final t = '\$t\$%${sf.searchText}%\$t\$';
      w += ' AND (name like $t OR description like $t)';
    }

    if(sf.lower != null){
      w += " AND (date < '${sf.lower}'::timestamp)";
    }

    q = q.replaceFirst('#w', w);
    return q;
  }

  static String getSpeakersCount(SearchFilterTool sf){
    var q = '''SELECT count(id) as count FROM #tb WHERE (#w)
        ''';

    q = q.replaceFirst('#tb', DbNames.T_speaker);

    var w = 'true';

    if(sf.searchText != null){
      final t = '\$t\$%${sf.searchText}%\$t\$';
      w += ' AND (name like $t OR description like $t)';
    }

    if(sf.lower != null){
      w += " AND (date < '${sf.lower}'::timestamp)";
    }

    q = q.replaceFirst('#w', w);
    return q;
  }

  static String getBucketContent(int cId){
    var q = '''SELECT * FROM #tb WHERE
        id = #id
        ''';

    q = q.replaceFirst('#tb', DbNames.T_BucketContent);
    q = q.replaceFirst('#id', '$cId');

    return q;
  }

  static String getBucketContentByParent(int pId){
    var q = '''SELECT * FROM #tb WHERE
        parent_id = #pId
        ''';

    q = q.replaceFirst('#tb', DbNames.T_BucketContent);
    q = q.replaceFirst('#pId', '$pId');

    return q;
  }

  static String getAdvertising(SearchFilterTool sf){
    var q = '''SELECT * FROM #tb WHERE (#w) 
        order by register_date DESC
        ''';

    q = q.replaceFirst('#tb', DbNames.T_SimpleAdvertising);

    var w = 'true';

    q = q.replaceFirst('#w', w);
    return q;
  }

  static String getDailyText(String start, String end){
    var q = '''SELECT * FROM #tb WHERE (#w) 
        order by date DESC
        ''';

    q = q.replaceFirst('#tb', DbNames.T_dailyText);

    var w = "date >= '$start'::timestamp AND date <= '$end'::timestamp";

    q = q.replaceFirst('#w', w);
    return q;
  }

}