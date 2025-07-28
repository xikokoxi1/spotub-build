import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:spotube/components/button/back_button.dart';

import 'package:spotube/components/titlebar/titlebar.dart';
import 'package:spotube/modules/artist/artist_album_list.dart';
import 'package:spotube/extensions/context.dart';

import 'package:spotube/pages/artist/section/footer.dart';
import 'package:spotube/pages/artist/section/header.dart';
import 'package:spotube/pages/artist/section/related_artists.dart';
import 'package:spotube/pages/artist/section/top_tracks.dart';
import 'package:spotube/provider/spotify/spotify.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class ArtistPage extends HookConsumerWidget {
  static const name = "artist";

  final String artistId;
  const ArtistPage(
    @PathParam("id") this.artistId, {
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = useScrollController();
    final theme = Theme.of(context);

    final artistQuery = ref.watch(artistProvider(artistId));

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: const [
          TitleBar(
            leading: [BackButton()],
            backgroundColor: Colors.transparent,
          )
        ],
        floatingHeader: true,
        child: material.RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(artistProvider(artistId));
            ref.invalidate(relatedArtistsProvider(artistId));
            ref.invalidate(artistAlbumsProvider(artistId));
            ref.invalidate(artistIsFollowingProvider(artistId));
            ref.invalidate(artistTopTracksProvider(artistId));
            if (artistQuery.hasValue) {
              ref.invalidate(
                  artistWikipediaSummaryProvider(artistQuery.asData!.value));
            }
          },
          child: Builder(builder: (context) {
            if (artistQuery.hasError && artistQuery.asData?.value == null) {
              return Center(child: Text(artistQuery.error.toString()));
            }
            return Skeletonizer(
              enabled: artistQuery.isLoading,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: ArtistPageHeader(artistId: artistId),
                    ),
                  ),
                  const SliverGap(20),
                  ArtistPageTopTracks(artistId: artistId),
                  const SliverGap(20),
                  SliverToBoxAdapter(child: ArtistAlbumList(artistId)),
                  SliverPadding(
                    padding: const EdgeInsets.all(8.0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        context.l10n.fans_also_like,
                        style: theme.typography.h4,
                      ),
                    ),
                  ),
                  ArtistPageRelatedArtists(artistId: artistId),
                  const SliverGap(20),
                  if (artistQuery.asData?.value != null)
                    SliverToBoxAdapter(
                      child:
                          ArtistPageFooter(artist: artistQuery.asData!.value),
                    ),
                  const SliverSafeArea(sliver: SliverGap(10)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
