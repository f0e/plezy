import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/local_media.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/services/playback_initialization_service.dart';

import '../test_helpers/media_items.dart';

void main() {
  group('localMediaItem', () {
    test('carries its source and has no server', () {
      final item = localMediaItem(source: 'content://docs/document/primary%3AMovies%2FFilm.mkv');
      expect(item.serverId, isNull);
      expect(localMediaSource(item), 'content://docs/document/primary%3AMovies%2FFilm.mkv');
      expect(item.title, 'Film');
    });

    test('keeps an explicit title', () {
      expect(localMediaItem(source: '/sdcard/a.mkv', title: 'A Film').title, 'A Film');
    });

    test('a server item is never local, whatever its raw map holds', () {
      final item = testMediaItem(
        id: '1',
        backend: MediaBackend.plex,
        kind: MediaKind.movie,
        serverId: 'srv',
        raw: {'plezyLocalSource': '/sdcard/a.mkv'},
      );
      expect(localMediaSource(item), isNull);
    });
  });

  group('localMediaTitle', () {
    test('uses the last path segment without its extension', () {
      expect(localMediaTitle('/storage/emulated/0/Download/Some Movie (2007).mkv'), 'Some Movie (2007)');
      expect(localMediaTitle('https://example.com/media/clip.mp4?token=abc'), 'clip');
      expect(localMediaTitle(r'C:\Videos\film.mp4'), 'film');
    });

    test('decodes SAF document ids', () {
      expect(
        localMediaTitle('content://com.android.externalstorage.documents/document/primary%3ADownload%2FMy%20Film.mkv'),
        'My Film',
      );
    });
  });

  group('stripFileExtension', () {
    test('removes a file extension only', () {
      expect(stripFileExtension('Film (2007).mkv'), 'Film (2007)');
      expect(stripFileExtension('Mr. Robot'), 'Mr. Robot');
      expect(stripFileExtension('Some.Show.S01E01.mp4'), 'Some.Show.S01E01');
      expect(stripFileExtension('.mkv'), '.mkv');
    });
  });

  group('isPlayableMediaUrl', () {
    test('accepts direct stream schemes', () {
      expect(isPlayableMediaUrl('https://example.com/a.mkv'), isTrue);
      expect(isPlayableMediaUrl('  http://192.168.1.5:8000/a.mp4 '), isTrue);
      expect(isPlayableMediaUrl('rtsp://camera.local/stream'), isTrue);
    });

    test('rejects everything else', () {
      expect(isPlayableMediaUrl('example.com/a.mkv'), isFalse);
      expect(isPlayableMediaUrl('file:///sdcard/a.mkv'), isFalse);
      expect(isPlayableMediaUrl('javascript:alert(1)'), isFalse);
      expect(isPlayableMediaUrl(''), isFalse);
    });
  });

  group('PlaybackInitializationService', () {
    test('plays a local item from its source without a client or database', () async {
      final service = PlaybackInitializationService();
      final result = await service.getPlaybackData(
        PlaybackInitializationOptions(
          metadata: localMediaItem(source: 'content://docs/document/1'),
          selectedMediaIndex: 0,
        ),
        requireOffline: true,
      );
      expect(result.videoUrl, 'content://docs/document/1');
      expect(result.isOffline, isTrue);
      expect(result.availableVersions, isEmpty);
    });

    test('turns a plain path into a file URL', () async {
      final result = await PlaybackInitializationService().getPlaybackData(
        PlaybackInitializationOptions(metadata: localMediaItem(source: '/sdcard/Movies/a.mkv'), selectedMediaIndex: 0),
        requireOffline: true,
      );
      expect(result.videoUrl, 'file:///sdcard/Movies/a.mkv');
    });
  });
}
