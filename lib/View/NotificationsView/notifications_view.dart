import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:friendfy/AppLocalizations/translate.dart';
import 'package:friendfy/AppLocalizations/translate_keys.dart';
import 'package:friendfy/Controllers/all_controllers.dart';
import 'package:friendfy/Models/notification_model.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF060612),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF05060E),
                    const Color(0xFF140428),
                    const Color(0xFF2B0A5E).withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
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
                            fontSize: 35.sp,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        color: const Color(0xFF1A1A2A),
                        onSelected: (value) {
                          if (value == 'readAll') {
                            ref
                                .read(
                                  AllControllers.notificationsViewController
                                      .notifier,
                                )
                                .markAllAsRead();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'readAll',
                            child: Text(
                              'Mark all as read',
                              style: GoogleFonts.quicksand(color: Colors.white),
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
                      ? Center(
                          child: Text(
                            Translate.translate(
                              TranslateKeys.notificationsEmpty,
                              context,
                            ),
                            style: GoogleFonts.quicksand(
                              color: Colors.white70,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
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
    if (notification.type == NotificationType.trialStarted) {
      return Container(
        width: 42.w,
        height: 42.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFB355FF), width: 1.8),
          gradient: const LinearGradient(
            colors: [Color(0xFF2B0E4B), Color(0xFF522E8C)],
          ),
        ),
        child: Icon(
          Icons.workspace_premium_rounded,
          color: Colors.white,
          size: 20.sp,
        ),
      );
    }

    return Container(
      width: 42.w,
      height: 42.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: ClipOval(
        child: Image.asset(
          "assets/logo.png",
          fit: BoxFit.cover,
        ),
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
