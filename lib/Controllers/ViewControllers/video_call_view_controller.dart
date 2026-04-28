import 'package:friendfy/Models/agent_model.dart';
import 'package:riverpod/legacy.dart';
import 'package:riverpod/riverpod.dart';

class VideoCallViewController extends StateNotifier {
  Ref ref;
  VideoCallViewController(this.ref) : super(0);


  
}


class VideoCallViewModel{
  final AgentModel agent;
  final String sessionId;

  VideoCallViewModel(this.agent, this.sessionId);
  

}