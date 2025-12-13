import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/utils/app_constants.dart';
import 'package:http/http.dart' as http;
import 'package:friendfy/Models/user_model.dart';

class HttpService {
	final String baseUrl;
  final Ref? ref;

	HttpService({this.baseUrl = AppConstants.baseURL,this.ref});


  Map<String, String> get header => {
"x-auth-token": ref?.watch(AllControllers.userController)?.token ?? "",
'Content-Type': 'application/json'
  };



 Future<http.Response> post({required String path,dynamic body,Map<String, String>? headers}) async{
  log("sent body: $body, header: $header");
 http.Response response = await http.post(Uri.parse("$baseUrl$path"),body: body == null ? null : jsonEncode(body),headers: header);
 if (response.statusCode != 200) {
   //log("POST: Response ${response.body}");
 }
 return response;
 }


 Future<http.StreamedResponse?> postAudioFile({required String path,required File file,var conversation,Map<String, String>? headers}) async{

try {
    final url = Uri.parse("$baseUrl$path");
    final request = http.MultipartRequest('POST', url);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields["conversation"] = conversation;
    request.fields["sender"] = "user";
    http.StreamedResponse response = await request.send();
 if (response.statusCode != 200) {
  var body = await response.stream.bytesToString();
  var json = jsonDecode(body);
   log("POST: Response ${json["error"]}");
 }
  return response;
} catch (e) {
  log("Error on postAudio: $e");
  return null;
}

 }

 Future<http.Response> uploadToCDN({
    required String url,
    required List<int> fileBytes,
    required String contentType,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(url),
        body: fileBytes,
        headers: {
          'AccessKey': '68664abb-b19e-47e7-acd67dba78a5-e90a-4386',
          'Content-Type': contentType,
        },
      );
      
      log("CDN Upload Response: ${response.statusCode}");
      return response;
    } catch (e) {
      log("Error uploading to CDN: $e");
      rethrow;
    }
  }

 Future<http.StreamedResponse?> postImageFile({
    required String path,
    required File file,
    required String conversation,
    String? message,
    Map<String, String>? headers
  }) async {
    try {
      final url = Uri.parse("$baseUrl$path");
      final request = http.MultipartRequest('POST', url);
      
      // x-auth-token header'ı ekle
      request.headers['x-auth-token'] = ref?.watch(AllControllers.userController)?.token ?? "";
      
      // Resim dosyasını ekle
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      
      // Form fields
      request.fields["conversation"] = conversation;
      request.fields["sender"] = "user";
      if (message != null && message.isNotEmpty) {
        request.fields["message"] = message;
      }
      
      log("📤 Sending image: ${file.path}, conversation: $conversation");
      
      http.StreamedResponse response = await request.send();
      
      if (response.statusCode != 200) {
        var body = await response.stream.bytesToString();
        var json = jsonDecode(body);
        log("POST Image Error: ${json["error"]}");
      } else {
        log("✅ Image sent successfully");
      }
      
      return response;
    } catch (e) {
      log("❌ Error on postImage: $e");
      return null;
    }
  }


}