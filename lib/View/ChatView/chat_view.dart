import 'dart:async';
import 'dart:convert';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/ViewControllers/chat_screen_view_controller.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/message_model.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:waved_audio_player/waved_audio_player.dart';
import 'package:shimmer/shimmer.dart';

class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final ScrollController _scrollController = ScrollController();
  Timer? timer;
  // Her mesaj için ayrı text visibility state'i tutacak Map
  final Map<int, bool> _messageTextVisibility = {};
  int? _previousMessageCount = 0; // Önceki mesaj sayısını takip et
  int? _currentlyPlayingMessageId; // Şu anda oynatılan mesajın ID'si
  // Global audio player - tüm sesli mesajlar için tek bir player kullan
  final ap.AudioPlayer _globalAudioPlayer = ap.AudioPlayer();
  // TextField'ın focus node'unu saklamak için
  final FocusNode _textFieldFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    getMessages().then((_) => startStream());
  }

  @override
  void dispose() {
    timer?.cancel();
    _scrollController.dispose();
    // Sayfadan çıkınca tüm oynatılan sesleri durdur
    _globalAudioPlayer.stop();
    _globalAudioPlayer.dispose();
    _textFieldFocusNode.dispose();
    _currentlyPlayingMessageId = null;
    super.dispose();
  }

  void startStream() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) => listenMessages());
  }

  Future<void> getMessages() async {
    await ref.read(AllControllers.chatViewController.notifier).getMessages();
    scrollToBottom();
    // İlk yüklemede mesaj sayısını kaydet
    final messages = ref.read(AllControllers.chatViewController).messages;
    _previousMessageCount = messages?.length ?? 0;
  }

  Future<void> listenMessages() async {
    final previousCount = _previousMessageCount ?? 0;
    await ref.read(AllControllers.chatViewController.notifier).listenMessages();
    
    // Mesaj sayısını kontrol et
    final messages = ref.read(AllControllers.chatViewController).messages;
    final currentCount = messages?.length ?? 0;
    
    // Yeni mesaj geldi mi kontrol et
    if (currentCount > previousCount) {
      // Yeni mesaj geldiğinde her zaman scroll yap
      scrollToBottom();
    }
    
    _previousMessageCount = currentCount;
  }

  Future<void> sendMessage() async {
    await ref.read(AllControllers.chatViewController.notifier).sendMessage();
    // Kullanıcı mesaj attığında her zaman aşağı scroll yap
    scrollToBottom();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// URL regex pattern - http, https, www ile başlayan veya domain içeren linkleri yakalar
  static final RegExp _urlRegex = RegExp(
    r'(?:(?:https?|ftp):\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)',
    caseSensitive: false,
  );

  /// Mesaj metnindeki linkleri tespit edip tıklanabilir ve bold yapar
  Widget _buildTextWithLinks(String text, Color defaultColor) {
    final List<TextSpan> spans = [];
    final textStyle = GoogleFonts.poppins(
      color: defaultColor,
      fontSize: 14.sp,
    );
    final linkStyle = GoogleFonts.poppins(
      color: defaultColor,
      fontSize: 14.sp,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
    );

    int lastIndex = 0;
    for (final match in _urlRegex.allMatches(text)) {
      // Match'ten önceki normal metin
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: textStyle,
        ));
      }

      // Link metni
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            String urlToLaunch = url;
            // Eğer http/https yoksa ekle
            if (!urlToLaunch.startsWith('http://') && !urlToLaunch.startsWith('https://')) {
              urlToLaunch = 'https://$urlToLaunch';
            }
            
            try {
              final uri = Uri.parse(urlToLaunch);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              print('Error launching URL: $e');
            }
          },
      ));

      lastIndex = match.end;
    }

    // Kalan normal metin
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: textStyle,
      ));
    }

    // Eğer hiç link yoksa normal Text döndür
    if (spans.isEmpty || !_urlRegex.hasMatch(text)) {
      return Text(
        text,
        style: textStyle,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  void _showGalleryPopup(BuildContext context) {
    // Klavye kapalı olduğunda pop-up'ı göster
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        // MediaQuery'yi dialog context'inden al (klavye durumunu doğru almak için)
        final mediaQuery = MediaQuery.of(dialogContext);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        
        return Stack(
          children: [
            // Arka plan overlay (tıklanınca kapanır)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Pop-up menü - sol alt köşede, input alanının üstünde
            // Klavye kapalıysa sabit pozisyon, açıksa klavye yüksekliğini hesaba kat
            Positioned(
              bottom: keyboardHeight > 0 ? keyboardHeight + 80.h : 80.h,
              left: 16.w,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  width: 180.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kamera seçeneği
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await ref.read(AllControllers.chatViewController.notifier).pickImageFromCamera();
                          },
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12.r),
                            topRight: Radius.circular(12.r),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.black87,
                                  size: 22,
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  Translate.translate("camera", context),
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300),
                      // Galeri seçeneği
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await ref.read(AllControllers.chatViewController.notifier).pickImage();
                          },
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12.r),
                            bottomRight: Radius.circular(12.r),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  color: Colors.black87,
                                  size: 22,
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  Translate.translate("gallery", context),
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(AllControllers.chatViewController);
    final messages = controller.messages ?? [];

    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(onPressed: ()=>Navigator.pop(context), icon: Icon(CupertinoIcons.back,color: Colors.white,)),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                _showFullScreenImage(context, controller.agent?.photoURL ?? "");
              },
              child:  ClipRRect(
              borderRadius: BorderRadius.circular(40.r),
              child: CachedNetworkImage(
                imageUrl: controller.agent?.photoURL ?? "",
                width: 40.w,
                height: 40.h,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 40.w,
                    height: 40.h,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 40.w,
                  height: 40.h,
                  color: Colors.grey[300],
                  child: Icon(Icons.person, size: 25),
                ),
              ),
            ),
            ),
                               
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: (){
                    ref.read(AllControllers.agentsViewController.notifier).pushAgentView(controller.agent!);
                  },
                  child: Text(
                    controller.agent?.name ?? "",
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (controller.chatState == ChatState.botWriting)
                  Text(
                    Translate.translate("typing", context),
                    style: GoogleFonts.quicksand(
                      color: Colors.grey,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (controller.chatState == ChatState.botAudioRecording)
                  Text(
                    Translate.translate("recording_audio", context),
                    style: GoogleFonts.quicksand(
                      color: Colors.grey,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
                    IconButton(
            onPressed: () => _showOptionsMenu(context),
            icon: SvgPicture.asset("assets/icons/call.svg",color: Colors.white,),
          ),
          IconButton(
            onPressed: () => _showOptionsMenu(context),
            icon: SvgPicture.asset("assets/icons/vieo_call.svg"),
          ),
        ],
      ),
      
      // --- BODY ---
      body: SafeArea(
        child: Column(
          children: [
            // Mesaj Listesi
            Expanded(
              child: ListView.builder(
                      controller: _scrollController,
                      key: ValueKey('messages_list_${_currentlyPlayingMessageId ?? 'none'}'), // Key değiştiğinde tüm widget'lar yeniden oluşturulur
                      padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 10.w),
                      itemCount: _getItemCount(messages),
                      itemBuilder: (context, index) {
                        final item = _getItemAtIndex(messages, index);
                        if (item is String) {
                          // Tarih başlığı
                          return _buildDateHeader(item);
                        } else {
                          // Mesaj
                          final msg = item as MessageModel;
                          return Align(
                            alignment: msg.sender == "user"
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: _chatBubble(msg),
                          );
                        }
                      },
                    ),
            ),
      
            // Yazı alanı
            _messageInput(controller.responseWaiting!),
          ],
        ),
      ),
          ),
    );
  }

  Widget _chatBubble(MessageModel message) {
    if (message.messageType == "text") {
      return Column(
        children: [
          Align(
            alignment: message.sender == "user" ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              margin: EdgeInsets.only(
                top: 8.h,
                bottom: 8.h,
                right: message.sender == "user" ? 12.w : 50.w,
                left: message.sender == "bot" ? 12.w : 50.w,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                    color: message.sender == "user"
                    ? Color(0xffAB10E2)
                    : Colors.white.withValues(alpha: 0.3),
                ),
                color: message.sender == "user"
                    ? Color(0xffAB10E2).withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(30).r,
                  topRight: const Radius.circular(30).r,
                  bottomLeft: message.sender == "user"
                      ? const Radius.circular(30).r
                      : const Radius.circular(0),
                  bottomRight: message.sender == "user"
                      ? const Radius.circular(0)
                      : const Radius.circular(30).r,
                ),
              ),
              child: _buildTextWithLinks(
                message.message,
                Colors.white,
              ),
            ),
          ),
                  Align(
          alignment: message.sender == "user" ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(dateParser(message.createdAt),style: GoogleFonts.poppins(color: Colors.grey,fontSize: 10.sp,fontWeight: FontWeight.w500),),
        )
        ],
      );
    } else if (message.messageType == "voice") {
      return voiceBuble(message);
    } else if (message.messageType == "image") {
      return imageBubble(message);
    } else {
      return voiceBuble(message);
    }
  }



  Widget imageBubble(MessageModel message) {
    var json = jsonDecode(message.message);
    final imageUrl = json["imageURL"] ?? "";
    final userMessage = json["message"];
    final aiExplanation = json["aiExplanation"];
    
    return Container(
      margin: EdgeInsets.only(
        top: 8.h,
        bottom: 8.h,
        right: message.sender == "user" ? 12.w : 50.w,
        left: message.sender == "bot" ? 12.w : 50.w,
      ),
      child: Column(
        crossAxisAlignment: message.sender == "user" 
            ? CrossAxisAlignment.end 
            : CrossAxisAlignment.start,
        children: [
          // Resim
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 200.w,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: 200.w,
                  height: 200.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 200.w,
                height: 200.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 50.sp,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          
          // Kullanıcı mesajı varsa göster
          if (userMessage != null && userMessage.toString().isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: message.sender == "user"
                    ? MyColors.purple
                    : const Color(0xffF4F4F4),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                userMessage,
                style: GoogleFonts.poppins(
                  color: message.sender == "bot"
                      ? const Color(0xff555555)
                      : Colors.white,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
          
          // AI açıklaması varsa göster (bot mesajlarında)
          if (aiExplanation != null && 
              aiExplanation.toString().isNotEmpty && 
              message.sender == "bot") ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xffF4F4F4),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                aiExplanation,
                style: GoogleFonts.poppins(
                  color: const Color(0xff555555),
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget voiceBuble(MessageModel message){
    var json = jsonDecode(message.message);
    // Bu mesajın text visibility state'ini al (yoksa false)
    final isTextVisible = _messageTextVisibility[message.id] ?? false;
  
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          margin: EdgeInsets.only(
            top: 8.h,
            bottom: 8.h,
            right: message.sender == "user" ? 12.w : 50.w,
            left: message.sender == "bot" ? 12.w : 50.w,
          ),
          decoration: BoxDecoration(
            color: message.sender == "user"
                ? MyColors.purple
                : const Color(0xffF4F4F4),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(35).r,
              topRight: const Radius.circular(35).r,
              bottomLeft: message.sender == "user"
                  ? const Radius.circular(35).r
                  : const Radius.circular(0),
              bottomRight: message.sender == "user"
                  ? const Radius.circular(0)
                  : const Radius.circular(35).r,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GestureDetector ile tıklama event'ini yakalayarak klavye kapanmasını engelle
              // WhatsApp gibi davranış: klavye açıkken sesli mesaja tıklayınca klavye kapanmaz
              // TextField'ın focus node'unu geçirerek, tıklandığında focus'u koruyoruz
              _ControlledWavedAudioPlayer(
                key: ValueKey('audio_${message.id}'),
                messageId: message.id,
                audioUrl: json["url"],
                playedColor: message.sender == "user" ? Colors.white : MyColors.purple,
                iconColor: Colors.black,
                currentlyPlayingId: _currentlyPlayingMessageId,
                globalAudioPlayer: _globalAudioPlayer,
                textFieldFocusNode: _textFieldFocusNode,
                onPlayStarted: (messageId) {
                  if (!mounted) return;
                  if (mounted) {
                    setState(() {
                      _currentlyPlayingMessageId = messageId;
                    });
                  }
                },
                onPlayStopped: (messageId) {
                  if (!mounted) return;
                  if (_currentlyPlayingMessageId == messageId) {
                    if (mounted) {
                      setState(() {
                        _currentlyPlayingMessageId = null;
                      });
                    }
                  }
                },
              ),
              SizedBox(height:  5.h),
              Align(
                alignment: message.sender == "user" ? Alignment.centerRight : Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                         setState(() {
              // Sadece bu mesajın state'ini toggle et
              _messageTextVisibility[message.id] = !isTextVisible;
            });
                  },
                  child: Text(!isTextVisible ? Translate.translate("convert_to_text", context) : Translate.translate("hide_text", context),style: GoogleFonts.poppins(fontSize: 9.sp,fontWeight: FontWeight.w500,color:message.sender == "user" ? Colors.white: MyColors.purple),))),
              if (isTextVisible) ...[
                SizedBox(height: 8.h),
                Text(
                  json["text"],
                  style: GoogleFonts.poppins(
                    color: message.sender == "bot"
                        ? const Color(0xff555555)
                        : Colors.white,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
        Align(
          alignment: message.sender == "user" ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(dateParser(message.createdAt),style: GoogleFonts.poppins(color: Colors.grey,fontSize: 10.sp,fontWeight: FontWeight.w500),),
        )
      ],
    );
  }

  String dateParser(String date){
    DateTime dateTime = DateTime.parse(date);
    String hour = "";
    String minute = "";
    if (dateTime.hour < 10) {
      hour = "0${dateTime.hour}";
    }else{
      hour = dateTime.hour.toString();
    }
    var x = dateTime.minute / 10 ;

    if (x.runtimeType.toString() == "int") {
      minute  = "${dateTime.minute}0";
    }else if(dateTime.minute < 10){
     minute = "0${dateTime.minute}";
    }else{
      minute = dateTime.minute.toString();
    }
    return "$hour:$minute";
  }

  /// Mesajları tarihlerine göre gruplar ve tarih başlıkları ekler
  int _getItemCount(List<MessageModel> messages) {
    if (messages.isEmpty) return 0;
    
    int count = messages.length;
    DateTime? lastDate;
    
    for (var msg in messages) {
      final msgDate = DateTime.parse(msg.createdAt);
      final msgDateOnly = DateTime(msgDate.year, msgDate.month, msgDate.day);
      
      if (lastDate == null || !_isSameDay(msgDateOnly, lastDate)) {
        count++; // Tarih başlığı için ekstra item
        lastDate = msgDateOnly;
      }
    }
    
    return count;
  }

  /// Belirli bir index'teki item'ı döndürür (mesaj veya tarih başlığı)
  dynamic _getItemAtIndex(List<MessageModel> messages, int index) {
    int currentIndex = 0;
    DateTime? lastDate;
    
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final msgDate = DateTime.parse(msg.createdAt);
      final msgDateOnly = DateTime(msgDate.year, msgDate.month, msgDate.day);
      
      // Yeni bir gün mü?
      if (lastDate == null || !_isSameDay(msgDateOnly, lastDate)) {
        // Tarih başlığı ekle
        if (currentIndex == index) {
          return _formatDateHeader(msgDateOnly);
        }
        currentIndex++;
        lastDate = msgDateOnly;
      }
      
      // Mesaj ekle
      if (currentIndex == index) {
        return msg;
      }
      currentIndex++;
    }
    
    // Fallback (olması gerekmez ama güvenlik için)
    return messages.isNotEmpty ? messages.last : null;
  }

  /// İki tarihin aynı gün olup olmadığını kontrol eder
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Tarih başlığını formatlar (Bugün, Dün, veya tam tarih)
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (_isSameDay(dateOnly, today)) {
      return Translate.translate("today", context);
    } else if (_isSameDay(dateOnly, yesterday)) {
      return Translate.translate("yesterday", context);
    } else {
      // Tam tarih formatı
      final locale = Localizations.localeOf(context);
      if (locale.languageCode == 'tr') {
        final months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
                       'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
        return '${date.day} ${months[date.month - 1]} ${date.year}';
      } else {
        return DateFormat('d MMMM yyyy', 'en').format(date);
      }
    }
  }

  /// Tarih başlığı widget'ı
  Widget _buildDateHeader(String dateText) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            dateText,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyChatView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(60.r),
            child: Image.asset(
              "assets/hello.gif",
              width: 120.w,
              height: 120.h,
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
            decoration: BoxDecoration(
              color: const Color(0xffF7F7F7),
              borderRadius: BorderRadius.circular(25.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                )
              ],
            ),
            child: Text(
              "Say hi!",
              style: GoogleFonts.quicksand(
                color: Colors.black,
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageInput(bool isLoading) {
final controllerStream =  ref.watch(AllControllers.chatViewController.notifier).messageController;
final chatController =  ref.watch(AllControllers.chatViewController);
final chatControllerNotifier =  ref.read(AllControllers.chatViewController.notifier);
    
    // Kayıt yapılıyor
    if (chatController.recordState == RecordState.recording) {
      return Container(
        width: MediaQuery.sizeOf(context).width,
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        margin: EdgeInsets.symmetric(horizontal: 15.w),
        height: 45.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50.r),
          color: const Color(0xffF7F7F7)
        ),
        child: Row(
          children: [
            // Stop/İptal butonu (sol taraf)
            IconButton(
              onPressed: () => chatControllerNotifier.stoppingAudio(), 
              icon: HeroIcon(HeroIcons.stopCircle, style: HeroIconStyle.solid,),
            ),
            Expanded(
              child: AudioWaveforms(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                waveStyle: WaveStyle(
                  waveColor: MyColors.purple,
                  extendWaveform: true,
                  showMiddleLine: false
                ),
                size: Size(MediaQuery.sizeOf(context).width, 40.h), 
                recorderController: chatControllerNotifier.recorderController
              ),
            ),
          ],
        ),
      );
    }
    
    // Kayıt durdurulmuş - gönderme butonu göster
    if (chatController.recordState == RecordState.stopped) {
      return Container(
        width: MediaQuery.sizeOf(context).width,
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        margin: EdgeInsets.symmetric(horizontal: 15.w),
        height: 45.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50.r),
          color: Colors.black.withValues(alpha: 0.4)
        ),
        child: Row(
          children: [
            // İptal butonu (sol taraf) - WhatsApp'taki gibi kırmızı X
            GestureDetector(
              onTap: () => chatControllerNotifier.cancelStoppedRecording(),
              child: Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.red, size: 20),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Center(
                child: Text(
                  Translate.translate("recording_stopped", context),
                  style: GoogleFonts.quicksand(
                    color: Colors.black54,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
          
            GestureDetector(
              onTap: () => chatControllerNotifier.sendStoppedRecording(),
              child: Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      );
    }
    
    // Normal input (kayıt yok)
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 5.h, 16.w, 15.h),
      child:  Column(
        children: [
          if(ref.watch(AllControllers.chatViewController.notifier).selectedImage != null)...[
           Container(
     
            height: 60.h,
            padding: EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(39).r,
              boxShadow: [BoxShadow(blurRadius: 2,color: const Color.fromARGB(255, 221, 221, 221))]
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60.w,
                  height:60.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(39).r,
                    image: DecorationImage(image: AssetImage(ref.watch(AllControllers.chatViewController.notifier).selectedImage!.path),fit: BoxFit.cover)
                  ),
                  
                ),
                SizedBox(width: 10.w,),
                Text("Görsel",style: GoogleFonts.quicksand(color: Colors.black,fontWeight: FontWeight.w500),),
                SizedBox(width: 30.w,),
                GestureDetector(
                  onTap: () {
                    ref.read(AllControllers.chatViewController.notifier).removeImage();
                  },
                  child: Container(
                    width: 20.w,
                    height: 20.h,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(50).r
                    ),
                    child: Center(child: Icon(Icons.close,color: Colors.red,size: 15.w,),),
                  ),
                )

              ],
            ),
           ),

           SizedBox(height: 10.h,),
          ],




          MyTextField(
            controller: controllerStream,
            focusNode: _textFieldFocusNode,
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(40),
            ),
            hintText: Translate.translate(TranslateKeys.enterMessage, context),
            hintStyle: GoogleFonts.quicksand(color: Colors.white),
            prefixIcon: GestureDetector(
              onTap: () {
                // Klavyeyi kapat
                FocusScope.of(context).unfocus();
                // Klavye animasyonunun bitmesini bekle, sonra popup'ı göster
                Future.delayed(Duration(milliseconds: 300), () {
                  if (mounted) {
                    _showGalleryPopup(context);
                  }
                });
              },
              child: HeroIcon(
                HeroIcons.plus,
                style: HeroIconStyle.solid,
                color: Colors.white,
                size: 24,
              ),
            ),
            textStyle: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600,fontSize: 13.sp),
            suffixIcon: AnimatedSwitcher(
              duration: Duration(milliseconds:50),
          
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation ,child: child,),
              child: suffixIcon(isLoading),)
          ),
        ],
      ),
    );
  }


  /// Mikrofon butonu - tıklayınca kayıt başlar
  Widget _buildInstagramStyleMicrophoneButton(ChatScreenViewController notifier) {
    return GestureDetector(
      onTap: () async {
        // Tıklayınca kayıt başlat
        debugPrint("🎤 onTap - Kayıt başlatılıyor...");
        await notifier.startRecording();
      },
      child: SvgPicture.asset("assets/icons/mic.svg")
    );
  }

