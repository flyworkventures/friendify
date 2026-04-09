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
      body: () {
        final viewModel = ref.watch(AllControllers.notificationsViewController);
        final sortedNotifications = viewModel.sortedNotifications;
        
        return sortedNotifications.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HeroIcon(HeroIcons.inbox,color: Colors.grey,),
              SizedBox(height: 10.h),
              Text("Henüz bildirim yok",style: GoogleFonts.quicksand(color: Colors.grey,fontSize: 14.sp),)
            ],
          ),
        )
        : ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: sortedNotifications.length,
          itemBuilder: (context, index) {
            final notification = sortedNotifications[index];
            return _buildNotificationItem(notification, context);
          },
        );
      }()
    );
  }

  Widget _buildNotificationItem(notification, BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: CircleAvatar(
          radius: 24.r,
          backgroundColor: Colors.black.withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsets.all(6.w),
            child: Image.asset(
              "assets/logo.png",
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(
          notification.title,
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
            color: notification.isRead ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: Text(
            notification.body,
            style: GoogleFonts.quicksand(
              fontSize: 12.sp,
              color: notification.isRead ? Colors.grey[600] : Colors.black87,
            ),
          ),
        ),
        trailing: Text(
          _formatDate(notification.createdAt),
          style: GoogleFonts.quicksand(
            fontSize: 10.sp,
            color: Colors.grey,
          ),
        ),
        onTap: () {
          // Bildirimi okundu olarak işaretle
          ref.read(AllControllers.notificationsViewController.notifier).markAsRead(notification.id);
        },
      ),
    );
  }

  Color _getNotificationColor(notificationType) {
    switch (notificationType.toString().split('.').last) {
      case 'welcome':
        return Colors.blue;
      case 'trialStarted':
        return Colors.green;
      case 'trialEnded':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  HeroIcons _getNotificationIcon(notificationType) {
    switch (notificationType.toString().split('.').last) {
      case 'welcome':
        return HeroIcons.sparkles;
      case 'trialStarted':
        return HeroIcons.gift;
      case 'trialEnded':
        return HeroIcons.clock;
      default:
        return HeroIcons.bell;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }
}