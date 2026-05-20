import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Services/agent_character_translation_service.dart';

/// UI rebuild tetiklemek için çeviri önbelleği sürümü.
final agentCharacterTranslationVersionProvider =
    StateProvider<int>((ref) => 0);

/// Controller / StateNotifier içinden (Ref) toplu çeviri.
Future<void> prefetchAgentDescriptionsFromRef(
  Ref ref,
  Iterable<AgentModel> agents,
  String langCode,
) async {
  await AgentCharacterTranslationService.instance.prefetchAgents(
    agents,
    langCode,
  );
  ref.read(agentCharacterTranslationVersionProvider.notifier).state++;
}
