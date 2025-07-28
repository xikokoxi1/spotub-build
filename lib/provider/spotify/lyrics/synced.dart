part of '../spotify.dart';

class SyncedLyricsNotifier extends FamilyAsyncNotifier<SubtitleSimple, Track?> {
  Track get _track => arg!;

  Future<SubtitleSimple> getSpotifyLyrics(String? token) async {
    final res = await globalDio.getUri(
      Uri.parse(
        "https://spclient.wg.spotify.com/color-lyrics/v2/track/${_track.id}?format=json&market=from_token",
      ),
      options: Options(
        headers: {
          "User-Agent":
              "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.0.0 Safari/537.36",
          "App-platform": "WebPlayer",
          "authorization": "Bearer $token"
        },
        responseType: ResponseType.json,
        validateStatus: (status) => true,
      ),
    );

    if (res.statusCode != 200) {
      return SubtitleSimple(
        lyrics: [],
        name: _track.name!,
        uri: res.realUri,
        rating: 0,
        provider: "Spotify",
      );
    }
    final linesRaw =
        Map.castFrom<dynamic, dynamic, String, dynamic>(res.data)["lyrics"]
            ?["lines"] as List?;

    final lines = linesRaw?.map((line) {
          return LyricSlice(
            time: Duration(milliseconds: int.parse(line["startTimeMs"])),
            text: line["words"] as String,
          );
        }).toList() ??
        [];

    return SubtitleSimple(
      lyrics: lines,
      name: _track.name!,
      uri: res.realUri,
      rating: 100,
      provider: "Spotify",
    );
  }

  /// Lyrics credits: [lrclib.net](https://lrclib.net) and their contributors
  /// Thanks for their generous public API
  Future<SubtitleSimple> getLRCLibLyrics() async {
    final packageInfo = await PackageInfo.fromPlatform();

    final res = await globalDio.getUri(
      Uri(
        scheme: "https",
        host: "lrclib.net",
        path: "/api/get",
        queryParameters: {
          "artist_name": _track.artists?.first.name,
          "track_name": _track.name,
          "album_name": _track.album?.name,
          "duration": _track.duration?.inSeconds.toString(),
        },
      ),
      options: Options(
        headers: {
          "User-Agent":
              "Spotube v${packageInfo.version} (https://github.com/KRTirtho/spotube)"
        },
        responseType: ResponseType.json,
      ),
    );

    if (res.statusCode != 200) {
      return SubtitleSimple(
        lyrics: [],
        name: _track.name!,
        uri: res.realUri,
        rating: 0,
        provider: "LRCLib",
      );
    }

    final json = res.data as Map<String, dynamic>;

    final syncedLyricsRaw = json["syncedLyrics"] as String?;
    final syncedLyrics = syncedLyricsRaw?.isNotEmpty == true
        ? Lrc.parse(syncedLyricsRaw!)
            .lyrics
            .map(LyricSlice.fromLrcLine)
            .toList()
        : null;

    if (syncedLyrics?.isNotEmpty == true) {
      return SubtitleSimple(
        lyrics: syncedLyrics!,
        name: _track.name!,
        uri: res.realUri,
        rating: 100,
        provider: "LRCLib",
      );
    }

    final plainLyrics = (json["plainLyrics"] as String)
        .split("\n")
        .map((line) => LyricSlice(text: line, time: Duration.zero))
        .toList();

    return SubtitleSimple(
      lyrics: plainLyrics,
      name: _track.name!,
      uri: res.realUri,
      rating: 0,
      provider: "LRCLib",
    );
  }

  @override
  FutureOr<SubtitleSimple> build(track) async {
    try {
      final database = ref.watch(databaseProvider);
      final spotify = ref.watch(spotifyProvider);
      final auth = await ref.watch(authenticationProvider.future);

      if (track == null) {
        throw "No track currently";
      }

      final cachedLyrics = await (database.select(database.lyricsTable)
            ..where((tbl) => tbl.trackId.equals(track.id!)))
          .map((row) => row.data)
          .getSingleOrNull();

      SubtitleSimple? lyrics = cachedLyrics;

      final token = await spotify.invoke((api) => api.getCredentials());

      if ((lyrics == null || lyrics.lyrics.isEmpty) && auth != null) {
        lyrics = await getSpotifyLyrics(token.accessToken);
      }

      if (lyrics == null ||
          lyrics.lyrics.isEmpty ||
          lyrics.lyrics.length <= 5) {
        lyrics = await getLRCLibLyrics();
      }

      if (lyrics.lyrics.isEmpty) {
        throw Exception("Unable to find lyrics");
      }

      if (cachedLyrics == null || cachedLyrics.lyrics.isEmpty) {
        await database.into(database.lyricsTable).insert(
              LyricsTableCompanion.insert(
                trackId: track.id!,
                data: lyrics,
              ),
              mode: InsertMode.replace,
            );
      }

      return lyrics;
    } catch (e, stackTrace) {
      AppLogger.reportError(e, stackTrace);
      rethrow;
    }
  }
}

final syncedLyricsDelayProvider = StateProvider<int>((ref) => 0);

final syncedLyricsProvider =
    AsyncNotifierProviderFamily<SyncedLyricsNotifier, SubtitleSimple, Track?>(
  () => SyncedLyricsNotifier(),
);

final syncedLyricsMapProvider =
    FutureProvider.family((ref, Track? track) async {
  final syncedLyrics = await ref.watch(syncedLyricsProvider(track).future);

  final isStaticLyrics =
      syncedLyrics.lyrics.every((l) => l.time == Duration.zero);

  final lyricsMap = syncedLyrics.lyrics
      .map((lyric) => {lyric.time.inSeconds: lyric.text})
      .reduce((accumulator, lyricSlice) => {...accumulator, ...lyricSlice});

  return (static: isStaticLyrics, lyricsMap: lyricsMap);
});
