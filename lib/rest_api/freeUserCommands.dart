
class FreeUserCommands {
  FreeUserCommands._();

  static final _cmdList = <String>[
    'get_app_parameters',
    'send_otp',
    'verify_otp',
    'verify_email',
    'register_user',
    'register_user_and_otp',
    'complete_registering',
    'restore_password',
    'resend_verify_code',
    'login_user_name',
    'login_admin',
  ];

  static bool isFreeCommand(String request){
    return _cmdList.contains(request);
  }
}