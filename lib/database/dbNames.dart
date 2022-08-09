
class DbNames {
  DbNames._();

  static const T_NumericSequence = 'numeric_sequence';
  static const T_CandidateToDelete = 'candidate_to_delete';
  static const T_TypeForSex = 'type_for_sex';
  static const T_Users = 'users';
  static const T_PreRegisteringUser = 'pre_registering_user';
  static const T_Continent = 'continent';
  static const T_Country = 'country';
  static const T_Language = 'language';
  static const T_BatchKey = 'batchKey';
  static const T_UserToBatch = 'userToBatch';
  static const T_Rights = 'rights';
  static const T_Roles = 'roles';
  static const T_UserToRoles = 'user_to_roles';
  static const T_BadWords = 'bad_words';
  static const T_ReservedWords = 'reserved_words';
  static const T_UserCountry = 'user_country';
  static const T_UserCurrency = 'user_currency';
  static const T_UserPlace = 'user_place';
  static const T_UserBlockList = 'user_block_list';
  static const T_DevicesCellar = 'devices_cellar';
  static const T_UserNameId = 'user_nameId';
  static const T_UserNotifier = 'user_notifier';
  static const T_TypeForUserMetaData = 'type_for_user_MetaData';
  static const T_UserMetaData = 'user_metaData';
  static const T_MobileNumber = 'mobile_number';
  static const T_UserEmail = 'user_email';
  static const T_TypeForUserImage = 'type_for_user_image';
  static const T_UserImages = 'user_images';
  static const T_DeviceConnections = 'device_connections';
  static const T_UserConnections = 'user_connections';
  static const T_SystemMessageVsCommon = 'systemMessageVsCommon';
  static const T_SystemMessageVsBatch = 'systemMessageVsBatch';
  static const T_SystemMessageVsUser = 'systemMessageVsUser';
  static const T_SystemMessageResult = 'systemMessageResult';
  static const T_Ticket = 'ticket';
  static const T_TicketMessageSeen = 'ticket_message_seen';
  static const T_TicketMessage = 'ticket_message';
  static const T_TicketEditedMessage = 'ticket_edited_message';
  static const T_TicketReplyMessage = 'ticket_reply_message';
  static const T_TypeForMessage = 'type_for_message';
  static const T_MediaMessageData = 'media_message_data';
  static const T_EditedMessage = 'edited_message';
  static const T_ReplyMessage = 'reply_message';
  static const T_ForwardMessage = 'forward_message';
  static const T_AppVersions = 'app_versions';
  static const T_Advertising = 'advertising';
  //---------------------------------
  static const T_HtmlHolder = 'html_holder';

  //... Sequence ...........................................................................
  static const Seq_User = 'user_seq';
  static const Seq_NewUser = 'new_user_seq';   // numeric
  static const Seq_SystemMessage = 'system_message_seq';
  static const Seq_ticket = 'ticket_seq';
  static const Seq_ticketMessageId = 'ticket_message_id_seq'; // numeric
  static const Seq_MediaId = 'media_id_seq';  // numeric
  static const Seq_MediaGroupId = 'media_group_id_seq';
}