class SearchFilterTool {
  int limit = 50;
  int? offset;
  String? searchText;
  String? orderBy;
  bool ascOrder = false;
  dynamic upper;
  dynamic lower;
  final Map<String, dynamic> _kv = {};

  SearchFilterTool();

  void addFilter(String key, String value){
    _kv[key] = value;
  }

  void removeFilter(String key){
    _kv.removeWhere((k, value) => k == key);
  }

  Map<String, dynamic> get filters => _kv;

  SearchFilterTool.fromMap(Map? map){
    if(map == null){
      return;
    }

    limit = map['limit'];
    offset = map['offset'];
    searchText = map['search_text'];
    upper = map['upper'];
    lower = map['lower'];

    if(map['filters'] is Map) {
      _kv.addAll(map['filters']);
    }
  }

  Map<String, dynamic> toMap(){
    final res = <String, dynamic>{};
    res['limit'] = limit;
    res['offset'] = offset;
    res['upper'] = upper;
    res['lower'] = lower;
    res['search_text'] = searchText;
    res['filters'] = _kv;

    return res;
  }
}