Widget suffixIcon(bool isLoading){
  final controllerStream =  ref.watch(AllControllers.chatViewController.notifier).messageController;
  final chatControllerNotifier =  ref.read(AllControllers.chatViewController.notifier);
  final hasImage = chatControllerNotifier.selectedImage != null;
  
  if (isLoading) {
    // Modern loading animasyonu - 3 nokta
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: _buildLoadingDots(),
    );
  } else {
    // Eğer resim seçilmişse VEYA mesaj yazılmışsa gönder butonu göster
    if (hasImage || controllerStream.text.trim().isNotEmpty) {
      return _buildSendButton();
    } else {
      // Ne resim ne de mesaj varsa mikrofon göster - Instagram tarzı
      return _buildInstagramStyleMicrophoneButton(chatControllerNotifier);
    }
  }
}







  Widget onlineWidget(){
    return Row(
      children: [
        Container(width: 4.w,height: 4.h,decoration: BoxDecoration(color: Color(0xff34C759),borderRadius: BorderRadius.circular(20).r),),
       SizedBox(width: 3.w,),
        Text("Online",style: GoogleFonts.quicksand(color: Colors.white,fontSize: 12.sp,fontWeight: FontWeight.w600),)
      ],
    );
  }



/// Modern loading animasyonu - 3 nokta
Widget _buildLoadingDots() {
  return SizedBox(
    width: 40.w,
    height: 40.h,
    child: _LoadingDotsWidget(),
  );
}

