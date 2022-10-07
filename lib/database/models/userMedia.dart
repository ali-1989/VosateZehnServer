import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:vosate_zehn_server/app/pathNs.dart';
import 'package:vosate_zehn_server/database/models/dbModel.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/publicAccess.dart';

/// note: insert relative path no full path [for where]

class UserMediaModelDb extends DbModel {
  int? id;
  late int user_id;
  late int type;
  String? mediaPath;
  String? name;
  String? extension;
  int? volume;
  double? width;
  double? height;
  String? date;

  //type:
  // 1: Avatar,
  // 2: Certificate Face
  // 3: Biography
  static final String QTbl_UserImages = '''
		CREATE TABLE IF NOT EXISTS #tb (
       id BIGSERIAL NOT NULL,
       user_id BIGINT NOT NULL,
       type SMALLINT NOT NULL,
       media_path varchar(400) NOT NULL,
       name varchar(100) DEFAULT NULL,
       extension varchar(10) DEFAULT NULL,
       volume INT DEFAULT NULL,
       width INT DEFAULT NULL,
       height INT DEFAULT NULL,
       insert_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
      		ON DELETE CASCADE ON UPDATE CASCADE,
       CONSTRAINT fk2_#tb FOREIGN KEY (type) REFERENCES #ref2 (Key)
      		ON DELETE RESTRICT ON UPDATE CASCADE
      )
      PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserMedia)
      .replaceFirst('#ref', DbNames.T_Users)
      .replaceFirst('#ref2', DbNames.T_MediaType);

  static final String QIdx_UserImages$type = '''
		CREATE INDEX IF NOT EXISTS #tb_type_idx ON #tb
		USING BTREE (type);
		'''
      .replaceAll('#tb', DbNames.T_UserMedia);

  static final String QTbl_UserImages$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserMedia);

  static final String QTbl_UserImages$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserMedia);

  /* no need unique
  static final String QAltUk1_UserImages$p1 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p1
     ADD CONSTRAINT uk1_#tb_p1 UNIQUE (user_id, type);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM;
        END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserMedia);

  static final String QAltUk1_UserImages$p2 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p2
     ADD CONSTRAINT uk1_#tb_p2 UNIQUE (user_id, type);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM;
        END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserMedia);*/


  UserMediaModelDb();

  @override
  UserMediaModelDb.fromMap(Map map) : super.fromMap(map) {
    id = map[Keys.id];
    user_id = map[Keys.userId];
    type = map[Keys.type];
    mediaPath = map[Keys.mediaPath];
    name = map[Keys.name];
    extension = map['extension'];
    //volume = v == null? null: (v as int).toDouble();
    volume = map['volume'];
    width = map['width'];
    height = map['height'];
    date = map[Keys.date];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.id] = id;
    map[Keys.userId] = user_id;
    map[Keys.type] = type;
    map[Keys.mediaPath] = mediaPath;
    map[Keys.name] = name;
    map['extension'] = extension;
    map['volume'] = volume;
    map['width'] = width;
    map['height'] = height;

    if(id != null) {
      map[Keys.id] = id;
    }

    if(date != null) {
      map[Keys.date] = date;
    }

    return map;
  }

  void changePathForClient(){
    if(mediaPath != null) {
      mediaPath = PathsNs.genUrlDomainFromLocalPathByDecoding(PublicAccess.domain, PathsNs.getCurrentPath(), mediaPath!);
    }
  }

  void changePathForDb(){
    if(mediaPath != null) {
      mediaPath = PathsNs.encodeFilePathForDataBase(mediaPath!);
    }
  }

  static Future<Map<String, dynamic>?> fetchFirst(int userId, int type) async {
    final q = '''SELECT * FROM ${DbNames.T_UserMedia} WHERE user_id = $userId AND type = $type;''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>?>> fetch(int userId, int type) async {
    final q = '''SELECT * FROM ${DbNames.T_UserMedia} WHERE user_id = $userId AND type = $type;''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return [];
    }

    return cursor.map((elm){
      return elm.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<bool> upsert(int userId, int type, String rawPath, int? volume) async{
    final q = 'SELECT media_path FROM ${DbNames.T_UserMedia} WHERE user_id = $userId AND type = $type;';
    final oldPath = await PublicAccess.psql2.getColumn(q, 'media_path');

    final value = [
      userId,
      type,
      PathsNs.encodeFilePathForDataBaseRelative(rawPath),
      volume
    ];

    final x = await PublicAccess.psql2.upsertWhere(DbNames.T_UserMedia,
        ['user_id', 'type', 'media_path', 'volume'],
        value,
        where: ' type = $type AND user_id = $userId');

    if(x != null && x > 0) {
      if(!TextHelper.isEmptyOrNull(oldPath)) {
        // no need to deCode, because again insert to DB
        PublicAccess.insertEncodedPathToJunkFile(oldPath);
      }

      return true;
    }

    return false;
  }

  static Future<bool> addUserImage(int userId, int type, String rawPath, int? volume) async{
    final value = [
      userId,
      type,
      PathsNs.encodeFilePathForDataBaseRelative(rawPath),
      volume,
    ];

    final x = await PublicAccess.psql2.insert(DbNames.T_UserMedia, ['user_id', 'type', 'media_path', 'volume'], value);
    return x != null && x > 0;
  }

  static Future<bool> deleteMediaByType(int userId, int type) async {
    final q = 'SELECT media_path FROM ${DbNames.T_UserMedia} WHERE user_id = $userId AND type = $type;';
    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'media_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_UserMedia, 'user_id = $userId AND type = $type');

    if(x != null && x > 0){
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        final deCode = UrlHelper.decodePathFromDataBase(oldRelPath)!;
        var p = PathsNs.addBasePathToLocalPath(deCode)!;

        p = PathsNs.encodeFilePathForDataBase(p)!;
        PublicAccess.insertEncodedPathToJunkFile(p);
      }

      return true;
    }

    return false;
  }

  static Future<bool> deleteMediaByUrl(int userId, int type, String url) async{
    final deCode = UrlHelper.decodeUrl(url)!;

    var relPath = UrlHelper.removeDomain(deCode)!;
    relPath = UrlHelper.encodeUrl(relPath)!;

    final where = "user_id = $userId AND type = $type AND media_path = '$relPath'";

    final q = 'SELECT media_path FROM ${DbNames.T_UserMedia} WHERE $where;';

    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'media_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_UserMedia, where);

    if(x != null && x > 0){
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        final deCode = UrlHelper.decodePathFromDataBase(oldRelPath)!;
        var p = PathsNs.addBasePathToLocalPath(deCode)!;

        p = PathsNs.encodeFilePathForDataBase(p)!;
        PublicAccess.insertEncodedPathToJunkFile(p);
      }

      return true;
    }

    return false;
  }

  static Future<bool> deleteMediaByDate(int userId, int type, String date) async{
    final where = "user_id = $userId AND type = $type AND insert_date = '$date'";

    final q = 'SELECT media_path FROM ${DbNames.T_UserMedia} WHERE $where;';
    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'media_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_UserMedia, where);

    if(x != null && x > 0){
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        final deCode = UrlHelper.decodePathFromDataBase(oldRelPath)!;
        var p = PathsNs.addBasePathToLocalPath(deCode)!;

        p = PathsNs.encodeFilePathForDataBase(p)!;
        PublicAccess.insertEncodedPathToJunkFile(p);
      }

      return true;
    }

    return false;
  }
  //-----------------------------------------------------------------------------------------------
  /*Map<String, dynamic> _toMapForClient() {
    final res = <String, dynamic>{};

    res[Keys.userId] = user_id;
    res[Keys.profileImageUrl] = mediaPath;

    return res;
  }*/

  static Future<Map<String, dynamic>?> fetchProfileImageMap(int userId) async {
    return await UserMediaModelDb.fetchFirst(userId, 1);
  }

  static Future<Map<String, dynamic>> getProfileImage(int userId) async {
    final map = await UserMediaModelDb.fetchProfileImageMap(userId);

    if (map == null) {
      return <String, dynamic>{};
    }

    final model = UserMediaModelDb.fromMap(map);
    model.changePathForClient();

    final res = model.toMap();
    res[Keys.url] = model.mediaPath;

    return res;
  }

  static Future<bool> deleteProfileImage(int userId, int type) async {
    final q = 'SELECT media_path FROM ${DbNames.T_UserMedia} WHERE user_id = $userId AND type = $type;';
    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'media_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_UserMedia,' type = $type AND user_id = $userId');

    if(x != null && x > 0) {
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        final deCode = UrlHelper.decodePathFromDataBase(oldRelPath)!;
        var p = PathsNs.addBasePathToLocalPath(deCode)!;

        p = PathsNs.encodeFilePathForDataBase(p)!;
        PublicAccess.insertEncodedPathToJunkFile(p);
      }

      return true;
    }

    return false;
  }

}
