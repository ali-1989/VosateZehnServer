import 'dart:core';
import 'dart:io';
import 'package:assistance_kit/api/converter.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:assistance_kit/database/psql2.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:vosate_zehn_server/app/pathNs.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/database/models/emailModel.dart';
import 'package:vosate_zehn_server/database/models/mobileNumber.dart';
import 'package:vosate_zehn_server/database/models/userConnection.dart';
import 'package:vosate_zehn_server/database/models/userCurrency.dart';
import 'package:vosate_zehn_server/database/models/userMedia.dart';
import 'package:vosate_zehn_server/database/models/users.dart';
import 'package:vosate_zehn_server/database/models/userCountry.dart';
import 'package:vosate_zehn_server/database/models/userNameId.dart';
import 'package:vosate_zehn_server/database/queryList.dart';
import 'package:vosate_zehn_server/database/querySelector.dart';
import 'package:vosate_zehn_server/models/enums.dart';
import 'package:vosate_zehn_server/models/photoDataModel.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/rest_api/searchFilterTool.dart';

class CommonMethods {
  CommonMethods._();

  static String? castToJsonb(dynamic mapOrJs, {bool nullIfNull = true}){
    return Psql2.castToJsonb(mapOrJs, nullIfNull: nullIfNull);
  }
  ///=====================================================================================================
  static Future<Map<String, dynamic>> getUserLoginInfo(int userId, bool byPassword) async {
    final getDataTypes = <UserDataType>{};

    getDataTypes.add(UserDataType.personal);
    getDataTypes.add(UserDataType.country);
    getDataTypes.add(UserDataType.currency);
    getDataTypes.add(byPassword? UserDataType.userNamePassword : UserDataType.userName);
    getDataTypes.add(UserDataType.mobileNumber);
    getDataTypes.add(UserDataType.email);
    getDataTypes.add(UserDataType.profileImage);

    return _getInfoForUser(userId, getDataTypes);
  }

  static Future<Map<String, dynamic>> getUserAdvanced(int userId) async {
    final getDataTypes = <UserDataType>{};
    getDataTypes.add(UserDataType.personal);
    getDataTypes.add(UserDataType.userName);
    getDataTypes.add(UserDataType.profileImage);
    getDataTypes.add(UserDataType.lastTouch);

    final res = await _getInfoForUser(userId, getDataTypes);
    JsonHelper.removeKeys(res, [Keys.sex, Keys.birthdate, /*...PublicAccess.avoidForLimitedUser*/]);

    return res;
  }

  static Future<Map<String, dynamic>> _getInfoForUser(int userId, Set<UserDataType> tList) async {
    final res = <String, dynamic>{};

    for(final type in tList){
      if(type == UserDataType.personal) {
        res.addAll((await UserModelDb.fetchMap(userId))?? {});
      }

      if(type == UserDataType.country) {
        res.addAll((await UserCountryModelDb.getUserCountryJs(userId))?? {});
      }

      if(type == UserDataType.currency) {
        res.addAll((await UserCurrencyModelDb.getUserCurrencyJs(userId))?? {});
      }

      if(type == UserDataType.userNamePassword) {
        final r = await UserNameModelDb.fetchMap(userId)?? {};

        JsonHelper.removeKeys(r, ['hash_password']);
        res.addAll(r);
      }

      if(type == UserDataType.userName) {
        final r = await UserNameModelDb.fetchMap(userId)?? {};

        JsonHelper.removeKeys(r, ['hash_password', 'password']);
        res.addAll(r);
      }

      if(type == UserDataType.mobileNumber) {
        res.addAll((await MobileNumberModelDb.fetchMap(userId))?? {});
      }

      if(type == UserDataType.email) {
        res.addAll((await UserEmailDb.fetchMap(userId))?? {});
      }

      if(type == UserDataType.profileImage) {
        res['profile_image_model'] = (await UserMediaModelDb.getProfileImage(userId));
      }

      if(type == UserDataType.lastTouch) {
        res.addAll((await UserConnectionModelDb.fetchLastTouch(userId)));
      }
    }

    return res;
  }

