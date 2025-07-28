library spotify;

import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:spotube/collections/assets.gen.dart';
import 'package:spotube/collections/env.dart';
import 'package:spotube/models/database/database.dart';
import 'package:spotube/provider/authentication/authentication.dart';
import 'package:spotube/provider/database/database.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lrc/lrc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spotify/spotify.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// ignore: depend_on_referenced_packages, implementation_imports
import 'package:riverpod/src/async_notifier.dart';
import 'package:spotube/extensions/album_simple.dart';
import 'package:spotube/extensions/track.dart';
import 'package:spotube/models/lyrics.dart';
import 'package:spotube/models/spotify/recommendation_seeds.dart';
import 'package:spotube/models/spotify_friends.dart';
import 'package:spotube/provider/custom_spotify_endpoint_provider.dart';
import 'package:spotube/provider/user_preferences/user_preferences_provider.dart';
import 'package:spotube/services/dio/dio.dart';
import 'package:spotube/services/wikipedia/wikipedia.dart';
import 'package:spotube/utils/primitive_utils.dart';

import 'package:wikipedia_api/wikipedia_api.dart';

part 'album/favorite.dart';
part 'album/tracks.dart';
part 'album/releases.dart';
part 'album/is_saved.dart';

part 'artist/artist.dart';
part 'artist/is_following.dart';
part 'artist/following.dart';
part 'artist/top_tracks.dart';
part 'artist/albums.dart';
part 'artist/wikipedia.dart';
part 'artist/related.dart';

part 'category/genres.dart';
part 'category/categories.dart';
part 'category/playlists.dart';

part 'lyrics/synced.dart';

part 'playlist/favorite.dart';
part 'playlist/playlist.dart';
part 'playlist/liked.dart';
part 'playlist/tracks.dart';
part 'playlist/featured.dart';
part 'playlist/generate.dart';

part 'search/search.dart';

part 'user/me.dart';
part 'user/friends.dart';

part 'tracks/track.dart';

part 'views/view.dart';

part 'utils/mixin.dart';
part 'utils/state.dart';
part 'utils/provider.dart';
part 'utils/async.dart';

part 'utils/provider/paginated.dart';
part 'utils/provider/cursor.dart';
part 'utils/provider/paginated_family.dart';
part 'utils/provider/cursor_family.dart';

class SpotifyApiWrapper {
  final SpotifyApi api;

  final Ref ref;
  SpotifyApiWrapper(
    this.ref,
    this.api,
  );

  bool _isRefreshing = false;

  FutureOr<T> invoke<T>(
    FutureOr<T> Function(SpotifyApi api) fn,
  ) async {
    try {
      return await fn(api);
    } catch (e) {
      if (((e is AuthorizationException && e.error == 'invalid_token') ||
              e is ExpirationException) &&
          !_isRefreshing) {
        _isRefreshing = true;
        await ref.read(authenticationProvider.notifier).refreshCredentials();

        _isRefreshing = false;
        return await fn(api);
      }
      rethrow;
    }
  }
}

final spotifyProvider = Provider<SpotifyApiWrapper>(
  (ref) {
    final authState = ref.watch(authenticationProvider);
    final anonCred = PrimitiveUtils.getRandomElement(Env.spotifySecrets);

    final wrapper = SpotifyApiWrapper(
      ref,
      authState.asData?.value == null
          ? SpotifyApi(
              SpotifyApiCredentials(
                anonCred["clientId"],
                anonCred["clientSecret"],
              ),
            )
          : SpotifyApi.withAccessToken(
              authState.asData!.value!.accessToken.value,
            ),
    );

    return wrapper;
  },
);
