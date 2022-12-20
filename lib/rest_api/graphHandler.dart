import 'dart:async';
import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/api/converter.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/dateSection/ADateStructure.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:vosate_zehn_server/app/pathNs.dart';
import 'package:vosate_zehn_server/database/models/userBlockList.dart';
import 'package:vosate_zehn_server/database/models/userConnection.dart';
import 'package:vosate_zehn_server/database/models/userCountry.dart';
import 'package:vosate_zehn_server/database/models/userMedia.dart';
import 'package:vosate_zehn_server/database/models/users.dart';
import 'package:vosate_zehn_server/database/models/userNameId.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/freeUserCommands.dart';
import 'package:vosate_zehn_server/rest_api/guestUserCommands.dart';
import 'package:vosate_zehn_server/rest_api/serverNs.dart';
import 'package:vosate_zehn_server/rest_api/adminCommands.dart';
import 'package:vosate_zehn_server/rest_api/commonMethods.dart';
import 'package:vosate_zehn_server/rest_api/httpCodes.dart';
import 'package:vosate_zehn_server/rest_api/loginZone.dart';
import 'package:vosate_zehn_server/rest_api/registerZone.dart';
import 'package:vosate_zehn_server/rest_api/searchFilterTool.dart';
import 'package:vosate_zehn_server/rest_api/statisticsApis.dart';
import 'package:vosate_zehn_server/webSocket/wsMessenger.dart';

class GraphHandlerWrap {
  late HttpRequest request;
  late HttpResponse response;
  late Map<String, dynamic> bodyJSON;
  late String zoneRequest;
  int? userId;
  String? deviceId;
}
///==========================================================================================================
class GraphHandler {
  GraphHandler._();

  static Map<String, dynamic> generateResultOk() {
    return HttpCodes.generateResultOk();
  }

  static Map<String, dynamic> generateResultError(int causeCode, {String? cause}) {
    return HttpCodes.generateJsonError(causeCode, cause: cause);
  }

