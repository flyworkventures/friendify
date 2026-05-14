import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/notification_model.dart';
import 'package:friendfy/Widgets/background.dart';
import 'package:friendfy/main.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(AllControllers.notificationsViewController);
    final sortedNotifications = viewModel.sortedNotifications;

    return BackgroundWidget(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
   
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 4.h),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => navigatorKey.currentState?.pop(),
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            Translate.translate(
                              TranslateKeys.notificationsListTitle,
                              context,
                            ),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20.sp,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          color: Colors.black,
                          padding: EdgeInsets.zero,
                          menuPadding: EdgeInsets.zero,
                          offset: Offset(0, 40.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          onSelected: (value) {
                            if (value == 'readAll') {
                              ref
                                  .read(
                                    AllControllers.notificationsViewController
                                        .notifier,
                                  )
                                  .markAllAsRead();
                            } else if (value == 'clearAll') {
                              ref
                                  .read(
                                    AllControllers.notificationsViewController
                                        .notifier,
                                  )
                                  .clearNotifications();
                            }
                          },
                          itemBuilder: (context) => [
                         
                            PopupMenuItem(
                              value: 'clearAll',
                              child: Row(
                                children: [
                                 SvgPicture.asset("assets/icons/trash2.svg", width: 16.w, height: 16.h, color: Colors.white,),
                                  SizedBox(width: 8.w),
                                  Text(
                                    Translate.translate(
                                      TranslateKeys.notificationsClearAll,
                                      context,
                                    ),
                                    style: GoogleFonts.quicksand(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.sp
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          child: Padding(
                            padding: EdgeInsets.all(12.w),
                            child: Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 22.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: sortedNotifications.isEmpty
                        ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        
                          Center(child: SvgPicture.asset("assets/icons/notification.svg", width: 100.w, height: 100.h,),),
                          Center(
                            child: Text(
                              Translate.translate(
                                TranslateKeys.notificationsEmpty,
                                context,
                              ),
                              style: GoogleFonts.quicksand(
                                color: Colors.white,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Center(
                                                            child: Text(
                                Translate.translate(
                                  TranslateKeys.notificationsEmptyDescription,
                                  context,
                                ),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                
                                  fontWeight: FontWeight.w500,
                                ),
                                                            ),
                                                          ),
                              )
                        ],)
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18.w,
                              vertical: 10.h,
                            ),
                            itemCount: sortedNotifications.length,
                            itemBuilder: (context, index) {
                              final notification = sortedNotifications[index];
                              return _buildNotificationItem(notification, context);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationModel notification,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () {
        ref
            .read(AllControllers.notificationsViewController.notifier)
            .markAsRead(notification.id);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeadingAvatar(notification),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.quicksand(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.sp,
                            color: Colors.white.withValues(
                              alpha: notification.isRead ? 0.8 : 1,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _formatDate(notification.createdAt),
                        style: GoogleFonts.quicksand(
                          fontSize: 11.sp,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.body,
                    style: GoogleFonts.quicksand(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingAvatar(NotificationModel notification) {
    switch (notification.type) {
      case NotificationType.trialStarted:
        return _notificationTypeCircle(
          icon: Icons.workspace_premium_rounded,
          borderColor: const Color(0xFFB355FF),
          gradient: const LinearGradient(
            colors: [Color(0xFF2B0E4B), Color(0xFF522E8C)],
          ),
        );
      case NotificationType.trialEnded:
        return _notificationTypeCircle(
          icon: Icons.hourglass_bottom_rounded,
          borderColor: const Color(0xFFFFB74D),
          gradient: const LinearGradient(
            colors: [Color(0xFF3E2723), Color(0xFF5D4037)],
          ),
        );
      case NotificationType.welcome:
        return _notificationTypeCircle(
          icon: Icons.waving_hand_rounded,
          borderColor: const Color(0xFF81C784),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          ),
        );
      case NotificationType.reminder:
        return _notificationTypeCircle(
          icon: Icons.alarm_rounded,
          borderColor: const Color(0xFF64B5F6),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          ),
        );
      case NotificationType.system:
        return _notificationTypeCircle(
          icon: Icons.info_rounded,
          borderColor: Colors.white.withValues(alpha: 0.35),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
        );
    }
  }

  Widget _notificationTypeCircle({
    required IconData icon,
    required Color borderColor,
    required Gradient gradient,
  }) {
    return Container(
      width: 42.w,
      height: 42.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.8),
        gradient: gradient,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20.sp,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return Translate.translate(
        TranslateKeys.notificationsDaysAgo,
        context,
      ).replaceAll('%%count%%', difference.inDays.toString());
    } else if (difference.inHours > 0) {
      return Translate.translate(
        TranslateKeys.notificationsHoursAgo,
        context,
      ).replaceAll('%%count%%', difference.inHours.toString());
    } else if (difference.inMinutes > 0) {
      return Translate.translate(
        TranslateKeys.notificationsMinutesAgo,
        context,
      ).replaceAll('%%count%%', difference.inMinutes.toString());
    } else {
      return Translate.translate(TranslateKeys.notificationsJustNow, context);
    }
  }
}
