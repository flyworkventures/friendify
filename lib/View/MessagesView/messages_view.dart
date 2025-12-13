import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/Controllers/ViewControllers/chat_screen_view_controller.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Themes/colors.dart';
import 'package:friendfy/Widgets/textfield.dart';
import 'package:friendfy/main.dart';
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
      backgroundColor: Colors.white,
      appBar: MyAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: 20),
        child: SafeArea(
        
          child: Column(
            children: [
            MyTextField(
              height: 44.h,
              prefixIcon: HeroIcon(HeroIcons.magnifyingGlass),
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              hintText: Translate.translate("search_textfield_hinttext", context),
              hintStyle: GoogleFonts.quicksand(),
              contentPadding: EdgeInsets.only(top: 5.h),
              controller: searchController,
              onChanged: (value) {
                ref.read(AllControllers.chatViewController.notifier).searchConversations(value);
              },
            ),


               SizedBox(height: 20.h,),
if(displayConversations.isNotEmpty)...[

               SizedBox(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                 child: ListView.builder(
                  itemCount: displayConversations.length,
                  itemBuilder: (context,index){
                    return ListTile(
                      onTap: () {
                        ref.read(AllControllers.chatViewController.notifier).pushFromMessages(displayConversations[index].chatModel!, displayConversations[index].agentModel!);
                      },
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(40.r),
                        child: CachedNetworkImage(
                          imageUrl: displayConversations[index].agentModel?.photoURL ?? "",
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
                            child: Icon(Icons.person, size: 20),
                          ),
                        ),
                      ),
                      title: Text(displayConversations[index].agentModel?.name ?? ""),
                      subtitle: Text(lastMessageConverter(displayConversations[index].chatModel?.lastMessage ),maxLines: 1,overflow: TextOverflow.ellipsis,style: GoogleFonts.quicksand(color: const Color.fromARGB(255, 37, 37, 37),fontSize: 13.sp),),
                    );
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
              color: Colors.grey.shade600,
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

Column(

  children: [
      HeroIcon(HeroIcons.lifebuoy,color: Colors.grey,),
      Text("Oppss.. Hiç kimseyle konuşamamışsın",style: GoogleFonts.quicksand(color: Colors.grey,fontWeight: FontWeight.w600),)
  ],
)
]
            ],
          ),
        ),
      ),
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
}




class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 10,right:10),//adjust the padding as you want
      child: AppBar(
        backgroundColor: Colors.white,
             elevation: 0,
        automaticallyImplyLeading: false,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(),
        leadingWidth: 35.w,
        leading: Image.asset("assets/logo.png",width: 45.w,),
        title: Text(Translate.translate("chat", context),style: GoogleFonts.quicksand(color: Colors.black,fontWeight: FontWeight.w600),),
        centerTitle: true,
        actions: [
          IconButton(onPressed: (){navigatorKey.currentState?.pushNamed('/agentsView');}, icon: HeroIcon(HeroIcons.plusCircle,color: MyColors.purple,))
        ],
      ), //or row/any widget
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}