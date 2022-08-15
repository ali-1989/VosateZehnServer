
class AdminCommands {
  AdminCommands._();

  static final _admList = <String>[
    'set_about_us_data',
    'set_aid_data',
    'set_aid_dialog_data',
    'set_term_data',
    'delete_bucket_image',
    'upsert_bucket',
  ];

  static bool isAdminCommand(String request){
    return _admList.contains(request);
  }
}