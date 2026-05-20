import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:friendfy/Models/agent_model.dart';
import 'package:friendfy/Providers/agent_character_translation_provider.dart';
import 'package:friendfy/Services/agent_character_translation_service.dart';
import 'package:friendfy/locale_provider.dart';
import 'package:friendfy/utils/agent_display_localization.dart';

/// Karakter açıklaması — dil değişince otomatik güncellenir (Flutter çeviri + önbellek).
class AgentCharacterDescriptionText extends ConsumerStatefulWidget {
  final AgentModel agent;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  const AgentCharacterDescriptionText({
    super.key,
    required this.agent,
    required this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  ConsumerState<AgentCharacterDescriptionText> createState() =>
      _AgentCharacterDescriptionTextState();
}

class _AgentCharacterDescriptionTextState
    extends ConsumerState<AgentCharacterDescriptionText> {
  String? _lastLang;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleResolve());
  }

  @override
  void didUpdateWidget(covariant AgentCharacterDescriptionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agent.id != widget.agent.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleResolve());
    }
  }

  String _langCode() {
    return ref.watch(appProvider).currentLang?.languageCode ??
        Localizations.localeOf(context).languageCode;
  }

  void _scheduleResolve() {
    final lang = _langCode();
    if (_lastLang == lang &&
        AgentCharacterTranslationService.instance
                .cachedForAgent(widget.agent.id, lang) !=
            null) {
      return;
    }
    _lastLang = lang;
    AgentCharacterTranslationService.instance
        .resolveForAgent(widget.agent, lang)
        .then((_) {
      if (!mounted) return;
      ref.read(agentCharacterTranslationVersionProvider.notifier).state++;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(agentCharacterTranslationVersionProvider);
    final lang = _langCode();
    if (_lastLang != lang) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleResolve());
    }

    final cached = AgentCharacterTranslationService.instance
        .cachedForAgent(widget.agent.id, lang);
    final text = (cached != null && cached.isNotEmpty)
        ? cached
        : AgentDisplayLocalization.cardPreview(widget.agent, lang);

    if (text.isEmpty) return const SizedBox.shrink();

    return Text(
      text,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