  static Map<String, dynamic> generateResultBy(String result) {
    return HttpCodes.generateResultJson(result);
  }
  ///----------------------------------------------------------------------------------------
  static FutureOr response(HttpRequest req, HttpResponse res) async {
    final body = await req.bodyAsJsonMap;
    late Map<String, dynamic> bJSON;

    if(body.containsKey(Keys.jsonPart)) {
      bJSON = JsonHelper.jsonToMap<String, dynamic>(body[Keys.jsonPart]!)!;
    }
    else {
      bJSON = body;
    }

    PublicAccess.logInDebug(bJSON.toString());
    req.store.set('Body', body);

    final request = bJSON[Keys.requestZone];
    dynamic requesterId = bJSON[Keys.requesterId];
    final deviceId = bJSON[Keys.deviceId];

    if(requesterId is String){
      requesterId = int.tryParse(requesterId);
    }

    if(deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if (request == null) {
      return generateResultError(HttpCodes.error_zoneKeyNotFound);
    }

    if(requesterId == null){
      if(!FreeUserCommands.isFreeCommand(request)){
        return generateResultError(HttpCodes.error_canNotAccess);
      }
    }

    final wrapper = GraphHandlerWrap();
    wrapper.request = req;
    wrapper.response = res;
    wrapper.bodyJSON = bJSON;
    wrapper.zoneRequest = request;
    wrapper.userId = requesterId;
    wrapper.deviceId = deviceId;

    /// Guest user
    if(requesterId == 0){
      if(!GuestUserCommands.isGuestCommand(wrapper)){
        return generateResultError(HttpCodes.error_canNotAccess);
      }
    }

    if (requesterId != null && requesterId != 0) {
      final token = bJSON[Keys.token];

      if (!(await UserConnectionModelDb.tokenIsActive(requesterId, deviceId, token))) {
        return generateResultError(HttpCodes.error_tokenNotCorrect);
      }

      // ignore: unawaited_futures
      UserConnectionModelDb.upsertUserActiveTouch(requesterId, deviceId);

      if (await UserModelDb.isDeletedUser(requesterId)) {
        return generateResultError(HttpCodes.error_userNotFound);
      }

      if (await UserBlockListModelDb.isBlockedUser(requesterId)) {
        return generateResultError(HttpCodes.error_userIsBlocked);
      }
    }

    if(AdminCommands.isAdminCommand(request)){
      if(requesterId == null) {
        return generateResultError(HttpCodes.error_mustSendRequesterUserId);
      }

      final isManager = await UserModelDb.isManagerUser(requesterId);

      if(!isManager){
        return generateResultError(HttpCodes.error_canNotAccess);
      }
    }
    ///.............................................................................................
    try{
      return await _process(wrapper);
    }
    catch (e){
      PublicAccess.logInDebug('>>> Error in process graph-request:\n$e');

      if(!PublicAccess.isReleaseMode()) {
        rethrow;
      }
    }
  }
  ///==========================================================================================================
  static Future<Map<String, dynamic>> _process(GraphHandlerWrap wrapper) async {
    final request = wrapper.zoneRequest;
    
    if (request == 'get_app_parameters') {
      return getAppParameters(wrapper);
    }

    if (request == 'send_otp') {
      return RegisterZone.preRegisterByMobileAndSendOtp(wrapper);
    }

    if (request == 'verify_otp') {
      return RegisterZone.verifyOtp(wrapper);
    }

    if (request == 'verify_email') {
      return RegisterZone.verifyEmail(wrapper);
    }

    if (request == 'register_user') {
      return RegisterZone.registerUserWithFullData(wrapper);
    }

    if (request == 'register_user_and_otp') {
      return RegisterZone.preRegisterWithFullDataAndSendOtp(wrapper);
    }

    if (request == 'complete_registering') {
      return RegisterZone.verifyOtpAndCompletePreRegistering(wrapper);
    }

    if (request == 'restore_password') {
      return RegisterZone.restorePassword(wrapper);
    }

    if (request == 'resend_verify_code') {
      return RegisterZone.resendSavedOtp(wrapper);
    }

    if (request == 'login_user_name') {
      return LoginZone.loginByUserName(wrapper);
    }

    if (request == 'login_admin') {
      return LoginZone.loginAdmin(wrapper);
    }

    if (request == 'Logoff_user_report') {
      return setUserIsLogoff(wrapper);
    }

    if (request == 'get_profile_data') {
      return getProfileData(wrapper);
    }

    if (request == 'update_user_nameFamily') {
      return updateProfileNameFamily(wrapper);
    }

    if (request == 'Update_profile_avatar') {
      return updateProfileAvatar(wrapper);
    }

    if (request == 'delete_profile_avatar') {
      return deleteProfileAvatar(wrapper);
    }

    if (request == 'update_user_gender') {
      return updateProfileSex(wrapper);
    }

    if (request == 'update_user_birthdate') {
      return updateProfileBirthDate(wrapper);
    }

    if (request == 'set_about_us_data') {
      return setAboutUsData(wrapper);
    }

    if (request == 'get_about_us_data') {
      return getAboutUsData(wrapper);
    }

    if (request == 'set_aid_data') {
      return setAidData(wrapper);
    }

    if (request == 'get_aid_data') {
      return getAidData(wrapper);
    }

    if (request == 'set_aid_dialog_data') {
      return setAidDialogData(wrapper);
    }

    if (request == 'get_aid_dialog_data') {
      return getAidDialogData(wrapper);
    }

    if (request == 'set_term_data') {
      return setTermData(wrapper);
    }

    if (request == 'get_term_data') {
      return getTermData(wrapper);
    }

    if (request == 'send_ticket_data') {
      return setTicketData(wrapper);
    }

    if (request == 'get_tickets') {
      return getTickets(wrapper);
    }

    if (request == 'upsert_bucket') {
      return upsertBucket(wrapper);
    }

    if (request == 'upsert_sub_bucket') {
      return upsertSubBucket(wrapper);
    }

    if (request == 'delete_bucket') {
      return deleteBucket(wrapper);
    }

    if (request == 'get_bucket_data') {
      return getBucketData(wrapper);
    }

    if (request == 'get_sub_bucket_data') {
      return getSubBucketData(wrapper);
    }

    if (request == 'delete_sub_bucket') {
      return deleteSubBucket(wrapper);
    }

    if (request == 'get_bucket_content_data') {
      return getBucketContentData(wrapper);
    }

    if (request == 'upsert_bucket_content') {
      if(wrapper.bodyJSON.containsKey('sort_command')) {
        return sortBucketContent(wrapper);
      }

      return upsertBucketContent(wrapper);
    }

    if (request == 'set_media_title') {
      return setMediaTitle(wrapper);
    }

    if (request == 'upsert_speaker') {
      return upsertSpeaker(wrapper);
    }

    if (request == 'delete_speaker') {
      return deleteSpeaker(wrapper);
    }

    if (request == 'get_speaker_data') {
      return getSpeakerData(wrapper);
    }

    if (request == 'set_advertising') {
      return setAdvertising(wrapper);
    }

    if (request == 'delete_advertising_image') {
      return deleteAdvertisingImage(wrapper);
    }

    if (request == 'set_advertising_url') {
      return setAdvertisingUrl(wrapper);
    }

    if (request == 'get_advertising_data') {
      return getAdvertisingData(wrapper);
    }

    if (request == 'set_daily_text') {
      return setDailyText(wrapper);
    }

    if (request == 'delete_daily_text') {
      return deleteDailyText(wrapper);
    }

    if (request == 'get_daily_text_data') {
      return getDailyTextData(wrapper);
    }

    if (request == 'get_home_page_data') {
      return getHomePageData(wrapper);
    }

    if (request == 'set_content_seen') {
      return setContentSeen(wrapper);
    }

    if (request == 'search_on_data') {
      return searchOnData(wrapper);
    }

    if (request == 'get_user_statistics') {
      return getUserStatistics(wrapper);
    }

    if (request == 'search_users') {
      return searchUsers(wrapper);
    }

    return generateResultError(HttpCodes.error_requestNotDefined);
  }
  ///==========================================================================================================
  static Future<Map<String, dynamic>> getAppParameters(GraphHandlerWrap wrap) async{

    final res = generateResultOk();
    res['aid_pop_message'] = await CommonMethods.getTextData('aid_dialog');

    return res;
  }

  static Future<Map<String, dynamic>> setUserIsLogoff(GraphHandlerWrap wrap) async{
    ///for security: check requester be admin or userId == requester
    dynamic userId = wrap.bodyJSON[Keys.forUserId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final r = await UserConnectionModelDb.setUserLogoff(wrap.userId!, wrap.deviceId!);

    if(!r) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set user logoff');
    }

    final res = generateResultOk();
    res[Keys.userId] = wrap.userId;

    return res;
  }

  static Future<Map<String, dynamic>> getProfileData(GraphHandlerWrap wrap) async{
    ///for security: check requester be admin or userId == requester
    dynamic userId = wrap.bodyJSON[Keys.forUserId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(userId is String){
      userId = int.tryParse(userId);
    }

    final res = generateResultOk();
    res.addAll(await CommonMethods.getUserLoginInfo(userId, false));

    return res;
  }

  static Future<Map<String, dynamic>> setAboutUsData(GraphHandlerWrap wrapper) async{
    final data = wrapper.bodyJSON[Keys.data];

    final r = await CommonMethods.setHtmlData(wrapper.userId!, 'about_us', data);

    if(r == null || r < 1) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set about us');
    }

    return generateResultOk();
  }

  static Future<Map<String, dynamic>> getAboutUsData(GraphHandlerWrap wrapper) async{
    final r = await CommonMethods.getHtmlData('about_us');

    final res = generateResultOk();
    res[Keys.data] = r;

    return res;
  }

  static Future<Map<String, dynamic>> setAidData(GraphHandlerWrap wrapper) async{
    final data = wrapper.bodyJSON[Keys.data];

    final r = await CommonMethods.setHtmlData(wrapper.userId!, 'aid', data);

    if(r == null || r < 1) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set aid');
    }

    return generateResultOk();
  }

