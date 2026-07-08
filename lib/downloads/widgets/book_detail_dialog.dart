import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/online_book_service.dart';

class BookDetailDialog extends StatelessWidget {
  const BookDetailDialog({
    super.key,
    required this.fallbackTitle,
    required this.detail,
    required this.onDownload,
    required this.downloadStatusListenable,
  });

  final String fallbackTitle;
  final BookDetailData detail;
  final ValueChanged<String> onDownload;
  final ValueListenable<String?> downloadStatusListenable;

  @override
  Widget build(BuildContext context) {
    final title = detail.title.trim().isNotEmpty ? detail.title : fallbackTitle;
    final intro = detail.intro.trim().isNotEmpty ? detail.intro : '暂无简介';

    return ValueListenableBuilder<String?>(
      valueListenable: downloadStatusListenable,
      builder: (context, status, _) {
        final isDownloading = status != null && status.isNotEmpty;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560.w,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(intro),
                  SizedBox(height: 12.h),
                  if (isDownloading) ...[
                    LinearProgressIndicator(minHeight: 6.h),
                    SizedBox(height: 6.h),
                    Text(
                      status,
                      style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                    ),
                    SizedBox(height: 12.h),
                  ],
                  Text(
                    '下载链接：',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ...detail.links.map((u) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              u,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          ElevatedButton(
                            onPressed:
                                isDownloading ? null : () => onDownload(u),
                            child: const Text('下载'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
