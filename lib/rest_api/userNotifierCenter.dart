
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:vosate_zehn_server/database/models/userNotifier.dart';
import 'package:vosate_zehn_server/webSocket/wsMessenger.dart';

class UserNotifierCenter {
  UserNotifierCenter._();

  static Future acceptRequest(int receiverId, Map description) async {
    final notify = UserNotifierModel();
    notify.user_id = receiverId;
    notify.batch = NotifiersBatch.courseAnswer.name;
    notify.descriptionJs = description;
    notify.title = 'درخواست شما از طرف مربی پذیرفته شد';
    notify.titleTranslateKey = 'notify_acceptRequestByTrainer';
    notify.register_date = DateHelper.getNowTimestampToUtc();

    notify.id = await UserNotifierModel.insertModel(notify);

    return null;//WsMessenger.sendCourseRequestAnswerNotifier(receiverId, notify);
  }
}