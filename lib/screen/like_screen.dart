import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_app/screen/play_screen.dart';
import 'package:on_audio_query/on_audio_query.dart';

class LikedSongsScreen extends StatelessWidget {
  final List<SongModel> songs;
  final List<int> likedSongIds;
  final Function(SongModel, int) onPlay;

  const LikedSongsScreen({
    super.key,
    required this.songs,
    required this.likedSongIds,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final likedSongs =
        songs.where((song) => likedSongIds.contains(song.id)).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Yoqtirilgan qo‘shiqlar",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  likedSongs.isEmpty
                      ? const Center(
                        child: Text(
                          "Yoqtirilgan qo‘shiqlar yo‘q",
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      )
                      : ListView.builder(
                        itemCount: likedSongs.length,
                        itemBuilder: (context, index) {
                          final song = likedSongs[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: QueryArtworkWidget(
                                id: song.id,
                                type: ArtworkType.AUDIO,
                                artworkHeight: 50,
                                artworkWidth: 50,
                                artworkBorder: BorderRadius.circular(8),
                                nullArtworkWidget: const Icon(
                                  Icons.music_note,
                                  color: Colors.deepPurpleAccent,
                                  size: 50,
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(song.artist ?? "Noma'lum ijrochi"),
                              trailing: const Icon(
                                Icons.favorite,
                                color: Colors.redAccent,
                              ),
                              onTap: () {
                                onPlay(song, songs.indexOf(song));
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PlayerScreen(
                                          player: AudioPlayer(),
                                          song: song,
                                          songs: songs,
                                          currentIndex: songs.indexOf(song),
                                          onNext: () {},
                                          onPrevious: () {},
                                        ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
