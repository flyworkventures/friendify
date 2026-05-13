import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mindcoach/Services/LocalServices/local_db_service.dart';
import 'package:mindcoach/core/routes/page_routes.dart';
import 'package:mindcoach/core/services/video_call_insights_service.dart';
import 'package:mindcoach/core/utils/local_db_keys.dart';
import 'package:mindcoach/models/consultant_model.dart';

class VideoCallTrialInsightsScreen extends StatefulWidget {
  final ConsultantModel specialist;
  final int durationSeconds;
  final List<Map<String, String>> transcriptTurns;

  const VideoCallTrialInsightsScreen({
    super.key,
    required this.specialist,
    required this.durationSeconds,
    required this.transcriptTurns,
  });

  @override
  State<VideoCallTrialInsightsScreen> createState() =>
      _VideoCallTrialInsightsScreenState();
}

class _VideoCallTrialInsightsScreenState
    extends State<VideoCallTrialInsightsScreen> {
  Future<VideoCallInsightsResult>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= VideoCallInsightsService().buildInsights(
      consultantId: widget.specialist.id,
      durationSeconds: widget.durationSeconds,
      transcriptTurns: widget.transcriptTurns,
      coachName: _coachName(),
      localeCode: Localizations.localeOf(context).languageCode,
    );
  }

  String _coachName() {
    final names = widget.specialist.names;
    final tr = names['tr']?.toString();
    final en = names['en']?.toString();
    if (tr != null && tr.isNotEmpty) return tr;
    if (en != null && en.isNotEmpty) return en;
    if (names.values.isNotEmpty) return names.values.first.toString();
    return 'Lyra';
  }

  String _detailPhotoUrl(String originalUrl) {
    if (originalUrl.isEmpty) return '';
    final dotIndex = originalUrl.lastIndexOf('.');
    if (dotIndex == -1) return originalUrl;
    return '${originalUrl.substring(0, dotIndex)}_detail${originalUrl.substring(dotIndex)}';
  }

  Future<void> _openTrialActivatedPage({
    required bool openPaywallAfterLogin,
  }) async {
    await LocalDbService().setBool(
      key: LocalDbKeys.pendingPaywallAfterLogin,
      value: openPaywallAfterLogin,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TrialActivatedScreen()),
    );
  }

  String get _langCode =>
      Localizations.localeOf(context).languageCode.toLowerCase();

  String _t({
    required String tr,
    required String en,
    required String de,
    required String es,
    required String fr,
    required String hi,
    required String it,
    required String ja,
    required String ko,
    required String pt,
    required String ru,
    required String zh,
  }) {
    if (_langCode.startsWith('tr')) return tr;
    if (_langCode.startsWith('de')) return de;
    if (_langCode.startsWith('es')) return es;
    if (_langCode.startsWith('fr')) return fr;
    if (_langCode.startsWith('hi')) return hi;
    if (_langCode.startsWith('it')) return it;
    if (_langCode.startsWith('ja')) return ja;
    if (_langCode.startsWith('ko')) return ko;
    if (_langCode.startsWith('pt')) return pt;
    if (_langCode.startsWith('ru')) return ru;
    if (_langCode.startsWith('zh')) return zh;
    return en;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<VideoCallInsightsResult>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF21BC87)),
                );
              }
              final data = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _TopCoachCard(
                      coachName: _coachName(),
                      photoUrl: _detailPhotoUrl(widget.specialist.photoURL),
                      greeting: data.greeting,
                    ),
                    const SizedBox(height: 2),
                    _StatsRow(
                      durationSeconds: widget.durationSeconds,
                      score: data.mindfulnessScore,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAEAEA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          itemCount: data.highlights.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = data.highlights[index];
                            final isBlurred = index >= 3;
                            return _HighlightCard(
                              item: item,
                              isBlurred: isBlurred,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF21BC87),
                            blurRadius: 10,
                            offset: Offset(0, 0),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21BC87),
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.all(10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          _openTrialActivatedPage(openPaywallAfterLogin: true);
                        },
                        child: Text(
                          _t(
                            tr: 'Daha fazlası için Premium satın al',
                            en: 'Buy Premium for more',
                            de: 'Premium kaufen fuer mehr Inhalte',
                            es: 'Compra Premium para ver mas',
                            fr: 'Passe a Premium pour en voir plus',
                            hi: 'और देखने के लिए Premium खरीदें',
                            it: 'Acquista Premium per saperne di piu',
                            ja: '続きを見るにはPremiumを購入',
                            ko: '더 보려면 Premium을 구매하세요',
                            pt: 'Compre Premium para ver mais',
                            ru: 'Купите Premium, чтобы увидеть больше',
                            zh: '购买 Premium 以查看更多内容',
                          ),
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _openTrialActivatedPage(openPaywallAfterLogin: false);
                      },
                      child: Text(
                        _t(
                          tr: 'Satın almadan devam et',
                          en: 'Continue without purchase',
                          de: 'Ohne Kauf fortfahren',
                          es: 'Continuar sin comprar',
                          fr: 'Continuer sans achat',
                          hi: 'खरीद के बिना जारी रखें',
                          it: 'Continua senza acquisto',
                          ja: '購入せずに続行',
                          ko: '구매 없이 계속하기',
                          pt: 'Continuar sem comprar',
                          ru: 'Продолжить без покупки',
                          zh: '不购买继续',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B3D40),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopCoachCard extends StatelessWidget {
  final String coachName;
  final String photoUrl;
  final String greeting;

  const _TopCoachCard({
    required this.coachName,
    required this.photoUrl,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),

      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF21BC87),
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 28)
                    : ClipOval(
                        child: Transform.translate(
                          offset: const Offset(0, 5),
                          child: SizedBox.expand(
                            child: CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorWidget: (_, _, _) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              Positioned(
                right: 3,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF32E76E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              greeting,
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 20 / 16,
                letterSpacing: -0.16,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int durationSeconds;
  final int score;

  const _StatsRow({required this.durationSeconds, required this.score});

  String _formatDuration() {
    final clampedDuration = durationSeconds.clamp(0, 60);
    final minutes = clampedDuration ~/ 60;
    final seconds = clampedDuration % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _t(
    BuildContext context, {
    required String tr,
    required String en,
    required String de,
    required String es,
    required String fr,
    required String hi,
    required String it,
    required String ja,
    required String ko,
    required String pt,
    required String ru,
    required String zh,
  }) {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    if (lang.startsWith('tr')) return tr;
    if (lang.startsWith('de')) return de;
    if (lang.startsWith('es')) return es;
    if (lang.startsWith('fr')) return fr;
    if (lang.startsWith('hi')) return hi;
    if (lang.startsWith('it')) return it;
    if (lang.startsWith('ja')) return ja;
    if (lang.startsWith('ko')) return ko;
    if (lang.startsWith('pt')) return pt;
    if (lang.startsWith('ru')) return ru;
    if (lang.startsWith('zh')) return zh;
    return en;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: _t(
                context,
                tr: 'Süre',
                en: 'Duration',
                de: 'Dauer',
                es: 'Duracion',
                fr: 'Duree',
                hi: 'अवधि',
                it: 'Durata',
                ja: '時間',
                ko: '시간',
                pt: 'Duracao',
                ru: 'Длительность',
                zh: '时长',
              ),
              child: Text(
                _formatDuration(),
                style: const TextStyle(
                  fontFamily: 'Geist',
                  color: Color(0xFF000000),
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  height: 24 / 20,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: _t(
                context,
                tr: 'Öz farkındalık skoru',
                en: 'Self awareness score',
                de: 'Selbstwahrnehmungs-Score',
                es: 'Puntuacion de autoconciencia',
                fr: 'Score de conscience de soi',
                hi: 'आत्म-जागरूकता स्कोर',
                it: 'Punteggio di consapevolezza',
                ja: '自己認識スコア',
                ko: '자기 인식 점수',
                pt: 'Pontuacao de autoconsciencia',
                ru: 'Оценка самоосознания',
                zh: '自我觉察评分',
              ),
              child: Text.rich(
                TextSpan(
                  text: '$score',
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    color: Color(0xFF21BC87),
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 24 / 20,
                    letterSpacing: -0.2,
                  ),
                  children: const [
                    TextSpan(
                      text: '/100',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: -0.14,
                        color: Color(0xFF8F939A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _StatCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    // İÇTEKİ BEYAZ KARTLAR BURASI
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF), // İç kart rengi
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Geist',
              color: const Color(0xFF000000).withOpacity(0.65),
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 22 / 14,
              letterSpacing: -0.14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final VideoCallInsightItem item;
  final bool isBlurred;

  const _HighlightCard({required this.item, required this.isBlurred});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFDCF4EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset(
              "assets/icons/ic_medal.svg",
              width: 32,
              height: 32,
              fit: BoxFit.scaleDown,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 22 / 14,
                    letterSpacing: -0.14,
                  ),
                ),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF96989C),
                    height: 22 / 14,
                    letterSpacing: -0.14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!isBlurred) return card;

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 3.8, sigmaY: 3.8),
            child: card,
          ),
        ),
      ],
    );
  }
}

class TrialActivatedScreen extends StatefulWidget {
  const TrialActivatedScreen({super.key});

  @override
  State<TrialActivatedScreen> createState() => _TrialActivatedScreenState();
}

class _TrialActivatedScreenState extends State<TrialActivatedScreen> {
  bool _switchOn = false;
  bool _didComplete = false;
  String get _langCode =>
      Localizations.localeOf(context).languageCode.toLowerCase();

  String _t({
    required String tr,
    required String en,
    required String de,
    required String es,
    required String fr,
    required String hi,
    required String it,
    required String ja,
    required String ko,
    required String pt,
    required String ru,
    required String zh,
  }) {
    if (_langCode.startsWith('tr')) return tr;
    if (_langCode.startsWith('de')) return de;
    if (_langCode.startsWith('es')) return es;
    if (_langCode.startsWith('fr')) return fr;
    if (_langCode.startsWith('hi')) return hi;
    if (_langCode.startsWith('it')) return it;
    if (_langCode.startsWith('ja')) return ja;
    if (_langCode.startsWith('ko')) return ko;
    if (_langCode.startsWith('pt')) return pt;
    if (_langCode.startsWith('ru')) return ru;
    if (_langCode.startsWith('zh')) return zh;
    return en;
  }

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _switchOn = true);
      _continueFlow();
    });
  }

  Future<void> _continueFlow() async {
    if (_didComplete) return;
    _didComplete = true;

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(PageRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TrialToggleVisual(isOn: _switchOn),
            const SizedBox(height: 16),
            Text(
              _t(
                tr: '3 günlük ücretsiz deneme',
                en: '3-day free trial',
                de: '3 Tage kostenlos testen',
                es: 'prueba gratis de 3 dias',
                fr: 'essai gratuit de 3 jours',
                hi: '3 दिन का मुफ्त ट्रायल',
                it: 'prova gratuita di 3 giorni',
                ja: '3日間無料トライアル',
                ko: '3일 무료 체험',
                pt: 'teste gratis de 3 dias',
                ru: '3-дневный бесплатный пробный период',
                zh: '3天免费试用',
              ),
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 42 / 2,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              _t(
                tr: 'aktif',
                en: 'activated',
                de: 'aktiviert',
                es: 'activado',
                fr: 'active',
                hi: 'सक्रिय',
                it: 'attivato',
                ja: '有効化',
                ko: '활성화됨',
                pt: 'ativado',
                ru: 'активировано',
                zh: '已激活',
              ),
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 58 / 2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF21BC87),
                letterSpacing: -0.29,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialToggleVisual extends StatelessWidget {
  final bool isOn;

  const _TrialToggleVisual({required this.isOn});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isOn ? 1.14 : 1.0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        width: 98,
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isOn ? const Color(0xFF21BC87) : const Color(0xFF7B7483),
            width: 2,
          ),
          color: isOn
              ? const Color(0xFF21BC87).withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isOn ? const Color(0xFF21BC87) : const Color(0xFF7B7483),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
