import 'dart:async';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/api/helpers/LocaleHelper.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:vosate_zehn_server/services/sms_0098.dart';
import 'package:vosate_zehn_server/database/databaseNs.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/database/models/emailModel.dart';
import 'package:vosate_zehn_server/database/models/mobileNumber.dart';
import 'package:vosate_zehn_server/database/models/register.dart';
import 'package:vosate_zehn_server/database/models/users.dart';
import 'package:vosate_zehn_server/database/models/userConnection.dart';
import 'package:vosate_zehn_server/database/models/userCountry.dart';
import 'package:vosate_zehn_server/database/models/userNameId.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/models/userTypeModel.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/commonMethods.dart';
import 'package:vosate_zehn_server/rest_api/graphHandler.dart';
import 'package:vosate_zehn_server/rest_api/httpCodes.dart';
import 'package:vosate_zehn_server/rest_api/loginZone.dart';

class RegisterZone {
  RegisterZone._();

  static Future<Map<String, dynamic>?> checkCanRegister(GraphHandlerWrap wrapper, PreRegisterModelDb model) async{

    if (model.name == null || model.family == null
        ||
        (model.email == null && model.mobileNumber == null)
    //|| model.userName == null
    //|| model.password == null
    ) {
      return GraphHandler.generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    /*if (await UserNameModelDb.existThisUserName(model.userName)) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'ExistUserName');
    }*/

    if(model.mobileNumber != null){
      if (await MobileNumberModelDb.existThisMobile(model.userType!, model.phoneCode, model.mobileNumber)) {
        return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'existMobile');
      }

      /*if (await RegisterModelDb.existRegisteringFor(model.userName, model.phoneCode, model.mobileNumber)) {
        return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'ExistUserName');
      }*/
    }

    if(model.email != null){
      if (await UserEmailDb.existThisEmail(model.userType!, model.email!)) {
        return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'existEmail');
      }
    }

    /*if (await PublicAccess.psql2.exist(DbNames.T_BadWords, "word = '${model.userName}'")) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'NotAcceptUserName');
    }

    if (await PublicAccess.psql2.exist(DbNames.T_ReservedWords, "word = '${model.userName}'")) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'NotAcceptUserName');
    }*/

