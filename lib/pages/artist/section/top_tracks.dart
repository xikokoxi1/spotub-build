import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:spotify/spotify.dart';
import 'package:spotube/collections/fake.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/dialogs/select_device_dialog.dart';
import 'package:spotube/components/track_tile/track_tile.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/models/connect/connect.dart';
import 'package:spotube/provider/connect/connect.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/spotify/spotify.dart';

class ArtistPageTopTracks extends HookConsumerWidget {
  final String artistId;
  const ArtistPageTopTracks({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);

    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final topTracksQuery = ref.watch(artistTopTracksProvider(artistId));

    final isPlaylistPlaying = playlist.containsTracks(
      topTracksQuery.asData?.value ?? <Track>[],
    );

    if (topTracksQuery.hasError) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text(topTracksQuery.error.toString()),
        ),
      );
    }

    final topTracks = topTracksQuery.asData?.value ??
        List.generate(10, (index) => FakeData.track);

    void playPlaylist(List<Track> tracks, {Track? currentTrack}) async {
      currentTrack ??= tracks.first;

      final isRemoteDevice = await showSelectDeviceDialog(context, ref);

      if (isRemoteDevice == null) return;

      if (isRemoteDevice) {
        final remotePlayback = ref.read(connectProvider.notifier);
        final remotePlaylist = ref.read(queueProvider);

        final isPlaylistPlaying = remotePlaylist.containsTracks(tracks);

        if (!isPlaylistPlaying) {
          await remotePlayback.load(
            WebSocketLoadEventData.playlist(
              tracks: tracks,
              collection: null,
              initialIndex: tracks.indexWhere((s) => s.id == currentTrack?.id),
            ),
          );
        } else if (isPlaylistPlaying &&
            currentTrack.id != null &&
            currentTrack.id != remotePlaylist.activeTrack?.id) {
          final index = playlist.tracks
              .toList()
              .indexWhere((s) => s.id == currentTrack!.id);
          await remotePlayback.jumpTo(index);
        }
      } else {
        if (!isPlaylistPlaying) {
          playlistNotifier.load(
            tracks,
            initialIndex: tracks.indexWhere((s) => s.id == currentTrack?.id),
            autoPlay: true,
          );
        } else if (isPlaylistPlaying &&
            currentTrack.id != null &&
            currentTrack.id != playlist.activeTrack?.id) {
          await playlistNotifier.jumpToTrack(currentTrack);
        }
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  context.l10n.top_tracks,
                  style: theme.typography.h4,
                ),
              ),
              if (!isPlaylistPlaying)
                IconButton.outline(
                  icon: const Icon(
                    SpotubeIcons.queueAdd,
                  ),
                  onPressed: () {
                    playlistNotifier.addTracks(topTracks.toList());
                    showToast(
                      context: context,
                      location: ToastLocation.topRight,
                      builder: (context, overlay) {
                        return SurfaceCard(
                          child: Text(
                            context.l10n.added_to_queue(
                              topTracks.length,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(width: 5),
              IconButton.primary(
                shape: ButtonShape.circle,
                enabled: !isPlaylistPlaying,
                icon: Skeleton.keep(
                  child: Icon(
                    isPlaylistPlaying ? SpotubeIcons.pause : SpotubeIcons.play,
                  ),
                ),
                onPressed: () => playPlaylist(topTracks.toList()),
              )
            ],
          ),
        ),
        const SliverGap(10),
        SliverList.builder(
          itemCount: topTracks.length,
          itemBuilder: (context, index) {
            final track = topTracks.elementAt(index);
            return TrackTile(
              index: index,
              playlist: playlist,
              track: track,
              onTap: () async {
                playPlaylist(
                  topTracks.toList(),
                  currentTrack: track,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
