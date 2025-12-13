import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:friendfy/Local/local_db_keys.dart';
import 'package:friendfy/Models/user_model.dart';
import 'package:friendfy/Http/http_service.dart';

class UserRepository {
	final SharedPreferences prefs;
	final HttpService httpService;

	UserRepository({required this.prefs, required this.httpService});

}