import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/ViewControllers/chat_screen_view_controller.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Widgets/HomeWidgets/your_matches.dart';
import 'package:friendfy/Widgets/MessagesWidgets/quick_message.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:shimmer/shimmer.dart';

class MessagesView extends ConsumerStatefulWidget {
  const MessagesView({super.key});

  @override
  ConsumerState<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends ConsumerState<MessagesView> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    ref.read(AllControllers.chatViewController.notifier).getConversations();
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<ConversationModel> displayConversations = ref.watch(AllControllers.chatViewController).filteredConversations ?? [];
    bool isSearching = ref.watch(AllControllers.chatViewController).isSearching;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: MyAppBar(),
      body: SingleChildScrollView(
        
        child: SafeArea(
        
          child: Padding( 
           padding:  EdgeInsets.only(bottom: displayConversations.length >= 9 ? 100.h:0,left: 10), 
           child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    Text(
                      "Quick Message",
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.sp,
                      ),
                    ),
                    SizedBox(height: 10.h,),
          QuickMessage(),

               SizedBox(height: 20.h,),
               if(displayConversations.isNotEmpty)...[
                                           Text(
                      "Quick Message",
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.sp,
                      ),
                    ),
                    SizedBox(height: 10.h,),
               ],
        
                    
if(displayConversations.isNotEmpty)...[

               SizedBox(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                 child: ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: displayConversations.length,
                  itemBuilder: (context,index){
                    final conversation = displayConversations[index];
                    return _buildSwipeableConversationTile(conversation, context);
                  }
                  ),
               )
]else if(isSearching && displayConversations.isEmpty)...[
  SizedBox(
    width: MediaQuery.sizeOf(context).width,
    height: MediaQuery.sizeOf(context).height * 0.5,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80.sp,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 20.h),
          Text(
            Translate.translate("no_results_found", context),
            style: GoogleFonts.quicksand(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            Translate.translate("no_conversations_found", context),
            style: GoogleFonts.quicksand(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    ),
  ),
],

if(!isSearching && displayConversations.isEmpty)...[

Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
      children: [
          SvgPicture.asset("assets/icons/message-search.svg"),
          SizedBox(height: 10.h,),
          Text("You do not yet have any message history",textAlign: TextAlign.center,style: GoogleFonts.quicksand(color: Colors.white,fontSize: 20.sp,fontWeight: FontWeight.bold),)
      ],
    ),
  ),
)
]
            ],
          ),
        ),
      ),)
    );
  }
  String lastMessageConverter(String? value){
    if (value == null) {
      return Translate.translate("say_hi", context);
    }else if(value == "voice_message"){
      return Translate.translate("voice_message", context);
    }else{
     return value;
    }

  }

  Widget _buildSwipeableConversationTile(ConversationModel conversation, BuildContext context) {
    return Dismissible(
      key: Key(conversation.chatModel?.id.toString() ?? '${conversation.hashCode}'),
      direction: DismissDirection.endToStart, // Sadece sağdan sola kaydırma
      dismissThresholds: const {DismissDirection.endToStart: 0.35}, // WhatsApp benzeri kaydırma eşiği
      movementDuration: const Duration(milliseconds: 200),
      background: Container(
        color: Colors.transparent,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Container(
          width: 44.w,
          height: 44.h,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: HeroIcon(
            HeroIcons.trash,
            style: HeroIconStyle.solid,
            color: Colors.white,
            size: 24.sp,
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        // Dialog ile onay iste
        final shouldDelete = await _showDeleteConfirmationDialog(context, conversation);
        
        if (shouldDelete) {
          // Onay verildiyse sohbeti sil
          final success = await _deleteConversation(conversation);
          
          if (success) {
            // Başarılı silme mesajı göster
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Sohbet başarıyla silindi",
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return true; // Widget'ı tree'den kaldır
          } else {
            // Hata mesajı göster ve widget'ı geri getir
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    Translate.translate("delete_conversation_error", context) != "delete_conversation_error" 
                        ? Translate.translate("delete_conversation_error", context)
                        : "Sohbet silinemedi",
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return false; // Widget'ı geri getir
          }
        }
        
        return false; // İptal edildi, widget'ı geri getir
      },
      child: ListTile(
        onTap: () {
          ref.read(AllControllers.chatViewController.notifier).pushFromMessages(conversation.chatModel!, conversation.agentModel!);
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(40.r),
          child: CachedNetworkImage(
            imageUrl: conversation.agentModel?.photoURL ?? "",
            width: 47.w,
            height: 47.h,
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 47.w,
                height: 47.h,
                color: Colors.white,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 47.w,
              height: 47.h,
              color: Colors.grey[300],
              child: Icon(Icons.person, size: 20),
            ),
          ),
        ),
        trailing: Text( "11 AM",style: GoogleFonts.quicksand(color: Colors.white),),
        title: Text(conversation.agentModel?.name ?? "",style: GoogleFonts.quicksand(color: Colors.white),),
        subtitle: Text(
          lastMessageConverter(conversation.chatModel?.lastMessage),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context, ConversationModel conversation) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (bottomSheetContext) {
            return Container(
              padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 20.h),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                color: Colors.black.withValues(alpha: 0.95),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SvgPicture.asset("assets/icons/message-delete.svg"),
                    ),
 
                    SizedBox(height: 14.h),
                    Text(
                      "Are you sure you want to delete the message?",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.quicksand(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
              
                    SizedBox(height: 18.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                             backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 13.h),
                            ),
                            onPressed: () => Navigator.of(bottomSheetContext).pop(false),
                            child: Text(
                              Translate.translate("cancel", context),
                              style: GoogleFonts.quicksand(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 13.h),
                            ),
                            onPressed: () => Navigator.of(bottomSheetContext).pop(true),
                            child: Text(
                              Translate.translate("delete", context),
                              style: GoogleFonts.quicksand(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  Future<bool> _deleteConversation(ConversationModel conversation) async {
    try {
      // ChatViewController'da conversationId'yi set et
      ref.read(AllControllers.chatViewController.notifier).changeChatModel(
        conversation.chatModel!,
        conversation.agentModel!,
      );
      
      // Sohbeti sil
      final success = await ref.read(AllControllers.chatViewController.notifier).deleteConversation();
      
      return success;
    } catch (e) {
      debugPrint("❌ Error deleting conversation: $e");
      return false;
    }
  }
}




class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right:10),//adjust the padding as you want
      child: AppBar(
        backgroundColor: Colors.transparent,
             elevation: 0,
        automaticallyImplyLeading: false,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(),
        leadingWidth: 35.w,

        title: Text(Translate.translate("chat", context),style: GoogleFonts.quicksand(color: Colors.white,fontWeight: FontWeight.w600),),
        centerTitle: false,
     
      ), //or row/any widget
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}