  static Future<Map<String, dynamic>> setAidDialogData(GraphHandlerWrap wrapper) async{
    final data = wrapper.bodyJSON[Keys.data];

    final r = await CommonMethods.setTextData('aid_dialog', data);

    if(r == null || r < 1) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set aid dialog');
    }

    return generateResultOk();
  }

  static Future<Map<String, dynamic>> getAidData(GraphHandlerWrap wrapper) async{
    final r = await CommonMethods.getHtmlData('aid');

    final res = generateResultOk();
    res[Keys.data] = r;

    return res;
  }

  static Future<Map<String, dynamic>> getAidDialogData(GraphHandlerWrap wrapper) async{
    final r = await CommonMethods.getTextData('aid_dialog');

    final res = generateResultOk();
    res[Keys.data] = r;

    return res;
  }

  static Future<Map<String, dynamic>> setTermData(GraphHandlerWrap wrapper) async{
    final data = wrapper.bodyJSON[Keys.data];

    final r = await CommonMethods.setHtmlData(wrapper.userId!, 'term', data);

    if(r == null || r < 1) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set term');
    }

    return generateResultOk();
  }

  static Future<Map<String, dynamic>> getTermData(GraphHandlerWrap wrapper) async{
    final r = await CommonMethods.getHtmlData('term');

    final res = generateResultOk();
    res[Keys.data] = r;

    return res;
  }

  static Future<Map<String, dynamic>> setTicketData(GraphHandlerWrap wrapper) async{
    final data = wrapper.bodyJSON[Keys.data];

    final r = await CommonMethods.setTicket(wrapper.userId!, data);

    if(r == null || r < 1) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set ticket');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> getTickets(GraphHandlerWrap wrapper) async{
    final tickets = await CommonMethods.getTickets(wrapper.bodyJSON);
    final senderIds = <int>{};

    for(final k in tickets){
      if(k['sender_user_id'] != null){
        senderIds.add(k['sender_user_id']);
      }
    }

    final customers = await CommonMethods.getCustomersForIds(senderIds.toList());

    final res = generateResultOk();
    res['ticket_list'] = tickets;
    res['customer_list'] = customers;
    //res['all_count'] = count;

    return res;
  }

  static Future<Map<String, dynamic>> upsertBucket(GraphHandlerWrap wrapper) async{
    final key = wrapper.bodyJSON[Keys.key];
    final bucketData = wrapper.bodyJSON[Keys.data];

    if(key == null || bucketData == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var cover = wrapper.bodyJSON['image'];
    int? mediaId;

    if(cover is String){
      final body = wrapper.request.store.get('Body');
      final coverFile = await ServerNs.uploadFile(wrapper.request, body, cover);

      if(coverFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }

      mediaId = await CommonMethods.insertMedia(coverFile);
    }

    if(wrapper.bodyJSON['delete_media_id'] != null){ // is edit mode
      //final mediaId = await CommonMethods.getMediaIdFromBucket(bucketData['id']);

      // ignore: unawaited_futures
      CommonMethods.deleteMedia(wrapper.bodyJSON['delete_media_id']);
    }

    final result = await CommonMethods.upsetBucket(wrapper.userId!, wrapper.bodyJSON, mediaId);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not upsert bucket');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> upsertSubBucket(GraphHandlerWrap wrapper) async{
    //final bucketId = wrapper.bodyJSON[Keys.id];
    final subBucketData = wrapper.bodyJSON[Keys.data];

    if(subBucketData == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var cover = wrapper.bodyJSON['cover'];
    var media = wrapper.bodyJSON['media'];
    var type = subBucketData['type'];
    File? mediaFile;
    int? mediaId;
    int? coverId;

    if(media == null && subBucketData['id'] == null && type != 10){
      return generateResultError(HttpCodes.error_notUpload);
    }

    if(media != null) {
      final body = wrapper.request.store.get('Body');
      mediaFile = await ServerNs.uploadFile(wrapper.request, body, media);
    }

    if(subBucketData['duration'] == null){
      try {
        final args = ['-v', 'quiet', '-hide_banner', '-show_entries', 'stream=duration',
          '-of', 'default=noprint_wrappers=1:nokey=1', mediaFile?.path?? ''];

        final result = await Process.run('ffprobe', args);
        var d = Duration(seconds: double.parse(result.stdout).toInt());

        subBucketData['duration'] = d.inMilliseconds;
      }
      catch (e){/**/}
    }

    if(mediaFile != null) {
      mediaId = await CommonMethods.insertMedia(
        mediaFile,
        duration: subBucketData['duration'],
        fileName: wrapper.bodyJSON[Keys.fileName],
      );
    }
    else {
      mediaId = subBucketData['media_id'];
    }

    if(cover is String){
      final body = wrapper.request.store.get('Body');
      final coverFile = await ServerNs.uploadFile(wrapper.request, body, cover);

      if(coverFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }

      coverId = await CommonMethods.insertMedia(coverFile, extension: '.png');
    }

    if(wrapper.bodyJSON['delete_cover_id'] != null){ // is edit mode
      // ignore: unawaited_futures
      CommonMethods.deleteMedia(wrapper.bodyJSON['delete_cover_id']);
    }

    if(wrapper.bodyJSON['delete_media_id'] != null){ // is edit mode
      // ignore: unawaited_futures
      CommonMethods.deleteMedia(wrapper.bodyJSON['delete_media_id']);
    }

    final result = await CommonMethods.upsetSubBucket(wrapper.bodyJSON, coverId, mediaId, null);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not upsert bucket');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> deleteBucket(GraphHandlerWrap wrapper) async{
    final bucketId = wrapper.bodyJSON[Keys.id];

    if(bucketId == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final mediaId = await CommonMethods.getMediaIdFromBucket(bucketId);

    if(mediaId != null) {
      // ignore: unawaited_futures
      CommonMethods.deleteMedia(mediaId);
    }

    final result = await CommonMethods.deleteBucket(bucketId);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete bucket');
    }

    final subIds = await CommonMethods.findSubBucketIdsByBucket(bucketId);

    if(subIds != null){
      for(final k in subIds){
        await deleteSubBucket(null, subBucketId: k);
      }
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> getBucketData(GraphHandlerWrap wrapper) async{
    final key = wrapper.bodyJSON[Keys.key];

    if(key == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final buckets = await CommonMethods.getBuckets(wrapper.bodyJSON);

    if(buckets == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not get bucket');
    }

    final count = await CommonMethods.getBucketsCount(wrapper.bodyJSON);

    var mediaIds = <int>{};

    for(final k in buckets){
      if(k['media_id'] != null){
        mediaIds.add(k['media_id']);
      }
    }

    final mediaList = await CommonMethods.getMediasByIds(mediaIds.toList());

    final res = generateResultOk();
    res['bucket_list'] = buckets;
    res['media_list'] = mediaList?? [];
    res['all_count'] = count;

    return res;
  }

  static Future<Map<String, dynamic>> getSubBucketData(GraphHandlerWrap wrapper) async{
    final parentId = wrapper.bodyJSON[Keys.id];

    if(parentId == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final subBuckets = await CommonMethods.getSubBuckets(wrapper.bodyJSON);

    if(subBuckets == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not get sub-bucket');
    }

    final count = await CommonMethods.getSubBucketsCount(wrapper.bodyJSON);

    final mediaIds = <int>{};

    for(final k in subBuckets){
      if(k['media_id'] != null){
        mediaIds.add(k['media_id']);
      }

      if(k['cover_id'] != null){
        mediaIds.add(k['cover_id']);
      }
    }

    final mediaList = await CommonMethods.getMediasByIds(mediaIds.toList());

    final res = generateResultOk();
    res['sub_bucket_list'] = subBuckets;
    res['media_list'] = mediaList?? [];
    res['all_count'] = count;

    return res;
  }

  static Future<Map<String, dynamic>> upsertBucketContent(GraphHandlerWrap wrapper) async{
    final List? medias = wrapper.bodyJSON['medias_parts'];
    final Map? mediasInfo = wrapper.bodyJSON['medias_info'];
    final speaker = wrapper.bodyJSON['speaker'];

    if(medias == null || mediasInfo == null || speaker == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final mediaIdList = <int>[];
    final speakerId = speaker['id'];

    final body = wrapper.request.store.get('Body');

    for(final k in medias){
      final mediaFile = await ServerNs.uploadFile(wrapper.request, body, k);

      if(mediaFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }

      final info = mediasInfo[k];

      if(info['duration'] == null){
        try {
          final args = ['-v', 'quiet', '-hide_banner', '-show_entries', 'stream=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1', mediaFile.path];

          final result = await Process.run('ffprobe', args);
          var d = Duration(seconds: double.parse(result.stdout).toInt());

          info['duration'] = d.inMilliseconds;
        }
        catch (e){/**/}
      }

      final mediaId = await CommonMethods.insertMedia(
        mediaFile,
        duration: info['duration'],
        extension: info['extension'],
        fileName: info[Keys.fileName],
      );

      mediaIdList.add(mediaId);
    }


    final deletedIds = wrapper.bodyJSON['delete_media_ids'];

    if(deletedIds != null){ // is edit mode
      for(final k in deletedIds){
        // ignore: unawaited_futures
        CommonMethods.deleteMedia(k);
      }
    }

    final contentId = await CommonMethods.upsetBucketContent(wrapper.bodyJSON, speakerId, mediaIdList);

    if(contentId < 0) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not upsert content');
    }

    final pId = wrapper.bodyJSON['parent_id'];
    await CommonMethods.setContentIdToSubBucket(pId, contentId);

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> sortBucketContent(GraphHandlerWrap wrapper) async{
    final medias = Converter.correctList<int>(wrapper.bodyJSON['media_ids']);
    final parentId = wrapper.bodyJSON['parent_id'];
    final contentId = wrapper.bodyJSON[Keys.id];
    final forceOrder = wrapper.bodyJSON['force_order']?? true;

    if(medias == null || parentId == null || contentId == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isOk = await CommonMethods.sortBucketContent(contentId, medias, forceOrder);

    if(isOk < 1) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sort bucket content');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> getBucketContentData(GraphHandlerWrap wrapper) async{
    final subBucketId = wrapper.bodyJSON[Keys.id];

    if(subBucketId == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final content = await CommonMethods.getBucketContent(wrapper.bodyJSON);

    if(content == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not get content of bucket');
    }

    //final count = await CommonMethods.getSubBucketsCount(wrapper.bodyJSON);
    final speakerId = content['speaker_id']?? 0;
    final speaker = await CommonMethods.getSpeaker(speakerId);

    var mediaIds = <int>{};

    if(speaker != null && speaker['media_id'] != null) {
      mediaIds.add(speaker['media_id']);
    }

    if(content['media_ids'] != null) {
      mediaIds.addAll(Converter.correctList<int>(content['media_ids'])!);
    }

    final mediaList = await CommonMethods.getMediasByIds(mediaIds.toList());

    final res = generateResultOk();
    res['content'] = content;
    res['media_list'] = mediaList?? [];
    res['seen_list'] = await CommonMethods.getContentSeenList(wrapper.userId!, subBucketId, content['id']);
    res['speaker'] = speaker;
    //res['all_count'] = count;

    return res;
  }

  static Future<Map<String, dynamic>> deleteSubBucket(GraphHandlerWrap? wrapper, {int? subBucketId}) async{
    final subBucket_Id = subBucketId?? wrapper!.bodyJSON[Keys.id];

    if(subBucket_Id == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final mediaId = await CommonMethods.getMediaIdFromSubBucket(subBucket_Id);

    if(mediaId != null) {
      // ignore: unawaited_futures
      CommonMethods.deleteMedia(mediaId);
    }

    final coverId = await CommonMethods.getCoverIdFromSubBucket(subBucket_Id);

    if(coverId != null) {
      // ignore: unawaited_futures
      CommonMethods.deleteMedia(coverId);
    }

    final contentId = await CommonMethods.deleteSubBucket(subBucket_Id);

    if(contentId != null) {
      await CommonMethods.deleteContentAndMedias(contentId);
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> getSpeakerData(GraphHandlerWrap wrapper) async{
    final speakers = await CommonMethods.getSpeakers(wrapper.bodyJSON);

    if(speakers == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not get speakers');
    }

    final count = await CommonMethods.getSpeakersCount(wrapper.bodyJSON);

    var mediaIds = <int>{};

    for(final k in speakers){
      if(k['media_id'] != null){
        mediaIds.add(k['media_id']);
      }
    }

    final mediaList = await CommonMethods.getMediasByIds(mediaIds.toList());

    final res = generateResultOk();
    res['speaker_list'] = speakers;
    res['media_list'] = mediaList?? [];
    res['all_count'] = count;

    return res;
  }

  static Future<Map<String, dynamic>> setMediaTitle(GraphHandlerWrap wrapper) async{
    final mediaId = wrapper.bodyJSON[Keys.id];
    final title = wrapper.bodyJSON[Keys.title];

    if(mediaId == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final result = await CommonMethods.updateMediaTitle(mediaId, title);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set title to media');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> upsertSpeaker(GraphHandlerWrap wrapper) async{
    final speakerData = wrapper.bodyJSON[Keys.data];

    if(speakerData == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var profile = wrapper.bodyJSON['image'];
    int? mediaId;

    if(profile is String){
      final body = wrapper.request.store.get('Body');
      final profileFile = await ServerNs.uploadFile(wrapper.request, body, profile);

      if(profileFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }

      mediaId = await CommonMethods.insertMedia(profileFile);
    }

    if(wrapper.bodyJSON['delete_media_id'] != null){ // is edit mode
      // ignore: unawaited_futures
      CommonMethods.deleteMedia(wrapper.bodyJSON['delete_media_id']);
    }

    final result = await CommonMethods.upsetSpeaker(wrapper.bodyJSON, mediaId);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not upsert speaker');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> deleteSpeaker(GraphHandlerWrap wrapper) async{
    final speakerId = wrapper.bodyJSON[Keys.id];

    if(speakerId == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final mediaId = await CommonMethods.getMediaIdFromSpeaker(speakerId);

    if(mediaId != null) {
      // ignore: unawaited_futures
      CommonMethods.deleteMedia(mediaId);
    }

    final result = await CommonMethods.deleteSpeaker(speakerId);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete speaker');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> setAdvertising(GraphHandlerWrap wrapper) async{
    final tag = wrapper.bodyJSON['tag'];

    if(tag == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var advMedia = wrapper.bodyJSON['media'];
    int? mediaId;

    if(advMedia is String){
      final body = wrapper.request.store.get('Body');
      final advMediaFile = await ServerNs.uploadFile(wrapper.request, body, advMedia);

      if(advMediaFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }

      mediaId = await CommonMethods.insertMedia(advMediaFile);
    }

    final result = await CommonMethods.insertAdvertising(wrapper.bodyJSON, mediaId);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not insert adv');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> deleteAdvertisingImage(GraphHandlerWrap wrapper) async{
    final tag = wrapper.bodyJSON['tag'];

    if(tag == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final result = await CommonMethods.deleteAdvertising(tag);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete adv image');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> setAdvertisingUrl(GraphHandlerWrap wrapper) async{
    final tag = wrapper.bodyJSON['tag'];
    final url = wrapper.bodyJSON['url'];

    if(tag == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final result = await CommonMethods.setAdvertisingUrl(tag, url);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set adv url');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> getAdvertisingData(GraphHandlerWrap wrapper) async{
    final advertising = await CommonMethods.getAdvertising(wrapper.bodyJSON);

    if(advertising == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not get advertising');
    }

    var mediaIds = <int>{};

    for(final k in advertising){
      if(k['media_id'] != null){
        mediaIds.add(k['media_id']);
      }
    }

    final mediaList = await CommonMethods.getMediasByIds(mediaIds.toList());

    final res = generateResultOk();
    res['advertising_list'] = advertising;
    res['media_list'] = mediaList?? [];

    return res;
  }

  static Future<Map<String, dynamic>> setDailyText(GraphHandlerWrap wrapper) async{
    final text = wrapper.bodyJSON['text'];
    final date = wrapper.bodyJSON[Keys.date];
    final id = wrapper.bodyJSON[Keys.id];

    if(text == null || date == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final eventId = await CommonMethods.insertDailyText(id, text, date);

    if(eventId == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set daily text');
    }

    final res = generateResultOk();
    res[Keys.id] = eventId;

    return res;
  }

  static Future<Map<String, dynamic>> deleteDailyText(GraphHandlerWrap wrapper) async{
    final date = wrapper.bodyJSON[Keys.date];
    final id = wrapper.bodyJSON[Keys.id];

    if(id == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isOk = await CommonMethods.deleteDailyText(id, date);

    if(!isOk) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete daily text');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> getDailyTextData(GraphHandlerWrap wrapper) async{
    var startDate = wrapper.bodyJSON[Keys.date];
    var endDate = wrapper.bodyJSON['end_date'];


    if(startDate == null) {
      final s = GregorianDate().getFirstOfMonth();
      s.changeTime(0, 0, 0, 0);
      startDate = DateHelper.toTimestamp(s.convertToSystemDate());
    }

    if(endDate == null) {
      final start = DateHelper.tsToSystemDate(startDate)!;
      final end = GregorianDate.from(start).getEndOfMonth();
      end.changeTime(23, 59, 59, 999);
      endDate = DateHelper.toTimestamp(end.convertToSystemDate());
    }

    final list = await CommonMethods.getDailyText(startDate, endDate);

    if(list == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not get daily text');
    }

    final res = generateResultOk();
    res[Keys.dataList] = list;
    return res;
  }

  static Future<Map<String, dynamic>> getHomePageData(GraphHandlerWrap wrapper) async{
    final sf = SearchFilterTool();
    sf.limit = 8;

    final meditations = await CommonMethods.getNewSubBucketsByType(sf, '4');
    final video = await CommonMethods.getNewSubBucketsByType(sf, '1');
    final news = await CommonMethods.getNewSubBuckets();

    final mediaIds = <int>{};

    if(news != null) {
      for (final k in news) {
        if (k['media_id'] != null) {
          mediaIds.add(k['media_id']);
        }

        if (k['cover_id'] != null) {
          mediaIds.add(k['cover_id']);
        }
      }
    }

    if(meditations != null) {
      for (final k in meditations) {
        if (k['media_id'] != null) {
          mediaIds.add(k['media_id']);
        }

        if (k['cover_id'] != null) {
          mediaIds.add(k['cover_id']);
        }
      }
    }

    if(video != null) {
      for (final k in video) {
        if (k['media_id'] != null) {
          mediaIds.add(k['media_id']);
        }

        if (k['cover_id'] != null) {
          mediaIds.add(k['cover_id']);
        }
      }
    }

    final mediaList = await CommonMethods.getMediasByIds(mediaIds.toList());

    final res = generateResultOk();
    res['media_list'] = mediaList;
    res['new_list'] = news;
    res['new_meditation_list'] = meditations;
    res['new_video_list'] = video;
    return res;
  }

  static Future<Map<String, dynamic>> setContentSeen(GraphHandlerWrap wrapper) async{
    final subBucketId = wrapper.bodyJSON[Keys.id];
    final contentId = wrapper.bodyJSON['content_id'];
    final mediaId = wrapper.bodyJSON['media_id'];

    if(subBucketId == null || contentId == null || mediaId == null || wrapper.userId == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isOk = await CommonMethods.addContentSeen(wrapper.userId!, subBucketId, contentId, mediaId);

    if(!isOk){
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set content seen');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> searchOnData(GraphHandlerWrap wrapper) async{
    final searchFilter = wrapper.bodyJSON[Keys.searchFilter];

    if(searchFilter == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final sf = SearchFilterTool.fromMap(searchFilter);
    final list = await CommonMethods.searchSubBuckets(sf);

    final mediaIds = <int>{};

    for (final k in list) {
      if (k['media_id'] != null) {
        mediaIds.add(k['media_id']);
      }

      if (k['cover_id'] != null) {
        mediaIds.add(k['cover_id']);
      }
    }

    final mediaList = await CommonMethods.getMediasByIds(mediaIds.toList());

    final res = generateResultOk();
    res['sub_bucket_list'] = list;
    res['media_list'] = mediaList;
    return res;
  }

  static Future<Map<String, dynamic>> deleteProfileAvatar(GraphHandlerWrap wrapper) async{
    dynamic forUserId = wrapper.bodyJSON[Keys.forUserId];

    if(forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(forUserId is String) {
      forUserId = int.tryParse(forUserId);
    }

    final del = await UserMediaModelDb.deleteProfileImage(forUserId, 1);

    if(!del) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not delete from[UserImages]');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    return res;
  }

  static Future<Map<String, dynamic>> updateProfileUserName(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    String? userName = js[Keys.userName];

    if(forUserId == null || userName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(userName.isEmpty){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserNameModelDb.changeUserName(forUserId, userName);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save userName');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateProfileNameFamily(GraphHandlerWrap wrapper) async{
    dynamic forUserId = wrapper.bodyJSON[Keys.forUserId];
    String? name = wrapper.bodyJSON[Keys.name];
    String? family = wrapper.bodyJSON[Keys.family];

    if(forUserId == null || name == null || family == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(forUserId is String){
      forUserId = int.tryParse(forUserId);
    }

    if(name.isEmpty || family.isEmpty){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserModelDb.changeNameFamily(forUserId, name, family);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save name family');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateProfileSex(GraphHandlerWrap wrapper) async{
    dynamic forUserId = wrapper.bodyJSON[Keys.forUserId];
    int? sex = wrapper.bodyJSON[Keys.sex];

    if(forUserId == null || sex == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(forUserId is String){
      forUserId = int.tryParse(forUserId);
    }

    final okDb = await UserModelDb.changeUserSex(forUserId, sex);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save sex');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateProfileBirthDate(GraphHandlerWrap wrapper) async{
    dynamic forUserId = wrapper.bodyJSON[Keys.forUserId];
    String? birthDate = wrapper.bodyJSON[Keys.date];

    if(forUserId == null || birthDate == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(forUserId is String){
      forUserId = int.tryParse(forUserId);
    }

    final okDb = await UserModelDb.changeUserBirthDate(forUserId, birthDate);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save birthDate');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateProfileAvatar(GraphHandlerWrap wrapper) async{
    dynamic forUserId = wrapper.bodyJSON[Keys.forUserId];
    final partName = wrapper.bodyJSON[Keys.partName];
    final fileName = wrapper.bodyJSON[Keys.fileName];

    if(forUserId == null || partName == null || fileName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(forUserId is String){
      forUserId = int.tryParse(forUserId);
    }

    final body = wrapper.request.store.get('Body');
    //final file = body[partName] as HttpBodyFileUpload;
    final savedFile = await ServerNs.uploadFile(wrapper.request, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final okDb = await UserMediaModelDb.addUserImage(forUserId, 1, savedFile.path, savedFile.lengthSync());

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save [UserImages]');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;
    res[Keys.url] = PathsNs.genUrlDomainFromFilePath(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path);
    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    //--- To other user chats ------------------------------------
    //WsMessenger.sendDataToOtherUserChats(userId, 'todo');

    return res;
  }

  static Future<Map<String, dynamic>> updateUserCountryIso(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    String? countryCode = js[Keys.phoneCode];
    String? countryIso = js[Keys.countryIso];

    if(userId == null || countryCode == null || countryIso == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserCountryModelDb.upsertUserCountry(userId, countryIso);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save user Country');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(userId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> setUserBlockingState(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];
    final forUserId = js[Keys.forUserId];
    bool? state = js[Keys.state];
    String? cause = js[Keys.cause];

    if(forUserId == null || state == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    // before call this method ,check requester is manager

    if(state) {
      final okDb = await UserBlockListModelDb.blockUser(forUserId, blocker: requesterId, cause: cause);

      if(!okDb) {
        return generateResultError(HttpCodes.error_databaseError , cause: 'Not change user block state');
      }
    }
    else {
      final okDb = await UserBlockListModelDb.unBlockUser(forUserId);

      if(okDb == null || okDb < 1) {
        return generateResultError(HttpCodes.error_databaseError , cause: 'Not change user block state');
      }
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To all user's devices ------------------------------------
    WsMessenger.sendYouAreBlocked(forUserId);

    return res;
  }

  static Future<Map<String, dynamic>> getUserStatistics(GraphHandlerWrap wrapper) async{
    final statistics = await StatisticsApis.getUserStatistics();

    final res = generateResultOk();
    res.addAll(statistics);

    return res;
  }

  static Future<Map<String, dynamic>> searchUsers(GraphHandlerWrap wrapper) async{
    final searchFilter = wrapper.bodyJSON[Keys.searchFilter];

    if(searchFilter == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final sf = SearchFilterTool.fromMap(searchFilter);
    final list = await CommonMethods.searchOnUsers(sf);


    final res = generateResultOk();
    res[Keys.data] = list;

    return res;
  }

}