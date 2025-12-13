// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Controllers/all_controllers.dart';

import 'package:friendfy/Http/http_service.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/main.dart';
import 'package:friendfy/utils/app_constants.dart';

class AgentsViewController extends StateNotifier<AgentsViewModel>{
  Ref? ref;

   AgentsViewController(this.ref) : super(AgentsViewModel());
   bool loading = false;
   bool editMode = false; // Anasayfadaki "Karakter Düzenle" butonundan gelirse true

   getAgents() async{
 try {
      loading = true;
    HttpService httpService = HttpService(ref: ref);
    var res = await httpService.post(path: AppConstants.systemAgents);
    if (res.statusCode== 200) {
      List json = jsonDecode(res.body);
      List<AgentModel>? agents = json.map((element)=> AgentModel.fromMap(element)).toList();
      state = state.copyWith(agents: agents);
      loading = false;
    } else {
      log("Server ${res.statusCode} error");
      loading = false;
    }
 } catch (e) {
   debugPrint("AgentsViewController, getAgents $e");
 }
   }


   getRecentAgents() async{
 try {
      loading = true;
    HttpService httpService = HttpService(ref: ref);
    var res = await httpService.post(path: AppConstants.recentAgents);
    if (res.statusCode== 200) {
      var json = jsonDecode(res.body);
      log(json.toString());
      List agentList = json["data"];
      List<AgentModel>? agents = agentList.map((element)=> AgentModel.fromMap(element)).toList();
      state = state.copyWith(recentAgents: agents);
      loading = false;
    } else {
      log("Server ${res.statusCode} error");
      loading = false;
    }
 } catch (e) {
   debugPrint("AgentsViewController, getRecentAgents $e");
 }
   }




   getUserAgents() async{
 try {
      loading = true;
      
      final userId = ref?.read(AllControllers.userController)?.id;
      debugPrint("🔷 getUserAgents called with userId: $userId");
      
      if (userId == null) {
        debugPrint("⚠️ userId is null, skipping getUserAgents");
        loading = false;
        return;
      }
      
    HttpService httpService = HttpService(ref: ref);
    var res = await httpService.post(
      path: AppConstants.userAgents,
      body: {"userId": userId}
    );
    
    debugPrint("📡 getUserAgents response: ${res.statusCode}");
    
    if (res.statusCode== 200) {
      List json = jsonDecode(res.body);
      List<AgentModel>? userAgents = json.map((element)=> AgentModel.fromMap(element)).toList();
      state = state.copyWith(userAgents: userAgents);
      debugPrint("✅ User agents loaded: ${userAgents.length} agents");
      loading = false;
    } else {
      log("Server ${res.statusCode} error");
      loading = false;
    }
 } catch (e) {
   debugPrint("❌ AgentsViewController, getUserAgents error: $e");
   loading = false;
 }
   }

   pushAgentView(AgentModel agent) async{
     try {
      ref?.read(AllControllers.agentsProfileViewController.notifier).changeAgentModel(agent);
     navigatorKey.currentState?.pushNamed('/agentDetails');
} catch (e) {
  debugPrint("AgentsViewController, getAgent $e");
}
   }

   /// Anasayfadaki "Karakter Düzenle" butonundan gelindiğinde çağrılır
   void setEditMode(bool value) {
     editMode = value;
     debugPrint("🔧 Edit mode set to: $value");
   }

   /// Edit mode'un değerini döndürür
   bool getEditMode() {
     return editMode;
   }


 
  
}


class AgentsViewModel {
  final List<AgentModel>? agents;
  final List<AgentModel>? userAgents;
  final List<AgentModel>? recentAgents;

  AgentsViewModel({
     this.agents,
     this.userAgents,
     this.recentAgents
  });

  AgentsViewModel copyWith({
    List<AgentModel>? agents,
    List<AgentModel>? userAgents,
    List<AgentModel>? recentAgents,
  }) {
    return AgentsViewModel(
      agents: agents ?? this.agents,
      userAgents: userAgents ?? this.userAgents,
       recentAgents: recentAgents ?? this.recentAgents,
    );
  }

}
