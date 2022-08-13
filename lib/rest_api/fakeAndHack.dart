import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/publicAccess.dart';
import 'package:vosate_zehn_server/rest_api/graphHandler.dart';

class FakeAndHack {
  FakeAndHack._();


  static void simulate_addTicket(int starterId, {int count = 4}){
    for(var i=1; i <= count; i++) {
      var q = '''
      INSERT INTO ticket (title, starter_user_id) VALUES ('TEST $i', $starterId);
    ''';

      PublicAccess.psql2.queryCall(q);
    }
  }

  static void simulate_addTicketWithMessage(int starterId, int senderId, {int count = 4}) async {
    for(var i=1; i <= count; i++) {
      var q = '''
      INSERT INTO ticket (title, starter_user_id) VALUES ('TEST $i', $starterId) RETURNING id;
    ''';

      var res = await PublicAccess.psql2.queryCall(q);
      var ticketId = res?[0].toList()[0]?? 1;

      for(var j=1; j <= 4; j++) {
        q = '''
      INSERT INTO ticketmessage
       (ticket_id, message_type, message_text, sender_user_id, user_send_ts, server_receive_ts)
        values ($ticketId, 1, 'hello ticket $j', $senderId, (now() at time zone 'utc'),
            (now() at time zone 'utc') + (floor(random() * 10) || ' day')::interval);
    ''';

        await PublicAccess.psql2.queryCall(q);
      }
    }
  }

  static void simulate_addTicketMessage(int senderId, {required List<int> ticketIds, int count = 4}) async {
    for(var ticketId in ticketIds){
      for(var i=1; i <= count; i++) {
        var q = '''
        INSERT INTO ticketmessage
         (ticket_id, message_type, message_text, sender_user_id, user_send_ts, server_receive_ts)
          values ($ticketId, 1, 'hello ticket $i', $senderId, (now() at time zone 'utc'),
              (now() at time zone 'utc') + (floor(random() * 10) || ' day')::interval);
      ''';

        await PublicAccess.psql2.queryCall(q);
      }
    }
  }

  static Map<String, dynamic> simulate_getLevel1(GraphHandlerWrap wrapper){
    final res = [];
    final upper = wrapper.bodyJSON[Keys.upper];

    var max = 20;

    if(upper != null){
      max = 12;
    }

    for(var i=0; i<max; i++){
      final itm = {};

      itm['title'] = 'انیمیشن ' + Generator.generateKey(5);
      //v1.description = 'کلیپ های کوتاه و کاربردی یرای درک';
      itm['description'] = 'درک رسیدن به آرامش با تماشای کلیپ های علمی و کاربردی یرای درک';

      itm['media'] = {'url': 'https://overlay.imageonline.co/overlay-image.jpg'};
      itm['date'] = DateHelper.getNowTimestamp();
      //v1.imageModel = MediaModel.fromMap({})..url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Image_created_with_a_mobile_phone.png/800px-Image_created_with_a_mobile_phone.png';
      //v2.imageModel = MediaModel.fromMap({})..url = 'https://overlay.imageonline.co/overlay-image.jpg';

      res.add(itm);
    }

    return {Keys.dataList : res};
  }

  static Map<String, dynamic> simulate_getLevel2(GraphHandlerWrap wrapper){
    final res = [];
    final upper = wrapper.bodyJSON[Keys.upper];

    var max = 20;

    if(upper != null){
      max = 12;
    }

    for(var i=0; i<max/2; i++){
      final itm = {};

      itm['title'] = 'فیلم مدیتیشن ' + Generator.generateKey(2);
      //v1.description = 'کلیپ های کوتاه و کاربردی یرای درک';
      itm['description'] = 'درک رسیدن به آرامش با تماشای کلیپ های علمی و  درک رسیدن به آرامش با تماشای کلیپ  شای کلیپ های علمی و کاربردی یکاربردی های علمی و کاربردی یکاربردی یرای درک';

      itm['media'] = {'url': 'https://overlay.imageonline.co/overlay-image.jpg'};
      itm['date'] = DateHelper.getNowTimestamp();
      itm['type'] = 1;
      itm['url'] = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

      res.add(itm);
    }

    for(var i=0; i<max/2; i++){
      final itm = {};

      itm['title'] = 'صوت ' + Generator.generateKey(2);
      itm['description'] = 'درک رسیدن به آرامش با تماشای کلیپ های علمی و  درک رسیدن به آرامش با تماشای کلیپ  شای کلیپ های علمی و کاربردی یکاربردی های علمی و کاربردی یکاربردی یرای درک';

      itm['media'] = {'url': 'https://overlay.imageonline.co/overlay-image.jpg'};
      itm['date'] = DateHelper.getNowTimestamp();
      itm['type'] = 2;
      itm['url'] = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

      res.add(itm);
    }

    final itm = {};

    itm['title'] = 'لیست ';
    itm['description'] = 'درک رسیدن به آرامش با تماشای کلیپ های علمی و  درک رسیدن به آرامش با تماشای کلیپ  شای کلیپ های علمی و کار';

    itm['media'] = {'url': 'https://overlay.imageonline.co/overlay-image.jpg'};
    itm['date'] = DateHelper.getNowTimestamp();
    itm['type'] = 10;
    itm['content_type'] = 2;

    res.add(itm);

    return {Keys.dataList : res};
  }
}