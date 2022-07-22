import 'package:vosate_zehn_server/publicAccess.dart';

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
}