/// Modern gönder butonu
Widget _buildSendButton() {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: sendMessage,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 40.w,
        height: 40.h,
        padding: EdgeInsets.all(8.w),
        child: HeroIcon(
          HeroIcons.paperAirplane,
          style: HeroIconStyle.solid,
          color: Colors.white,
          size: 20,
        ),
      ),
    ),
  );
}

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.report_outlined, color: Colors.orange),
                title: Text(
                  Translate.translate(TranslateKeys.report, context),
                  style: GoogleFonts.quicksand(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  Translate.translate(TranslateKeys.deleteConversation, context),
                  style: GoogleFonts.quicksand(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    final TextEditingController descriptionController = TextEditingController();
    
    final List<String> reportReasons = [
      'inappropriate_content',
      'harassment',
      'spam',
      'violence',
      'hate_speech',
      'other',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Text(
                Translate.translate(TranslateKeys.reportDialogTitle, context),
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.w700,
                  fontSize: 18.sp,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translate.translate(TranslateKeys.reportReason, context),
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(
                            Translate.translate(TranslateKeys.selectReason, context),
                            style: GoogleFonts.quicksand(),
                          ),
                          value: selectedReason,
                          items: reportReasons.map((reason) {
                            return DropdownMenuItem(
                              value: reason,
                              child: Text(
                                Translate.translate(reason, context),
                                style: GoogleFonts.quicksand(),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedReason = value;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      Translate.translate(TranslateKeys.reportDescription, context),
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: Translate.translate(TranslateKeys.reportDescriptionHint, context),
                        hintStyle: GoogleFonts.quicksand(
                          color: Colors.grey,
                          fontSize: 13.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: MyColors.purple),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    Translate.translate(TranslateKeys.cancel, context),
                    style: GoogleFonts.quicksand(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () async {
                          final description = descriptionController.text.trim();
                          if (description.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  Translate.translate(TranslateKeys.reportDescriptionHint, context),
                                ),
                              ),
                            );
                            return;
                          }

                          // Send report
                          final success = await _sendReport(
                            selectedReason!,
                            description,
                          );

                          // Close dialog first
                          if (mounted) {
                            Navigator.pop(dialogContext);
                          }

                          // Show feedback after dialog is closed
                          if (mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Translate.translate(TranslateKeys.reportSentSuccess, context),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Translate.translate(TranslateKeys.reportSentError, context),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    Translate.translate(TranslateKeys.sendReport, context),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _sendReport(String reason, String description) async {
    return await ref.read(AllControllers.chatViewController.notifier).sendReport(reason, description);
  }


  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(CupertinoIcons.back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(
                    Icons.person,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            Translate.translate(TranslateKeys.deleteConversationTitle, context),
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
            ),
          ),
          content: Text(
            Translate.translate(TranslateKeys.deleteConversationMessage, context),
            style: GoogleFonts.quicksand(
              fontSize: 14.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                Translate.translate(TranslateKeys.cancel, context),
                style: GoogleFonts.quicksand(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await _deleteConversation();
               navigatorKey.currentState?.pop();

                if (success) {
               
                   navigatorKey.currentState?.pop();
                
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        Translate.translate(TranslateKeys.conversationDeletedError, context),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                Translate.translate(TranslateKeys.delete, context),
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _deleteConversation() async {
    return await ref.read(AllControllers.chatViewController.notifier).deleteConversation();
  }

  
}

/// Loading dots animasyonu için StatefulWidget
class _LoadingDotsWidget extends StatefulWidget {
  @override
  State<_LoadingDotsWidget> createState() => _LoadingDotsWidgetState();
}

class _LoadingDotsWidgetState extends State<_LoadingDotsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final animationValue = ((_controller.value + delay) % 1.0);
            final opacity = animationValue < 0.5 
                ? animationValue * 2 
                : 2 - (animationValue * 2);
            final scale = 0.7 + (animationValue < 0.5 ? animationValue * 0.6 : (1 - animationValue) * 0.6);
            
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              width: 8.w * scale,
              height: 8.w * scale,
              decoration: BoxDecoration(
                color: MyColors.purple.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

// WavedAudioPlayer widget'ını sarmalayan widget - aynı anda sadece bir sesli mesaj oynatmak için
class _ControlledWavedAudioPlayer extends StatefulWidget {
  final int messageId;
  final String audioUrl;
  final Color playedColor;
  final Color iconColor;
  final int? currentlyPlayingId;
  final ap.AudioPlayer globalAudioPlayer;
  final Function(int) onPlayStarted;
  final Function(int) onPlayStopped;
  final FocusNode? textFieldFocusNode; // TextField'ın focus node'unu saklamak için

  const _ControlledWavedAudioPlayer({
    super.key,
    required this.messageId,
    required this.audioUrl,
    required this.playedColor,
    required this.iconColor,
    required this.currentlyPlayingId,
    required this.globalAudioPlayer,
    required this.onPlayStarted,
    required this.onPlayStopped,
    this.textFieldFocusNode,
  });

  @override
  State<_ControlledWavedAudioPlayer> createState() => _ControlledWavedAudioPlayerState();
}

class _ControlledWavedAudioPlayerState extends State<_ControlledWavedAudioPlayer> {
  GlobalKey _wavedPlayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _wavedPlayerKey = GlobalKey();
  }

  @override
  void didUpdateWidget(_ControlledWavedAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Eğer başka bir mesaj oynatılmaya başlandıysa, widget'ı yeniden oluştur
    if (oldWidget.currentlyPlayingId == widget.messageId && 
        widget.currentlyPlayingId != widget.messageId) {
      _wavedPlayerKey = GlobalKey();
    }
    // Eğer bu mesaj oynatılmaya başlandıysa, widget'ı yeniden oluştur
    if (oldWidget.currentlyPlayingId != widget.messageId && 
        widget.currentlyPlayingId == widget.messageId) {
      _wavedPlayerKey = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Sesli mesaja tıklandığında TextField'ın focus'unu koru
        // Bu sayede klavye kapanmaz
        if (widget.textFieldFocusNode != null && widget.textFieldFocusNode!.hasFocus) {
          // Focus'u koru - klavyeyi kapatma
          // Hemen focus'u tekrar request et (kısa bir delay ile)
          Future.delayed(Duration(milliseconds: 50), () {
            if (widget.textFieldFocusNode!.canRequestFocus && !widget.textFieldFocusNode!.hasFocus) {
              widget.textFieldFocusNode!.requestFocus();
            }
          });
        }
      },
      child: WavedAudioPlayer(
        key: _wavedPlayerKey,
        showTiming: false,
        source: ap.UrlSource(widget.audioUrl, mimeType: 'audio/mpeg'),
        playedColor: widget.playedColor,
        iconColor: widget.iconColor,
        onError: (err) {
          print('Audio player error: $err');
        },
      ),
    );
  }
}
