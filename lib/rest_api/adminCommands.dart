
class AdminCommands {
  AdminCommands._();

  static final _admList = <String>[
    'set_about_us_data',
    'set_aid_data',
    'set_aid_dialog_data',
    'set_term_data',
    'upsert_bucket',
    'delete_bucket',
    'upsert_sub_bucket',
    'delete_sub_bucket',
    'upsert_bucket_content',
    'upsert_speaker',
    'delete_speaker',
  ];

  static bool isAdminCommand(String request){
    return _admList.contains(request);
  }
}