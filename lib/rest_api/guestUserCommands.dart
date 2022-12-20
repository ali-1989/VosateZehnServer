
import 'package:vosate_zehn_server/keys.dart';
import 'package:vosate_zehn_server/rest_api/graphHandler.dart';

class GuestUserCommands {
  GuestUserCommands._();

  static final _cmdList = <String>[
    'get_app_parameters',
    'login_user_name',
    'Logoff_user_report',
    'get_profile_data',
    'get_about_us_data',
    'get_aid_data',
    'get_term_data',
    'send_ticket_data',
    'get_bucket_data',
    'get_sub_bucket_data',
    'get_bucket_content_data',
    'get_advertising_data',
    'get_home_page_data',
    'get_daily_text_data',
  ];

  static bool isGuestCommand(GraphHandlerWrap wrapper){
    final cmd = _cmdList.contains(wrapper.zoneRequest);

    if(!cmd){
      return false;
    }

    if(wrapper.zoneRequest == 'get_bucket_data') {
      final key = wrapper.bodyJSON[Keys.key];

      //4 => meditation
      if(key.toString() != '4'){
        return false;
      }
    }

    return true;
  }
}