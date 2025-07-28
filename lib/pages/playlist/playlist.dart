import 'package:flutter/material.dart' as material;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';
import 'package:spotube/components/dialogs/prompt_dialog.dart';
import 'package:spotube/components/track_presentation/presentation_props.dart';
import 'package:spotube/components/track_presentation/track_presentation.dart';
import 'package:spotube/components/track_presentation/use_is_user_playlist.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/extensions/image.dart';
import 'package:spotube/provider/spotify/spotify.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class PlaylistPage extends HookConsumerWidget {
  static const name = "playlist";

  final PlaylistSimple _playlist;
  final String id;
  const PlaylistPage({
    super.key,
    @PathParam("id") required this.id,
    required PlaylistSimple playlist,
  }) : _playlist = playlist;

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref
            .watch(
              favoritePlaylistsProvider.select(
                (value) => value.whenData(
                  (value) =>
                      value.items.firstWhereOrNull((s) => s.id == _playlist.id),
                ),
              ),
            )
            .asData
            ?.value ??
        _playlist;

    final tracks = ref.watch(playlistTracksProvider(playlist.id!));
    final tracksNotifier =
        ref.watch(playlistTracksProvider(playlist.id!).notifier);
    final isFavoritePlaylist =
        ref.watch(isFavoritePlaylistProvider(playlist.id!));

    final favoritePlaylistsNotifier =
        ref.watch(favoritePlaylistsProvider.notifier);

    final isUserPlaylist = useIsUserPlaylist(ref, playlist.id!);

    return material.RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(playlistTracksProvider(playlist.id!));
        ref.invalidate(isFavoritePlaylistProvider(playlist.id!));
        ref.invalidate(favoritePlaylistsProvider);
      },
      child: TrackPresentation(
        options: TrackPresentationOptions(
          collection: playlist,
          image: playlist.images.asUrlString(
            placeholder: ImagePlaceholder.collection,
          ),
          pagination: PaginationProps(
            hasNextPage: tracks.asData?.value.hasMore ?? false,
            isLoading: tracks.isLoading || tracks.isLoadingNextPage,
            onFetchMore: tracksNotifier.fetchMore,
            onRefresh: () async {
              ref.invalidate(playlistTracksProvider(playlist.id!));
            },
            onFetchAll: () async {
              return await tracksNotifier.fetchAll();
            },
          ),
          title: playlist.name!,
          description: playlist.description,
          owner: playlist.owner?.displayName,
          ownerImage: playlist.owner?.images?.lastOrNull?.url,
          tracks: tracks.asData?.value.items ?? [],
          routePath: '/playlist/${playlist.id}',
          isLiked: isFavoritePlaylist.asData?.value ?? false,
          shareUrl: playlist.externalUrls?.spotify ??
              "https://open.spotify.com/playlist/${playlist.id}",
          onHeart: isFavoritePlaylist.asData?.value == null
              ? null
              : () async {
                  final confirmed = isUserPlaylist
                      ? await showPromptDialog(
                          context: context,
                          title: context.l10n.delete_playlist,
                          message: context.l10n.delete_playlist_confirmation,
                        )
                      : true;
                  if (!confirmed) return null;

                  if (isFavoritePlaylist.asData!.value) {
                    await favoritePlaylistsNotifier.removeFavorite(playlist);
                  } else {
                    await favoritePlaylistsNotifier.addFavorite(playlist);
                  }
                  return isUserPlaylist;
                },
        ),
      ),
    );
  }
}
