import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_app/screen/like_screen.dart';
import 'package:music_app/screen/play_screen.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicListPage extends StatefulWidget {
  const MusicListPage({super.key});

  @override
  State<MusicListPage> createState() => _MusicListPageState();
}

class _MusicListPageState extends State<MusicListPage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();
  List<SongModel> _songs = [];
  List<SongModel> _filteredSongs = [];
  SongModel? _currentSong;
  int _currentIndex = -1;
  bool _isShuffling = false;
  LoopMode _loopMode = LoopMode.off;
  TextEditingController _searchController = TextEditingController();
  List<int> _likedSongIds = [];

  @override
  void initState() {
    super.initState();
    _fetchSongs();
    _loadLikedSongs();
    _player.positionStream.listen((position) {
      if (position >= (_player.duration ?? Duration.zero) && _player.playing) {
        _playNextSong();
      }
    });
    _searchController.addListener(_filterSongs);
  }

  Future<void> _loadLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final likedSongsJson = prefs.getString('liked_songs');
    if (likedSongsJson != null) {
      final likedSongsList = jsonDecode(likedSongsJson) as List;
      setState(() {
        _likedSongIds = likedSongsList.cast<int>();
      });
    }
  }

  Future<void> _saveLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('liked_songs', jsonEncode(_likedSongIds));
  }

  void _toggleLike(SongModel song) {
    setState(() {
      if (_likedSongIds.contains(song.id)) {
        _likedSongIds.remove(song.id);
      } else {
        _likedSongIds.add(song.id);
      }
    });
    _saveLikedSongs();
  }

  Future<void> _fetchSongs() async {
    bool storagePermission = true;
    bool audioPermission = true;

    if (Platform.isAndroid) {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      int sdkInt = androidInfo.version.sdkInt ?? 0;

      if (sdkInt >= 33) {
        audioPermission = await Permission.audio.isGranted;
        if (!audioPermission) {
          audioPermission = (await Permission.audio.request()).isGranted;
        }
      } else {
        storagePermission = await Permission.storage.isGranted;
        if (!storagePermission) {
          storagePermission = (await Permission.storage.request()).isGranted;
        }
      }
    }

    bool queryPermission = await _audioQuery.permissionsStatus();
    if (!queryPermission) {
      queryPermission = await _audioQuery.permissionsRequest();
    }

    if ((storagePermission || audioPermission) && queryPermission) {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      setState(() {
        _songs = songs;
        _filteredSongs = songs;
      });

      if (songs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Musiqa fayllari topilmadi. Fayllarni tekshiring."),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Fayllarga kirish uchun ruxsat kerak!"),
          action: SnackBarAction(
            label: "Sozlamalar",
            onPressed: () {
              openAppSettings();
            },
          ),
        ),
      );
    }
  }

  void _filterSongs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs =
          _songs.where((song) {
            final title = song.title.toLowerCase();
            final artist = (song.artist ?? "").toLowerCase();
            final album = (song.album ?? "").toLowerCase();
            return title.contains(query) ||
                artist.contains(query) ||
                album.contains(query);
          }).toList();
    });
  }

  void _playSong(SongModel song, int index) async {
    setState(() {
      _currentSong = song;
      _currentIndex = _songs.indexOf(song); // To‘g‘ri indeksni aniqlash
    });
    await _player.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
    _player.setLoopMode(_loopMode);
    _player.play();
  }

  void _playNextSong() {
    int nextIndex;
    if (_isShuffling) {
      nextIndex = (DateTime.now().millisecondsSinceEpoch % _songs.length);
      while (nextIndex == _currentIndex && _songs.length > 1) {
        nextIndex = (DateTime.now().millisecondsSinceEpoch % _songs.length);
      }
    } else {
      nextIndex = (_currentIndex + 1) % _songs.length;
    }
    _playSong(_songs[nextIndex], nextIndex);
  }

  void _playPreviousSong() {
    int prevIndex =
        (_currentIndex - 1) < 0 ? _songs.length - 1 : _currentIndex - 1;
    _playSong(_songs[prevIndex], prevIndex);
  }

  void _shareSong(SongModel song) async {
    final file = File(song.data);
    if (await file.exists()) {
      await Share.shareXFiles([
        XFile(song.data),
      ], text: '${song.title} by ${song.artist ?? "Unknown Artist"}');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Fayl topilmadi!")));
    }
  }

  Future<void> _deleteSong(SongModel song) async {
    try {
      final file = File(song.data);
      if (await file.exists()) {
        await file.delete();
        setState(() {
          _songs.remove(song);
          _filteredSongs.remove(song);
          if (_currentSong == song) {
            _player.stop();
            _currentSong = null;
            _currentIndex = -1;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("${song.title} o‘chirildi")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("O‘chirishda xato: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    "Musiqalar",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.favorite,
                          size: 28,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => LikedSongsScreen(
                                    songs: _songs,
                                    likedSongIds: _likedSongIds,
                                    onPlay: _playSong,
                                  ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.search, size: 28, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Qidirish (nomi, ijrochi, albom)",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  "🔊 Banner reklama (Yandex Ads)",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredSongs.length,
                itemBuilder: (context, index) {
                  final song = _filteredSongs[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _currentSong == song
                              ? Colors.deepPurple.withOpacity(0.2)
                              : Colors.black26,
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
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(song.artist ?? "Noma'lum ijrochi"),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white70,
                        ),
                        onSelected: (value) {
                          if (value == 'share') {
                            _shareSong(song);
                          } else if (value == 'delete') {
                            _deleteSong(song);
                          } else if (value == 'like') {
                            _toggleLike(song);
                          }
                        },
                        itemBuilder:
                            (context) => [
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text("Ulashish"),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text("O‘chirish"),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'like',
                                child: Row(
                                  children: [
                                    Icon(
                                      _likedSongIds.contains(song.id)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color:
                                          _likedSongIds.contains(song.id)
                                              ? Colors.redAccent
                                              : Colors.white70,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _likedSongIds.contains(song.id)
                                          ? "Yoqtirilgan"
                                          : "Yoqtirish",
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      ),
                      onTap: () {
                        _playSong(song, index);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => PlayerScreen(
                                  player: _player,
                                  song: song,
                                  songs: _songs,
                                  currentIndex: _songs.indexOf(song),
                                  onNext: _playNextSong,
                                  onPrevious: _playPreviousSong,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (_currentSong != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => PlayerScreen(
                            player: _player,
                            song: _currentSong!,
                            songs: _songs,
                            currentIndex: _currentIndex,
                            onNext: _playNextSong,
                            onPrevious: _playPreviousSong,
                          ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.black87,
                  child: Row(
                    children: [
                      QueryArtworkWidget(
                        id: _currentSong!.id,
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentSong!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _currentSong!.artist ?? "Noma'lum ijrochi",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white70,
                        ),
                        onPressed: _playPreviousSong,
                      ),
                      IconButton(
                        icon: StreamBuilder<bool>(
                          stream: _player.playingStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? false;
                            return Icon(
                              isPlaying
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              color: Colors.white70,
                            );
                          },
                        ),
                        onPressed: () {
                          final isPlaying = _player.playing;
                          isPlaying ? _player.pause() : _player.play();
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next,
                          color: Colors.white70,
                        ),
                        onPressed: _playNextSong,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