    return null;
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> preRegisterWithFullDataAndSendOtp(GraphHandlerWrap wrapper) async {
    final appName = wrapper.bodyJSON[Keys.appName];
    //final isExerciseTrainer = json['is_exercise_trainer'];

    final preRegisterModel = PreRegisterModelDb.fromMap(wrapper.bodyJSON);
    preRegisterModel.userType = UserTypeModel.getUserTypeNumByAppName(appName);

    final canRegister = await checkCanRegister(wrapper, preRegisterModel);

    if(canRegister != null) {
      return canRegister;
    }

    /*if(isFoodTrainer != null || isExerciseTrainer != null){
      var extra = {
        'is_exercise_trainer':isExerciseTrainer,
        'is_food_trainer':isFoodTrainer
      };
      preRegisterModel.extra_js = extra;
    }*/

    //no need: preRegisterModel.id = await DatabaseNs.getNextSequenceNumeric(DbNames.Seq_NewUser);
    preRegisterModel.verify_code = Generator.getRandomInt(10099, 98989).toString();

    var x = await PreRegisterModelDb.upsertModel(preRegisterModel);

    if(x != null && x > 0) {
      final res = GraphHandler.generateResultOk();
      res[Keys.mobileNumber] = preRegisterModel.mobileNumber;
      res[Keys.phoneCode] = preRegisterModel.phoneCode;

      final text = PublicAccess.getVerifySmsTemplate() + preRegisterModel.verify_code;

      final pc = preRegisterModel.phoneCode.toString().replaceFirst(RegExp(r'\+'), '00');
      // ignore: unawaited_futures
      Sms0098.sendSms(pc + preRegisterModel.mobileNumber!, text);

      return res;
    }
    else {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError);
    }
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> preRegisterByMobileAndSendOtp(GraphHandlerWrap wrapper) async{
    var mobileNumber = wrapper.bodyJSON[Keys.mobileNumber];
    var phoneCode = wrapper.bodyJSON[Keys.phoneCode];
    final countryIso = wrapper.bodyJSON[Keys.countryIso];
    final appName = wrapper.bodyJSON[Keys.appName];

    if (phoneCode == null || mobileNumber == null || appName == null) {
      return GraphHandler.generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    mobileNumber = LocaleHelper.numberToEnglish(mobileNumber.trim());
    phoneCode = LocaleHelper.numberToEnglish(phoneCode.trim());

    final vCode = Generator.generateIntId(4);

    final model = PreRegisterModelDb();
    model.userType = UserTypeModel.getUserTypeNumByAppName(appName);
    model.country_iso = countryIso;
    model.phoneCode = phoneCode;
    model.mobileNumber = mobileNumber;
    model.verify_code = '$vCode';

    final upsert = await PreRegisterModelDb.upsertModel(model);

    if(upsert > -1) {
      var send = 'وسعت ذهن';
      send += '\n\n';
      send += 'code: $vCode';

      phoneCode = phoneCode!.replaceFirst('\+', '00');
      // ignore: unawaited_futures
      Sms0098.sendSms(phoneCode + mobileNumber!, send);

      return GraphHandler.generateResultOk();
    }
    else {
      return GraphHandler.generateResultError(HttpCodes.error_databaseError);
    }
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> verifyOtpAndCompletePreRegistering(GraphHandlerWrap wrapper) async {
    String? mobileNumber = wrapper.bodyJSON[Keys.mobileNumber];
    String? phoneCode = wrapper.bodyJSON[Keys.phoneCode];
    String? code = wrapper.bodyJSON['code'];
    String? deviceId = wrapper.bodyJSON[Keys.deviceId];
    String? appName = wrapper.bodyJSON[Keys.appName];

    if (mobileNumber == null || phoneCode == null || code == null || deviceId == null) {
      return GraphHandler.generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    phoneCode = LocaleHelper.numberToEnglish(phoneCode.trim());
    mobileNumber = LocaleHelper.numberToEnglish(mobileNumber.trim());
    code = LocaleHelper.numberToEnglish(code.trim());
    var type = UserTypeModel.getUserTypeNumByAppName(appName);

    var exist = await PreRegisterModelDb.existRegisteringUser(type, phoneCode, mobileNumber);

    if(!exist){
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'MobileNotFound');
    }

    exist = await PreRegisterModelDb.isTimeoutRegistering(type, phoneCode, mobileNumber);

    if(exist){
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'TimeOut');
    }

    exist = await PreRegisterModelDb.existUserAndCode(type, phoneCode!, mobileNumber!, code!);

    if (PublicAccess.otpHackCode != code && !exist) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'NotCorrect');
    }

    var rMap = await PreRegisterModelDb.fetchModelMap(type, phoneCode, mobileNumber);
    var user = PreRegisterModelDb.fromMap(rMap as Map<String, dynamic>);

