import 'media_backend.dart';
import 'media_item.dart';
import 'media_kind.dart';

/// Key in [MediaItem.raw] holding the playable location of a local item.
const _localSourceKey = 'plezyLocalSource';

/// A video opened from outside any media server: a file the user picked (a
/// path, or an Android SAF `content://` URI) or a direct media URL.
///
/// It has no server, so the player opens it like a downloaded copy — no
/// server lookups, reporting, or watch-state sync — with [source] as the
/// stream.
MediaItem localMediaItem({required String source, String? title}) {
  return MediaItem(
    id: 'local:$source',
    backend: MediaBackend.plex,
    kind: MediaKind.movie,
    title: title ?? localMediaTitle(source),
    raw: {_localSourceKey: source},
  );
}

/// The playable location of [item] when it is a [localMediaItem], else null.
String? localMediaSource(MediaItem item) {
  if (item.serverId != null) return null;
  final source = item.raw?[_localSourceKey];
  return source is String && source.isNotEmpty ? source : null;
}

/// A readable title for [source]: its last path segment without extension,
/// decoded. Falls back to [source] itself.
String localMediaTitle(String source) {
  final uri = Uri.tryParse(source);
  var name = source;
  if (uri != null && uri.pathSegments.isNotEmpty) {
    name = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => source);
  } else {
    name = source.split(RegExp(r'[/\\]')).lastWhere((s) => s.isNotEmpty, orElse: () => source);
  }
  try {
    name = Uri.decodeComponent(name);
  } catch (_) {}
  // SAF document ids look like "primary:Download/Movie.mkv".
  name = stripFileExtension(name.split(RegExp(r'[/:\\]')).last);
  return name.isEmpty ? source : name;
}

final _fileExtension = RegExp(r'\.[A-Za-z0-9]{2,5}$');

/// [name] without a trailing file extension ("Film.mkv" → "Film"). Leaves
/// names whose last dot is not an extension alone ("Mr. Robot").
String stripFileExtension(String name) {
  final stripped = name.replaceFirst(_fileExtension, '');
  return stripped.isEmpty ? name : stripped;
}

/// Whether [text] is a URL the player can stream directly.
bool isPlayableMediaUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || uri.host.isEmpty) return false;
  return const {'http', 'https', 'rtmp', 'rtsp', 'rtp', 'udp', 'srt'}.contains(uri.scheme.toLowerCase());
}
