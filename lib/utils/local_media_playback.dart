import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:saf_util/saf_util.dart';

import '../i18n/strings.g.dart';
import '../media/local_media.dart';
import '../services/file_picker_service.dart';
import 'app_logger.dart';
import 'dialogs.dart';
import 'snackbar_helper.dart';
import 'video_player_navigation.dart';

/// Lets the user pick a video file and plays it in the built-in player.
///
/// Android opens the system document picker and plays the returned
/// `content://` URI in place — nothing is copied, so a large file on internal
/// storage or a USB drive starts at once. Other platforms pick a path.
Future<void> pickAndPlayLocalFile(BuildContext context) async {
  String? source;
  String? name;
  try {
    if (Platform.isAndroid) {
      final file = await SafUtil().pickFile(mimeTypes: const ['video/*']);
      source = file?.uri;
      name = file?.name;
    } else {
      final result = await FilePickerService.instance.pickFiles(type: FileType.video);
      final file = result?.files.singleOrNull;
      source = file?.path;
      name = file?.name;
    }
  } catch (e, st) {
    appLogger.w('Picking a local video failed', error: e, stackTrace: st);
    if (context.mounted) showErrorSnackBar(context, t.localMedia.pickFailed);
    return;
  }
  if (source == null || !context.mounted) return;
  await playLocalMedia(context, source, title: name);
}

/// Asks for a direct media URL and plays it in the built-in player.
Future<void> promptAndPlayMediaUrl(BuildContext context) async {
  final url = await showTextInputDialog(
    context,
    title: t.localMedia.openUrl,
    labelText: t.localMedia.urlLabel,
    hintText: 'https://',
    confirmText: t.localMedia.play,
    keyboardType: TextInputType.url,
    validator: (value) => isPlayableMediaUrl(value) ? null : t.localMedia.invalidUrl,
  );
  if (url == null || !context.mounted) return;
  await playLocalMedia(context, url.trim());
}

/// Plays [source] — a file path, `content://` URI, or URL — in the built-in
/// player. [title] is a file name or title; it defaults to the source's file
/// name.
Future<void> playLocalMedia(BuildContext context, String source, {String? title}) {
  return navigateToVideoPlayer(
    context,
    metadata: localMediaItem(source: source, title: title == null ? null : stripFileExtension(title)),
    isOffline: true,
    resolveWatchState: false,
  );
}
