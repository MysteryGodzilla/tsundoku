/// The library's sort order, remembered between visits. Filters aren't remembered: the library
/// opens showing everything.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../books/library_view.dart';

class ViewSettings extends ChangeNotifier {
  ViewSettings._(this._prefs, this._order);
  static const _orderKey = 'library.sort';

  static Future<ViewSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ViewSettings._(prefs, SortOrder.parse(prefs.getString(_orderKey)));
  }

  final SharedPreferences _prefs;
  SortOrder _order;
  SortOrder get sortOrder => _order;

  Future<void> setSortOrder(SortOrder o) async {
    _order = o;
    notifyListeners();
    await _prefs.setString(_orderKey, o.name);
  }
}
