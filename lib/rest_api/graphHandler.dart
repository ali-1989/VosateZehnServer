import 'dart:async';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:vosate_zehn_server/database/models/userBlockList.dart';
import 'package:vosate_zehn_server/database/models/userConnection.dart';
import 'package:vosate_zehn_server/database/models/userCountry.dart';
import 'package:vosate_zehn_server/database/models/userMedia.dart';
import 'package:vosate_zehn_server/database/models/users.dart';
import 'package:vosate_zehn_server/database/models/userNameId.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/ServerNs.dart';
import 'package:vosate_zehn_server/rest_api/adminCommands.dart';
import 'package:vosate_zehn_server/rest_api/commonMethods.dart';
import 'package:vosate_zehn_server/rest_api/fakeAndHack.dart';
import 'package:vosate_zehn_server/rest_api/httpCodes.dart';
import 'package:vosate_zehn_server/rest_api/loginZone.dart';
import 'package:vosate_zehn_server/rest_api/registerZone.dart';
import 'package:vosate_zehn_server/rest_api/wsMessenger.dart';

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

    req.store.set('Body', body);
    PublicAccess.logInDebug(bJSON.toString());

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
    
    if (requesterId != null) {
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
      final wrapper = GraphHandlerWrap();
      wrapper.request = req;
      wrapper.response = res;
      wrapper.bodyJSON = bJSON;
      wrapper.zoneRequest = request;
      wrapper.userId = requesterId;
      wrapper.deviceId = deviceId;

      return await _process(wrapper);
    }
    catch (e){
      PublicAccess.logInDebug('>>> Error in process graph-request:\n$e');
      rethrow;
    }
  }
  ///==========================================================================================================
  static Future<Map<String, dynamic>> _process(GraphHandlerWrap wrapper) async {
    final request = wrapper.zoneRequest;
    
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

    if (request == 'verify_otp') {
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

    if (request == 'upsert_bucket') {
      return upsertBucket(wrapper);
    }

    if (request == 'get_bucket_data') {
      return getBucketData(wrapper);
    }

    if (request == 'get_sub_bucket_data') {
      return getSubBucketData(wrapper);
    }

    if (request == 'get_bucket_content_data') {
      return getBucketContentData(wrapper);
    }



    return generateResultError(HttpCodes.error_requestNotDefined);
  }
  ///==========================================================================================================
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

  static Future<Map<String, dynamic>> upsertBucket(GraphHandlerWrap wrapper) async{
    final key = wrapper.bodyJSON[Keys.key];
    final bucketData = wrapper.bodyJSON[Keys.data];

    if(key == null || bucketData == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var image = wrapper.bodyJSON['image'];
    int? mediaId;

    if(image is String){
      final body = wrapper.request.store.get('Body');
      final savedFile = await ServerNs.uploadFile(wrapper.request, body, image);

      if(savedFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }

      mediaId = await CommonMethods.insertMedia(savedFile);
    }

    final result = await CommonMethods.upsetBucket(wrapper.userId!, wrapper.bodyJSON, mediaId);

    if(!result) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not upsert bucket');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> getBucketData(GraphHandlerWrap wrapper) async{
    final key = wrapper.bodyJSON[Keys.key];

    if(key == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final buckets = await CommonMethods.getBuckets(wrapper.userId!, wrapper.bodyJSON);

    if(buckets == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not get bucket');
    }

    var mediaIds = <int>{};

    for(final k in buckets){
      if(k['media_id'] != null){
        mediaIds.add(k['media_id']);
      }
    }

    final mediaList = await CommonMethods.getMediasByIds(wrapper.userId!, mediaIds.toList());

    final res = generateResultOk();
    res['bucket_list'] = buckets;
    res['media_list'] = mediaList?? [];
    res['all_count'] = 0;

    return res;
  }

  static Future<Map<String, dynamic>> getSubBucketData(GraphHandlerWrap wrapper) async{
    final modelId = wrapper.bodyJSON[Keys.id];

    if(modelId == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    /*final r = await CommonMethods.setTicket(wrapper.userId!, data);

    if(r == null || r < 1) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set ticket');
    }*/

    final res = generateResultOk();
    res.addAll(FakeAndHack.simulate_getLevel2(wrapper));

    return res;
  }

  static Future<Map<String, dynamic>> getBucketContentData(GraphHandlerWrap wrapper) async{
    final level2Id = wrapper.bodyJSON[Keys.id];

    if(level2Id == null){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    /*final r = await CommonMethods.setTicket(wrapper.userId!, data);

    if(r == null || r < 1) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set ticket');
    }*/

    final res = generateResultOk();
    res.addAll(FakeAndHack.simulate_getLevel2Content(wrapper));

    return res;
  }









  static Future<Map<String, dynamic>> deleteProfileAvatar(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final del = await UserMediaModelDb.deleteProfileImage(userId, 1);

    if(!del) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not delete from[UserImages]');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    return res;
  }

  /*static Future<Map<String, dynamic>> updateProfileAvatar(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final partName = js[Keys.partName];
    final fileName = js[Keys.fileName];

    if(userId == null || partName == null || fileName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final body = req.store.get('Body');
    //final file = body[partName] as HttpBodyFileUpload;
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final okDb = await UserImageModelDb.upsertUserImage(userId, 1, savedFile.path);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save [UserImages]');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;
    res[Keys.fileUri] = PathsNs.genUrlDomainFromFilePath(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path);
    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(userId, JsonHelper.mapToJson(match));

    //--- To other user chats ------------------------------------
    WsMessenger.sendDataToOtherUserChats(userId, 'todo');

    return res;
  }

  static Future<Map<String, dynamic>> updateBodyPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    final partName = js[Keys.partName]; // back_photo, front_photo
    final fileName = js[Keys.fileName];

    if(userId == null || partName == null || fileName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final body = req.store.get('Body');
    //final file = body[partName] as HttpBodyFileUpload;
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final uri = PathsNs.genUrlDomainFromLocalPathByDecoding(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path)!;

    final okDb = await UserFitnessDataModelDb.upsertUserFitnessImage(userId, partName, uri);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save [fitness Image]');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;
    res[Keys.fileUri] = uri;
    res.addAll(await UserFitnessDataModelDb.getUserFitnessStatusJs(userId));

    //--------- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));
    //---------------------------------------------------------------
    return res;
  }
*/
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

  //@ admin
  static Future<Map<String, dynamic>> updateProfileNameFamily(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    String? name = js[Keys.name];
    String? family = js['family'];

    if(forUserId == null || name == null || family == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
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

  //@ admin
  static Future<Map<String, dynamic>> updateProfileSex(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    int? sex = js['sex'];

    if(forUserId == null || sex == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
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

  //@ admin
  static Future<Map<String, dynamic>> updateProfileBirthDate(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    String? birthDate = js['birthdate'];

    if(forUserId == null || birthDate == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
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

  /*static Future<Map<String, dynamic>> deleteBodyPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    String? nodeName = js[Keys.nodeName];
    String? date = js[Keys.date];
    final uri = js[Keys.imageUri];

    if(userId == null || deviceId == null || nodeName == null || date == null || uri == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserFitnessDataModelDb.deleteUserFitnessImage(userId, nodeName, date, uri);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete User FitnessStatus image');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;
    res.addAll(await UserFitnessDataModelDb.getUserFitnessStatusJs(userId));

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(
        section: HttpCodes.sec_userData,
        command: HttpCodes.com_updateProfileSettings
    );
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }
*/
  static Future<Map<String, dynamic>> addAdvertising(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];
    final partName = js[Keys.partName];
    final fileName = js[Keys.fileName];

    if(requesterId == null || partName == null || fileName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final body = req.store.get('Body');
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final okDb = await CommonMethods.addNewAdvertising(requesterId, js, savedFile.path);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add new Advertising');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> deleteAdvertising(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final id = js['advertising_id'];

    if(userId == null || id == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.deleteAdvertising(userId, id);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete Advertising');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingShowState(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final state = js[Keys.state];

    if(userId == null || advId == null || state == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingShowState(userId, advId, state);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising state');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingTitle(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final title = js[Keys.title];

    if(userId == null || advId == null || title == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingTitle(userId, advId, title);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising title');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingTag(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final tag = js['tag'];

    if(userId == null || advId == null || tag == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingTag(userId, advId, tag);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising tag');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingType(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final type = js[Keys.type];

    if(userId == null || advId == null || type == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingType(userId, advId, type);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising type');
    }

    final res = generateResultOk();
    return res;
  }

  /*static Future<Map<String, dynamic>> changeAdvertisingPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];
    final advId = js['advertising_id'];
    final fileName = js[Keys.fileName];
    final partName = js[Keys.partName];

    if(requesterId == null || fileName == null || partName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(requesterId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final body = req.store.get('Body');
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final okDb = await CommonMethods.changeAdvertisingPhoto(requesterId, advId, savedFile.path);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising photo');
    }

    final res = generateResultOk();
    res[Keys.fileUri] = PathsNs.genUrlDomainFromFilePath(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path);

    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingOrder(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final orderNum = js['order_num'];

    if(userId == null || orderNum == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingOrder(userId, advId, orderNum);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising orderNum');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingDate(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final section = js[Keys.section];
    final dateTs = js[Keys.date];

    if(userId == null || section == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingDate(userId, advId, section, dateTs);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising date');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingLink(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final link = js['link'];

    if(userId == null || link == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingLink(userId, advId, link);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising link');
    }

    final res = generateResultOk();

    return res;
  }*/
}