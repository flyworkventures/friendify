import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text("Bildirimler",style: GoogleFonts.quicksand(fontWeight: FontWeight.w600,fontSize: 16.sp),),
        centerTitle: true,
      ),
      body: ref.watch(AllControllers.notificationsViewController).notifications!.isEmpty
      ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
             
          children: [
            HeroIcon(HeroIcons.inbox,color: Colors.grey,),
            Text("Henüz bildirim yok",style: GoogleFonts.quicksand(color: Colors.grey,fontSize: 14.sp),)
          ],
        ),
      )
      : Column()
    );
  }
}