
class AdminCommands {
  AdminCommands._();

  static final _admList = <String>[
    'set_about_us_data',
  ];

  static bool isAdminCommand(String request){
    return _admList.contains(request);
  }
}