    return completeRegistering(wrapper, user);
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> resendSavedOtp(GraphHandlerWrap wrapper) async {
    String? mobileNumber = wrapper.bodyJSON[Keys.mobileNumber];
    String? phoneCode = wrapper.bodyJSON[Keys.phoneCode];
    String? appName = wrapper.bodyJSON[Keys.appName];

    if (mobileNumber == null || phoneCode == null) {
      return GraphHandler.generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var type = UserTypeModel.getUserTypeNumByAppName(appName);

    String? code = await PreRegisterModelDb.fetchRegisterCode(type, phoneCode, mobileNumber);

    if (!TextHelper.isEmptyOrNull(code)) {
      phoneCode = phoneCode.replaceFirst('\+', '00');
      code = PublicAccess.getVerifySmsTemplate() + code!;
      // ignore: unawaited_futures
      Sms0098.sendSms(phoneCode + mobileNumber, code);

      return GraphHandler.generateResultOk();
    }
    else {
      return GraphHandler.generateResultError(HttpCodes.error_dataNotExist);
    }
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> registerUserWithFullData(GraphHandlerWrap wrapper) async {
    final appName = wrapper.bodyJSON[Keys.appName];
    //final isExerciseTrainer = json['is_exercise_trainer'];

    final preRegisterModel = PreRegisterModelDb.fromMap(wrapper.bodyJSON);
    preRegisterModel.userType = UserTypeModel.getUserTypeNumByAppName(appName);

    final canRegister = await checkCanRegister(wrapper, preRegisterModel);

    if(canRegister != null) {
      return canRegister;
    }

    //preRegisterModel.id = await DatabaseNs.getNextSequenceNumeric(DbNames.Seq_NewUser);

    final x = await PreRegisterModelDb.upsertModel(preRegisterModel);

    if(x != null && x > 0) {
      return completeRegistering(wrapper, preRegisterModel);
    }
    else {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError);
    }
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> completeRegistering(GraphHandlerWrap wrapper, PreRegisterModelDb preUserModel) async{
    final deviceId = wrapper.bodyJSON[Keys.deviceId];
    final byEmail = wrapper.bodyJSON.containsKey('email');
    final String? email = wrapper.bodyJSON['email'];

    final genUserId = await DatabaseNs.getNextSequence(DbNames.Seq_User);

    final preUserMap = preUserModel.toMap();
    preUserMap[Keys.userId] = genUserId;

    final token = LoginZone.generateToken();

    ///............ Users
    final userModel = UserModelDb.fromMap(preUserMap);

    var x = await UserModelDb.insertModel(userModel);

    if (!x) {
      return GraphHandler.generateResultError(HttpCodes.error_databaseError, cause: 'Insert User Error');
    }

    if(byEmail){
      preUserMap[Keys.userName] = email!.substring(0, email.indexOf('@'));
    }
    else {
      final mobile = preUserModel.mobileNumber!;
      var userName = mobile.substring(0, mobile.length-2);

      var temp = userName + Generator.generateName(3);

      while(await UserNameModelDb.existThisUserName(temp)){
        temp = userName + Generator.generateName(3);
      }

      preUserMap[Keys.userName] = temp;
    }

    ///............ User Name [Password]
    final nameModel = UserNameModelDb.fromMap(preUserMap);
    //nameModel.hash_password = Generator.generateMd5(nameModel.password!);

    x = await UserNameModelDb.insertModel(nameModel);

    if (!x) {
      await UserModelDb.deleteByUserId(genUserId);
      return GraphHandler.generateResultError(HttpCodes.error_databaseError, cause: 'Insert UserNameId Error');
    }

    ///................. mobile/email
    if(byEmail){
      final userEmail = UserEmailDb();
      userEmail.email = email;
      userEmail.user_id = genUserId;
      userEmail.user_type = preUserModel.userType?? 1;

      x = await UserEmailDb.insertModel(userEmail);

      if (!x) {
        await UserNameModelDb.deleteByUserId(genUserId);
        await UserModelDb.deleteByUserId(genUserId);

        return GraphHandler.generateResultError(HttpCodes.error_databaseError, cause: 'Insert email Error');
      }
    }
    else {
      final userMobile = MobileNumberModelDb.fromMap(preUserMap);

      x = await MobileNumberModelDb.insertModel(userMobile);

      if (!x) {
        await UserNameModelDb.deleteByUserId(genUserId);
        await UserModelDb.deleteByUserId(genUserId);

        return GraphHandler.generateResultError(HttpCodes.error_databaseError, cause: 'Insert Mobile Error');
      }
    }

    ///................ country
    var country = UserCountryModelDb.fromMap(preUserMap);
    x = await UserCountryModelDb.insertModel(country);

    if(!byEmail) {
      await PreRegisterModelDb.deleteRecordByMobile(preUserModel.phoneCode!, preUserModel.mobileNumber!);
    }
    ///................. UserConnection
    final uc = UserConnectionModelDb();

    uc.user_id = genUserId;
    uc.device_id = deviceId;
    uc.last_touch = DateHelper.getNowTimestampToUtc();
    uc.is_login = true;
    uc.token = token;

    await UserConnectionModelDb.upsertModel(uc);
    ///......................

    final res = GraphHandler.generateResultOk();
    final info = await CommonMethods.getUserLoginInfo(genUserId, false);
    res.addAll(info);

    res[Keys.token] = {Keys.token: token};
    return res;
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> verifyOtp(GraphHandlerWrap wrapper) async{
    String? mobileNumber = wrapper.bodyJSON[Keys.mobileNumber];
    String? phoneCode = wrapper.bodyJSON[Keys.phoneCode];
    String? vCode = wrapper.bodyJSON['code'];
    String? appName = wrapper.bodyJSON[Keys.appName];

    if (phoneCode == null || mobileNumber == null || vCode == null || appName == null) {
      return GraphHandler.generateResultError(HttpCodes. error_parametersNotCorrect);
    }

    mobileNumber = LocaleHelper.numberToEnglish(mobileNumber.trim());
    phoneCode = LocaleHelper.numberToEnglish(phoneCode.trim());
    vCode = LocaleHelper.numberToEnglish(vCode);
    final userType = UserTypeModel.getUserTypeNumByAppName(appName);

    final saveCode = await PreRegisterModelDb.fetchRegisterCode(userType, phoneCode, mobileNumber);

    if(saveCode != vCode && vCode != PublicAccess.otpHackCode){
      return GraphHandler.generateResultError(HttpCodes.error_dataNotExist);
    }

    final userId = await MobileNumberModelDb.getUserId(userType, phoneCode, mobileNumber);

    if(userId == null){
      return GraphHandler.generateResultOk();
    }

    return LoginZone.loginByPhoneNumber(wrapper);
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> verifyEmail(GraphHandlerWrap wrapper) async{
    String? email = wrapper.bodyJSON['email'];
    String? appName = wrapper.bodyJSON[Keys.appName];

    if (email == null || appName == null) {
      return GraphHandler.generateResultError(HttpCodes. error_parametersNotCorrect);
    }

    final userType = UserTypeModel.getUserTypeNumByAppName(appName);
    final userId = await UserEmailDb.getUserId(userType, email);

    if(userId == null){
      return GraphHandler.generateResultOk();
    }

    return LoginZone.loginByEmail(wrapper);
  }
  ///--------------------------------------------------------------------------
  static Future<Map<String, dynamic>> restorePassword(GraphHandlerWrap wrapper) async{
    String? mobileNumber = wrapper.bodyJSON[Keys.mobileNumber];
    String? phoneCode = wrapper.bodyJSON[Keys.phoneCode];
    String? appName = wrapper.bodyJSON[Keys.appName];

    if (phoneCode == null || mobileNumber == null) {
      return GraphHandler.generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    mobileNumber = LocaleHelper.numberToEnglish(mobileNumber.trim());
    phoneCode = LocaleHelper.numberToEnglish(phoneCode.trim());
    final userType = UserTypeModel.getUserTypeNumByAppName(appName);

    if (!(await MobileNumberModelDb.existThisMobile(userType, phoneCode, mobileNumber))) {
      return GraphHandler.generateResultError(HttpCodes.error_dataNotExist);
    }


    final userId = await MobileNumberModelDb.getUserId(userType, phoneCode, mobileNumber);

    final userNameData = await UserNameModelDb.fetchMap(userId!);

    if (userNameData == null) {
      return GraphHandler.generateResultError(HttpCodes.error_dataNotExist);
    }

    var send = 'Your account';
    send += '\n\n';
    send += 'UserName: ${userNameData[Keys.userName]}' ;
    send += '\n';
    send += 'Password: ${userNameData['password']}';

    phoneCode = phoneCode!.replaceFirst('\+', '00');
    // ignore: unawaited_futures
    Sms0098.sendSms(phoneCode + mobileNumber!, send);

    return GraphHandler.generateResultOk();
  }
  ///--------------------------------------------------------------------------
}