  static Future<int?> setHtmlData(int userId, String key, String? data) async {
    final where = '''key = '$key' ''';

    final kv = <String, dynamic>{};
    kv['owner_id'] = userId;
    kv['key'] = key;
    kv['data'] = data;
    kv['update_date'] = DateHelper.getNowTimestampToUtc();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_HtmlHolder, kv, where: where);

    if(cursor is num){
      return cursor!.toInt();
    }

    return null;
  }

  static Future<String?> getHtmlData(String key) async {
    var q = '''SELECT * FROM #T WHERE key = '$key' ''';
    q = q.replaceFirst('#T', DbNames.T_HtmlHolder);

    return await PublicAccess.psql2.getColumn(q, 'data');
  }

  static Future<int?> setTextData(String key, String? data) async {
    final where = '''key = '$key' ''';

    final kv = <String, dynamic>{};
    kv['key'] = key;
    kv['data'] = data;
    kv['update_date'] = DateHelper.getNowTimestampToUtc();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_TextHolder, kv, where: where);

    if(cursor is num){
      return cursor!.toInt();
    }

    return null;
  }

  static Future<String?> getTextData(String key) async {
    var q = '''SELECT * FROM #T WHERE key = '$key' ''';
    q = q.replaceFirst('#T', DbNames.T_TextHolder);

    return await PublicAccess.psql2.getColumn(q, 'data');
  }

  static Future<int?> setTicket(int userId, String? data) async {
    final kv = <String, dynamic>{};
    kv['sender_user_id'] = userId;
    kv['data'] = data;
    //kv['send_date'] = DateHelper.getNowTimestampToUtc();

    final cursor = await PublicAccess.psql2.insertKv(DbNames.T_SimpleTicket, kv,);

    if(cursor is num){
      return cursor!.toInt();
    }

    return null;
  }

  static Future<List<Map>?> getBuckets(Map jsData) async {
    final key = jsData[Keys.key];
    final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getBuckets(sf);
    q = q.replaceFirst('#key', '$key');

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future<int> getBucketsCount(Map jsData) async {
    final key = jsData[Keys.key];
    final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getBucketsCount(sf);
    q = q.replaceFirst('#key', '$key');

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<bool> upsetBucket(int userId, Map jsData, int? mediaId) async {
    //final key = jsData[Keys.key];
    final bucketData = jsData[Keys.data];
    final image = jsData['image'];

    final kv = <String, dynamic>{};
    kv['title'] = bucketData['title'];
    kv['description'] = bucketData['description'];
    kv['bucket_type'] = bucketData['bucket_type'];

    if(bucketData['date'] != null) {
      kv['date'] = bucketData['date'];
    }

    if(bucketData['is_hide'] != null) {
      kv['is_hide'] = bucketData['is_hide'];
    }

    if(mediaId != null) {
      kv['media_id'] = mediaId;
    }

    var id = -1;

    if(bucketData['id'] != null){
      id = bucketData['id'];
      kv['id'] = bucketData['id'];

      if(image is bool){ // mean: delete image in edit mode
        kv['media_id'] = null;
      }
    }

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_Bucket, kv, where: ' id = $id');

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  static Future<bool> deleteBucket(int bucketId) async {
    final r = await PublicAccess.psql2.delete(DbNames.T_Bucket, 'id = $bucketId');
    return r != null && r > 0;
  }

  static Future<int?> getMediaIdFromBucket(int bucketId) async {
    final q = 'SELECT media_id FROM ${DbNames.T_Bucket} WHERE id = $bucketId;';
    return await PublicAccess.psql2.getColumn(q, 'media_id');
  }

  static Future<List<int>?> findSubBucketIdsByBucket(int bucketId) async {
    final q = 'SELECT id FROM ${DbNames.T_SubBucket} WHERE parent_id = $bucketId;';
    return await PublicAccess.psql2.getColumnAsList<int>(q, 'id');
  }

  static Future deleteMedia(int mediaId) async {
    final q = 'SELECT media_path FROM ${DbNames.T_Media} WHERE id = $mediaId;';
    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'media_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_Media, 'id = $mediaId');

    if(x != null && x > 0){
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        PublicAccess.insertEncodedPathToJunkFile(oldRelPath);
      }

      return true;
    }

    return false;
  }

  static Future getMediasByIds(List mediaIds) async {
    if(mediaIds.isEmpty){
      return <Map<String, dynamic>>[];
    }

    final replace = {};
    replace['@list'] = Psql2.listToSequenceNum(mediaIds);

    final qs = QuerySelector();
    qs.addQuery(QueryList.getMediasByIds());

    final listOrNull = await PublicAccess.psql2.queryCall(qs.generate(0, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    // smpl: reWrite
    return listOrNull.map((e) {
      final m = e.toMap();
      m['url'] = PathsNs.genUrlDomainFromLocalPathByDecoding(PublicAccess.domain, PathsNs.getCurrentPath(), m['url']);
      return m as Map<String, dynamic>;
    }).toList();
  }

  static Future<int> insertMedia(File file, {
    String? title, String? fileName,
    String? extension, int? duration,
    int? width, int? height,
  }) async {
    final p = PathsNs.removeBasePathFromLocalPath(PathsNs.getCurrentPath(), file.path);

    final kv = <String, dynamic>{};
    kv['volume'] = file.lengthSync();
    kv['media_path'] = UrlHelper.encodeUrl(p!);

    if(duration != null){
      kv['duration'] = duration;
    }

    if(width != null){
      kv['width'] = width;
    }

    if(height != null){
      kv['height'] = height;
    }

    if(extension != null){
      kv['extension'] = extension;
    }

    if(fileName != null){
      kv['file_name'] = fileName;
    }

    if(title != null){
      kv['title'] = title;
    }

    final cursor = await PublicAccess.psql2.insertKvReturning(DbNames.T_Media, kv, 'id');

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    return cursor[0].toList()[0];
  }

  static Future<bool> upsetSubBucket(Map jsData, int? coverId, int? mediaId, int? contentId) async {
    //final key = jsData[Keys.key];
    final bucketData = jsData[Keys.data];
    final cover = jsData['cover'];

    var kv = <String, dynamic>{};
    kv['parent_id'] = bucketData['parent_id'];
    kv['title'] = bucketData['title'];
    kv['description'] = bucketData['description'];
    kv['type'] = bucketData['type'];
    kv['duration'] = bucketData['duration'];
    kv['content_type'] = bucketData['content_type'];
    kv['content_id'] = contentId;
    kv['media_id'] = mediaId;

    kv['id'] = bucketData['id'];
    kv['date'] = bucketData['date'];
    kv['is_hide'] = bucketData['is_hide'];
    kv['cover_id'] = coverId;

    kv = JsonHelper.removeNullsByKey(kv, ['id', 'date', 'is_hide', 'cover_id'])!;
    var id = -1;

    if(bucketData['id'] != null){
      id = bucketData['id'];

      if(cover is bool){ // mean: delete cover in edit mode
        kv['cover_id'] = null;
      }
    }

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_SubBucket, kv, where: ' id = $id');

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  static Future<List<Map>?> getSubBuckets(Map jsData) async {
    final pId = jsData[Keys.id];
    final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getSubBuckets(sf);
    q = q.replaceFirst('#pId', '$pId');

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future<int> getSubBucketsCount(Map jsData) async {
    final parentId = jsData[Keys.id];
    final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getSubBucketsCount(sf);
    q = q.replaceFirst('#pId', '$parentId');

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<int?> getMediaIdFromSubBucket(int subBucketId) async {
    final q = 'SELECT media_id FROM ${DbNames.T_SubBucket} WHERE id = $subBucketId;';
    return await PublicAccess.psql2.getColumn<int>(q, 'media_id');
  }

  static Future<int?> getCoverIdFromSubBucket(int bucketId) async {
    final q = 'SELECT cover_id FROM ${DbNames.T_SubBucket} WHERE id = $bucketId;';
    return await PublicAccess.psql2.getColumn<int>(q, 'cover_id');
  }

  static Future<int?> deleteSubBucket(int subBucketId) async {
    final res = await PublicAccess.psql2.deleteReturning(DbNames.T_SubBucket, 'id = $subBucketId', returning: 'content_id');

    if(res == null || res.isEmpty){
      return null;
    }

    final l = res[0].toList();

    return l.isNotEmpty? l[0] : null;
  }

  static Future<bool> deleteContentAndMedias(int contentId) async {
    final res = await PublicAccess.psql2.deleteReturning(DbNames.T_BucketContent, 'id = $contentId', returning: 'media_ids');

    if(res == null || res.isEmpty){
      return false;
    }

    final ids = res[0].toList()[0];

    for(final k in ids){
      // ignore: unawaited_futures
      deleteMedia(k);
    }

    return true;
  }

  static Future<List<Map>?> getSpeakers(Map jsData) async {
    final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getSpeakers(sf);

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future<Map?> getSpeaker(int id) async {
    var q = QueryList.getSpeaker(id);

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <String, dynamic>{};
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future<int> getSpeakersCount(Map jsData) async {
    final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getSpeakersCount(sf);

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return 0;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<bool> upsetSpeaker(Map jsData, int? mediaId) async {
   final speakerData = jsData[Keys.data];
    final cover = jsData['image'];

    var kv = <String, dynamic>{};
    kv['name'] = speakerData[Keys.name];
    kv['description'] = speakerData['description'];
    kv['id'] = speakerData[Keys.id];
    kv['date'] = speakerData['date'];
    kv['is_hide'] = speakerData['is_hide'];
    kv['media_id'] = mediaId;

   kv = JsonHelper.removeNullsByKey(kv, ['id', 'date', 'is_hide', 'media_id'])!;
    var id = -1;

    if(speakerData['id'] != null){
      id = speakerData['id'];

      if(cover is bool){ // mean: delete cover in edit mode
        kv['media_id'] = null;
      }
    }

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_speaker, kv, where: ' id = $id');

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  static Future<bool> deleteSpeaker(int subBucketId) async {
    final r = await PublicAccess.psql2.delete(DbNames.T_speaker, 'id = $subBucketId');
    return r != null && r > 0;
  }

  static Future<int?> getMediaIdFromSpeaker(int bucketId) async {
    final q = 'SELECT media_id FROM ${DbNames.T_speaker} WHERE id = $bucketId;';
    return await PublicAccess.psql2.getColumn(q, 'media_id');
  }

  static Future<int> upsetBucketContent(Map jsData, int speakerId, List<int> mediaIds) async {
    final pId = jsData['parent_id'];
    final id = jsData[Keys.id]?? -1;
    final currentMediaIds = Converter.correctList<int>(jsData['current_media_ids'])?? <int>[];

    currentMediaIds.addAll(mediaIds);

    final kv = <String, dynamic>{};
    kv['parent_id'] = pId;
    kv['speaker_id'] = speakerId;
    kv['media_ids'] = Psql2.listToPgIntArray(currentMediaIds);

    /*if(bucketData['date'] != null) {
      kv['date'] = bucketData['date'];
    }*/

    var cursor = await PublicAccess.psql2.upsertWhereKvReturning(DbNames.T_BucketContent, kv, where: ' id = $id', returning: 'id');

    if (cursor == null || cursor.isEmpty) {
      return -1;
    }

    return cursor[0].toList()[0];
  }

  static Future<int> sortBucketContent(int contentId, List<int> mediaIds, bool forceOrder) async {
    final kv = <String, dynamic>{};
    kv['media_ids'] = Psql2.listToPgIntArray(mediaIds);
    kv['has_order'] = forceOrder;

    final cursor = await PublicAccess.psql2.updateKv(DbNames.T_BucketContent, kv, ' id = $contentId');

    if (cursor == null || cursor < 1) {
      return -1;
    }

    return cursor;
  }

  static Future<bool> setContentIdToSubBucket(int subId, int contentId) async {
    final kv = <String, dynamic>{};
    kv['content_id'] = contentId;

    var cursor = await PublicAccess.psql2.updateKv(DbNames.T_SubBucket, kv, ' id = $subId');

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  static Future<Map?> getBucketContent(Map jsData) async {
    final pId = jsData[Keys.id];
    //final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getBucketContentByParent(pId);

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <String, dynamic>{};
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getTickets(Map jsData) async {
    final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    final q = QueryList.getTickets(sf);

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e.toMap() as Map<String, dynamic>).toList();
  }

  static Future<List<Map<String, dynamic>>> getCustomersForIds(List userIds) async {
    final res = <Map<String, dynamic>>[];

    if(userIds.isEmpty){
      return res;
    }

    final getDataTypes = <UserDataType>{};

    getDataTypes.add(UserDataType.personal);
    getDataTypes.add(UserDataType.country);
    //getDataTypes.add(UserDataType.currency);
    getDataTypes.add(UserDataType.userName);
    getDataTypes.add(UserDataType.mobileNumber);
    getDataTypes.add(UserDataType.email);
    getDataTypes.add(UserDataType.profileImage);

    for(final uid in userIds) {
      res.add(await _getInfoForUser(uid, getDataTypes));
    }

    return res;
  }

  static Future<bool> insertAdvertising(Map jsData, int? mediaId) async {
    final tag = jsData['tag'];
    final clickLink = jsData['image'];

    var kv = <String, dynamic>{};
    kv['tag'] =tag;
    kv['click_link'] = clickLink;
    kv['media_id'] = mediaId;

    //kv = JsonHelper.removeNullsByKey(kv, ['id', 'register_date'])!;
    var id = -1;

    if(jsData['id'] != null){
      id = jsData['id'];
      kv['id'] = jsData['id'];
    }

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_SimpleAdvertising, kv, where: ' id = $id');

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  static Future<bool> deleteAdvertising(String tag) async {
    final cursor = await PublicAccess.psql2.delete(DbNames.T_SimpleAdvertising, " tag = '$tag'");

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  static Future<bool> setAdvertisingUrl(String tag, String? url) async {
    final kv = <String, dynamic>{};
    kv['click_link'] = url;

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_SimpleAdvertising, kv, where: " tag = '$tag'");

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  static Future<List<Map>?> getAdvertising(Map jsData) async {
    final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getAdvertising(sf);

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      final res = e.toMap() as Map<String, dynamic>;
      res['date'] = res['register_date'];
      res['url'] = res['click_link'];

      JsonHelper.removeKeys(res, ['register_date', 'click_link']);
      return res;
    }).toList();
  }

  static Future<List<Map>?> getDailyText(String start, String end) async {
    //final sf = SearchFilterTool.fromMap(jsData[Keys.searchFilter]);

    var q = QueryList.getDailyText(start, end);

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      final res = e.toMap() as Map<String, dynamic>;
      return res;
    }).toList();
  }

  static Future<int?> insertDailyText(int? id, String txt, String date) async {
    final kv = <String, dynamic>{};
    kv['text'] =txt;
    kv['date'] = date;


    if(id != null){
      kv['id'] = id;
    }

    final cursor = await PublicAccess.psql2.upsertWhereKvReturning(
        DbNames.T_dailyText, kv, where: ' id = ${id?? -1}', returning: 'id');

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor[0].toMap()['id'];
  }

  static Future<bool> deleteDailyText(int id, String? date) async {
    final cursor = await PublicAccess.psql2.delete(DbNames.T_dailyText,  ' id = $id');

    if (cursor == null || cursor < 0) {
      return false;
    }

    return true;
  }

  static Future<List<Map>?> getNewSubBucketsByType(SearchFilterTool sf, String type) async {
    var q = QueryList.getNewSubBucketsByType(sf);
    q = q.replaceFirst('#type', '$type');

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future<List<Map>> searchSubBuckets(SearchFilterTool sf) async {
    var q = QueryList.searchSubBuckets(sf);

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future<List<Map>?> getNewSubBuckets() async {
    var q = QueryList.getNewSubBuckets();

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future<bool> addContentSeen(int userId, int subBucketId, int contentId, int mediaId) async {
    var q = QueryList.addContentSeen();
    q = q.replaceFirst('#userId', '$userId');
    q = q.replaceFirst('#subId', '$subBucketId');
    q = q.replaceFirst('#contentId', '$contentId');
    q = q.replaceAll('#mediaId', '$mediaId');

    final cursor = await PublicAccess.psql2.execution(q);

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  static Future<List<int>> getContentSeenList(int userId, int subBucketId, int contentId) async {
    final res = <int>[];

    var q = '''
      SELECT * FROM #tb WHERE user_id = #userId AND sub_bucket_id = #subBucketId AND content_id = #contentId;
    '''
    .replaceFirst('#tb', DbNames.T_seenContent)
    .replaceFirst('#userId', '$userId')
    .replaceFirst('#subBucketId', '$subBucketId')
    .replaceFirst('#contentId', '$contentId');

    final cursor = await PublicAccess.psql2.getColumn<List>(q, 'media_ids');

    if (cursor == null) {
      return res;
    }

    return cursor.map((e) => e as int).toList();
  }

  static Future<bool> updateMediaTitle(int mediaId, String? title) async {
    final kv = <String, dynamic>{};
    kv['title'] = title;

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_Media, kv, where: 'id = $mediaId');

    if (cursor == null || cursor < 1) {
      return false;
    }

    return true;
  }

  // [AppUser] for manager
  static Future<List<Map<String, dynamic>>> searchOnUsers(SearchFilterTool filter) async {
    final cursor = await PublicAccess.psql2.queryCall(QueryList.searchUsers(filter));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }


























  static Future<Map> getCoursePayInfo(int userId, int courseId) async {
    var q = '''
      SELECT 
       questions_js->'card_photo' AS card_photo
        FROM coursebuyquestion
        WHERE user_id = $userId AND course_id = $courseId;
    ''';

    final listOrNull = await PublicAccess.psql2.queryCall(q);

    if(listOrNull == null || listOrNull.isEmpty){
      return {};
    }

    return listOrNull[0].toMap();
  }

  static Future<bool> deleteCoursePayPhoto(int userId, int courseId) async {
    var q = '''
      UPDATE coursebuyquestion
      SET
          questions_js = jsonb_delete_path(questions_js, Array['card_photo']::text[])
      WHERE user_id = $userId AND course_id = $courseId;
    ''';

    final num = await PublicAccess.psql2.execution(q);

    return num != null && num > -1;
  }

  static Future<bool> updateCoursePayPhoto(int userId, int courseId, PhotoDataModel pd) async {
    var q = '''
      UPDATE coursebuyquestion
      SET
          questions_js = jsonb_set(questions_js, Array['card_photo'], ${Psql2.castToJsonb(pd.toMap())})
      WHERE user_id = $userId AND course_id = $courseId;
    ''';

    final num = await PublicAccess.psql2.execution(q);

    return num != null && num > -1;
  }


  static Future updateLastTicketSeen(int userId, int ticketId, String ts) async {
    final q = '''SELECT update_seen_ticket($userId, $ticketId, '$ts'::timestamp);''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor is List){
      return cursor!.first.toList()[0];
    }

    return null;
  }

  static Future updateLastChatSeen(int userId, int conversationId, String ts) async {
    final q = '''SELECT update_seen_chat($userId, $conversationId, '$ts'::timestamp);''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor is List){
      return cursor!.first.toList()[0];
    }

    return null;
  }

  static Future deleteMediaMessage(int userId, String mediaId) async {
    final cursor = await PublicAccess.psql2.delete(DbNames.T_MediaMessageData, ' id = $mediaId ');

    if(cursor is String || cursor is int){
      return cursor;
    }

    return null;
  }
}