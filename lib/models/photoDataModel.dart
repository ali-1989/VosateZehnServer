
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:vosate_zehn_server/keys.dart';

class PhotoDataModel {
  late String id;
  DateTime? utcDate;
  String? url;
  String? path;
  int order = 0;
  String? description;

  PhotoDataModel() : id = Generator.generateName(14);

  PhotoDataModel.fromMap(Map? map, {String? domain}){
    if(map == null){
      return;
    }
    else{
      id = Generator.generateName(14);
    }

    id = map[Keys.id];
    utcDate = DateHelper.tsToSystemDate(map[Keys.date]); //is utc
    url = map[Keys.url];
    path = map[Keys.mediaPath];
    order = map[Keys.orderNum]?? 0;
    description = map[Keys.description];
  }

  Map toMap(){
    final map = {};

    map[Keys.id] = id;
    map[Keys.date] = DateHelper.toTimestampNullable(utcDate);
    map[Keys.url] = url;
    map[Keys.mediaPath] = path;
    map[Keys.orderNum] = order;
    map[Keys.description] = description;

    return map;
  }

  @override
  String toString() {
    return '$url , $path , date:$utcDate';
  }

  static void sort(List<PhotoDataModel> list, {bool asc = true}){
    list.sort((PhotoDataModel p1, PhotoDataModel p2){
      final d1 = p1.utcDate;
      final d2 = p2.utcDate;

      if(d1 == null){
        return asc? 1: 1;
      }

      if(d2 == null){
        return asc? 1: 1;
      }

      return asc? d1.compareTo(d2) : d2.compareTo(d1);
    });
  }
}