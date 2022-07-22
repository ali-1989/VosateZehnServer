import 'dart:async';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/api/helpers/LocaleHelper.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:vosate_zehn_server/app/sms_0098.dart';
import 'package:vosate_zehn_server/database/databaseNs.dart';
import 'package:vosate_zehn_server/database/dbNames.dart';
import 'package:vosate_zehn_server/database/models/emailModel.dart';
import 'package:vosate_zehn_server/database/models/mobileNumber.dart';
import 'package:vosate_zehn_server/database/models/register.dart';
import 'package:vosate_zehn_server/database/models/users.dart';
import 'package:vosate_zehn_server/database/models/userBlockList.dart';
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

  static Future<Map?> checkCanRegister(GraphHandlerWrap wrapper, PreRegisterModelDb model) async{

    if (model.name == null || model.family == null
        || model.phoneCode == null
        || model.mobileNumber == null
    //|| model.userName == null
    //|| model.password == null
    ) {
      return GraphHandler.generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    /*if (await UserNameModelDb.existThisUserName(model.userName)) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'ExistUserName');
    }*/

    if (await MobileNumberModelDb.existThisMobile(model.userType!, model.phoneCode, model.mobileNumber)) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'ExistMobile');
    }

    /*if (await PublicAccess.psql2.exist(DbNames.T_BadWords, "word = '${model.userName}'")) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'NotAcceptUserName');
    }

    if (await PublicAccess.psql2.exist(DbNames.T_ReservedWords, "word = '${model.userName}'")) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'NotAcceptUserName');
    }*/

    /*if (await RegisterModelDb.existRegisteringFor(model.userName, model.phoneCode, model.mobileNumber)) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'ExistUserName');
    }*/

    return null;
  }
  ///--------------------------------------------------------------------------
  static dynamic preRegisterWithFullDataAndSendOtp(GraphHandlerWrap wrapper) async {
    PublicAccess.logger.logToAll('>>> register New User: ${wrapper.bodyJSON}');

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

      final text = PublicAccess.getVerifySmsText() + preRegisterModel.verify_code;

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
  static dynamic verifyOtpAndCompletePreRegistering(GraphHandlerWrap wrapper) async {
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

    if (PublicAccess.verifyHackCode != code && !exist) {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError, cause: 'NotCorrect');
    }

    var rMap = await PreRegisterModelDb.fetchModelMap(type, phoneCode, mobileNumber);
    var user = PreRegisterModelDb.fromMap(rMap as Map<String, dynamic>);

    return completeRegistering(wrapper, user);
  }
  ///--------------------------------------------------------------------------
  static dynamic resendSavedOtp(GraphHandlerWrap wrapper) async {
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
      code = PublicAccess.getVerifySmsText() + code!;
      // ignore: unawaited_futures
      Sms0098.sendSms(phoneCode + mobileNumber, code);

      return GraphHandler.generateResultOk();
    }
    else {
      return GraphHandler.generateResultError(HttpCodes.error_dataNotExist);
    }
  }
  ///--------------------------------------------------------------------------
  static dynamic registerUserWithFullData(GraphHandlerWrap wrapper) async {
    PublicAccess.logger.logToAll('>>> register new User: ${wrapper.bodyJSON}');

    final appName = wrapper.bodyJSON[Keys.appName];
    //final isExerciseTrainer = json['is_exercise_trainer'];

    final dbmRegister = PreRegisterModelDb.fromMap(wrapper.bodyJSON);
    dbmRegister.userType = UserTypeModel.getUserTypeNumByAppName(appName);

    final canRegister = await checkCanRegister(wrapper, dbmRegister);

    if(canRegister != null) {
      return canRegister;
    }

    //dbmRegister.id = await DatabaseNs.getNextSequenceNumeric(DbNames.Seq_NewUser);

    final x = await PreRegisterModelDb.upsertModel(dbmRegister);

    if(x != null && x > 0) {
      final res = GraphHandler.generateResultOk();
      res[Keys.mobileNumber] = dbmRegister.mobileNumber;
      res[Keys.phoneCode] = dbmRegister.phoneCode;

      return res;
    }
    else {
      return GraphHandler.generateResultError(HttpCodes.error_spacialError);
    }
  }
  ///--------------------------------------------------------------------------
  static dynamic completeRegistering(GraphHandlerWrap wrapper, PreRegisterModelDb userModel) async{
    final deviceId = wrapper.bodyJSON[Keys.deviceId];
    final genUserId = await DatabaseNs.getNextSequence(DbNames.Seq_User);

    final temp = userModel.toMap();
    temp[Keys.userId] = genUserId;

    ///............ Users
    final user = UserModelDb.fromMap(temp);

    var x = await UserModelDb.insertModel(user);

    if (!x) {
      return GraphHandler.generateResultError(HttpCodes.error_databaseError, cause: 'Insert User Error');
    }

    ///............ User Name [Password]
    final nameModel = UserNameModelDb.fromMap(temp);
    //nameModel.hash_password = Generator.generateMd5(nameModel.password!);

    x = await UserNameModelDb.insertModel(nameModel);

    if (!x) {
      await UserModelDb.deleteByUserId(genUserId);
      return GraphHandler.generateResultError(HttpCodes.error_databaseError, cause: 'Insert UserNameId Error');
    }

    ///............ mobile
    final userMobile = MobileNumberModelDb.fromMap(temp);

    x = await MobileNumberModelDb.insertModel(userMobile);

    if (!x) {
      await UserNameModelDb.deleteByUserId(genUserId);
      await UserModelDb.deleteByUserId(genUserId);

      return GraphHandler.generateResultError(HttpCodes.error_databaseError, cause: 'Insert Mobile Error');
    }

    ///............ country
    var country = UserCountryModelDb.fromMap(temp);
    x = await UserCountryModelDb.insertModel(country);

    await PreRegisterModelDb.deleteRecord(userModel.mobileNumber!, userModel.userName!);

    final token = Generator.generateKey(40);
    final uc = UserConnectionModelDb();

    uc.user_id = genUserId;
    uc.device_id = deviceId;
    uc.last_touch = DateHelper.getNowTimestampToUtc();
    uc.is_login = true;
    uc.token = token;

    await UserConnectionModelDb.upsertModel(uc);

    final res = GraphHandler.generateResultOk();

    final info = await CommonMethods.getUserLoginInfo(genUserId, false);
    res.addAll(info);

    /// manager users must apply by manager first
    if(userModel.userType != UserTypeModel.getUserTypeNumByType(UserTypeModel.managerUser)){
      res[Keys.token] = token;
    }
    else {
      await UserBlockListModelDb.blockUser(genUserId, cause: 'wait for apply');
      //todo : send alert to manager user
    }

    return res;
  }
  ///--------------------------------------------------------------------------
  static dynamic verifyOtp(GraphHandlerWrap wrapper) async{
    PublicAccess.logger.logToAll('>>> verifyByOtp: ${wrapper.bodyJSON}');
    
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

    if(saveCode != vCode){
      return GraphHandler.generateResultError(HttpCodes.error_dataNotExist);
    }

    final userId = await MobileNumberModelDb.getUserId(userType, phoneCode, mobileNumber);

    if(userId == null){
      return GraphHandler.generateResultOk();
    }

    return LoginZone.loginByPhoneNumber(wrapper);
  }
  ///--------------------------------------------------------------------------
  static dynamic verifyEmail(GraphHandlerWrap wrapper) async{
    PublicAccess.logger.logToAll('>>> verifyByEmail: ${wrapper.bodyJSON}');
    
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
  static dynamic restorePassword(GraphHandlerWrap wrapper) async{
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