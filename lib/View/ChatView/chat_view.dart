import 'dart:async';
import 'dart:convert';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/ViewControllers/chat_screen_view_controller.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';

import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/message_model.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/textfield.dart';
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
  
  @override
  void initState() {
    super.initState();
    getMessages().then((_) => startStream());
  }

  @override
  void dispose() {
    timer?.cancel();
    _scrollController.dispose();
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

  /// Kullanıcı scroll'un en altında mı kontrol et
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    
    final position = _scrollController.position;
    // En alt 100 pixel içindeyse "near bottom" kabul et
    return position.pixels >= position.maxScrollExtent - 100;
  }

  Future<void> listenMessages() async {
    final previousCount = _previousMessageCount ?? 0;
    await ref.read(AllControllers.chatViewController.notifier).listenMessages();
    
    // Mesaj sayısını kontrol et
    final messages = ref.read(AllControllers.chatViewController).messages;
    final currentCount = messages?.length ?? 0;
    
    // Yeni mesaj geldi mi kontrol et
    if (currentCount > previousCount) {
      // Kullanıcı en alttaysa veya yakınsa scroll yap
      if (_isNearBottom()) {
        scrollToBottom();
      }
    }
    
    _previousMessageCount = currentCount;
  }

  Future<void> sendMessage() async {
    await ref.read(AllControllers.chatViewController.notifier).sendMessage();
    // Mesaj gönderildiğinde her zaman aşağı scroll yap
    scrollToBottom();
  }

  void scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (force || _isNearBottom()) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(AllControllers.chatViewController);
    final messages = controller.messages ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Row(
          children: [
            ClipRRect(
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
                      color: Colors.black,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (controller.chatState == ChatState.botWriting)
                  Text(
                    "Yazıyor...",
                    style: GoogleFonts.quicksand(
                      color: Colors.grey,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (controller.chatState == ChatState.botAudioRecording)
                  Text(
                    "Ses kaydediyor...",
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
            icon: const HeroIcon(HeroIcons.ellipsisVertical),
          ),
        ],
      ),

      // --- BODY ---
      body: SafeArea(
        child: Column(
          children: [
            // Mesaj Listesi
            Expanded(
              child: messages.isEmpty
                  ? _emptyChatView()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 10.w),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return Align(
                          alignment: msg.sender == "user"
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: _chatBubble(msg),
                        );
                      },
                    ),
            ),

            // Yazı alanı
            _messageInput(controller.responseWaiting!),
          ],
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
                color: message.sender == "user"
                    ? MyColors.purple
                    : const Color(0xffF4F4F4),
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
              child: Text(
                message.message,
                style: GoogleFonts.poppins(
                  color: message.sender == "bot"
                      ? const Color(0xff555555)
                      : Colors.white,
                  fontSize: 14.sp,
                ),
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
              WavedAudioPlayer(
                showTiming: false,
            
                source: UrlSource(json["url"],mimeType: 'audio/mpeg'),
                playedColor: message.sender == "user" ? Colors.white: MyColors.purple,
                iconColor: Colors.black,
                onError: (err) {
                  print('$err');
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
                  child: Text(!isTextVisible ? "Convert to Text" : "Hide the text",style: GoogleFonts.poppins(fontSize: 9.sp,fontWeight: FontWeight.w500,color:message.sender == "user" ? Colors.white: MyColors.purple),))),
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
    return chatController.recordState == RecordState.recording
    ? Container(
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


           IconButton(onPressed: ()=>chatControllerNotifier.audioButton(), icon: HeroIcon(HeroIcons.stopCircle,style: HeroIconStyle.solid,)),
                     Expanded(child: AudioWaveforms(
            
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            waveStyle: WaveStyle(
              waveColor: MyColors.purple,
           extendWaveform: true,
              showMiddleLine: false
            ),
            size: Size(MediaQuery.sizeOf(context).width, 40.h), recorderController: chatControllerNotifier.recorderController)),

        ],
      ),
    )
    : Padding(
      padding: EdgeInsets.fromLTRB(16.w, 5.h, 16.w, 15.h),
      child:  Column(
        children: [
          if(ref.watch(AllControllers.chatViewController.notifier).selectedImage != null)...[
           Container(
     
            height: 60.h,
            padding: EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white,
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
            filled: true,
            fillColor: const Color(0xffF7F7F7),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(40),
            ),
            hintText: "Enter message",
            hintStyle: GoogleFonts.quicksand(color: Colors.black54),
            prefixIcon: CustomPopup(
              contentRadius: 40.r,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async{
                   await   ref.read(AllControllers.chatViewController.notifier).pickImage();
                   navigatorKey.currentState?.pop();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 35.w,height: 35.h,decoration: BoxDecoration(color: const Color.fromARGB(255, 240, 240, 240),borderRadius: BorderRadius.circular(50.r)),child: Center(
                          child:HeroIcon(HeroIcons.photo,style: HeroIconStyle.solid,color: const Color.fromARGB(255, 19, 19, 19),) ,
                        ),),
                        SizedBox(width: 10.w,),
                        Text("Gallery",style: GoogleFonts.quicksand(color: Colors.black,fontWeight: FontWeight.w600,fontSize: 14.sp),),
                        SizedBox(width: 10.w,),
                      ],
                    ),
                  )
          
                ],
              ),
              position: PopupPosition.top,
              child: Container(
                width: 45.w,
                height: 45.h,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MyColors.purple,
                  borderRadius: BorderRadius.circular(50.r),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
            suffixIcon: AnimatedSwitcher(
              duration: Duration(milliseconds:50),
          
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation ,child: child,),
              child: suffixIcon(isLoading),)
          ),
        ],
      ),
    );
  }


Widget suffixIcon(bool isLoading){
  final controllerStream =  ref.watch(AllControllers.chatViewController.notifier).messageController;
  final chatControllerNotifier =  ref.read(AllControllers.chatViewController.notifier);
  final hasImage = chatControllerNotifier.selectedImage != null;
  
  if (isLoading) {
   return Padding(
                padding: EdgeInsets.all(10.w),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.purple,
                ),
              );
  } else {
    // Eğer resim seçilmişse VEYA mesaj yazılmışsa gönder butonu göster
    if (hasImage || controllerStream.text.trim().isNotEmpty) {
      return IconButton(
                onPressed: sendMessage,
                icon: Icon(Icons.send, color: MyColors.purplesical),
              );
    } else {
      // Ne resim ne de mesaj varsa mikrofon göster
      return Row(
              mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
              children: [
            //    IconButton(onPressed: (){}, icon: HeroIcon(HeroIcons.photo,style: HeroIconStyle.solid,)),
                 IconButton(onPressed: () async => chatControllerNotifier.audioButton(), icon: HeroIcon(HeroIcons.microphone,style: HeroIconStyle.solid,))
              ],
            );
    }
  }

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
