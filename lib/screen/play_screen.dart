import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerScreen extends StatefulWidget {
  final AudioPlayer player;
  final SongModel song;
  final List<SongModel> songs;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const PlayerScreen({
    super.key,
    required this.player,
    required this.song,
    required this.songs,
    required this.currentIndex,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double _currentVolume = 0.5;
  bool _isShuffling = false;
  LoopMode _loopMode = LoopMode.off;
  List<int> _likedSongIds = [];

  @override
  void initState() {
    super.initState();
    _getVolume();
    widget.player.setLoopMode(_loopMode);
    _loadLikedSongs();
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

  Future<void> _getVolume() async {
    try {
      setState(() {
        _currentVolume = widget.player.volume;
      });
    } catch (e) {
      print("Ovoz balandligini olishda xato: $e");
      setState(() {
        _currentVolume = 0.5;
      });
    }
  }

  Future<void> _setVolume(double volume) async {
    try {
      await widget.player.setVolume(volume);
      setState(() => _currentVolume = volume);
    } catch (e) {
      print("Ovoz balandligini o‘zgartirishda xato: $e");
    }
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffling = !_isShuffling;
    });
  }

  void _toggleLoopMode() {
    setState(() {
      if (_loopMode == LoopMode.off) {
        _loopMode = LoopMode.one;
      } else if (_loopMode == LoopMode.one) {
        _loopMode = LoopMode.all;
      } else {
        _loopMode = LoopMode.off;
      }
      widget.player.setLoopMode(_loopMode);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Ijro etilmoqda",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white70),
                      onPressed: () {
                        _shareSong(widget.song);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: QueryArtworkWidget(
                              id: widget.song.id,
                              type: ArtworkType.AUDIO,
                              artworkHeight: 250,
                              artworkWidth: 250,
                              artworkFit: BoxFit.cover,
                              nullArtworkWidget: Container(
                                height: 250,
                                width: 250,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.deepPurple,
                                      Colors.purpleAccent,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  size: 100,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.song.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.song.artist ?? 'Noma\'lum ijrochi',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        StreamBuilder<Duration?>(
                          stream: widget.player.durationStream,
                          builder: (context, durationSnapshot) {
                            final total =
                                durationSnapshot.data ?? Duration.zero;
                            return StreamBuilder<Duration>(
                              stream: widget.player.positionStream,
                              builder: (context, positionSnapshot) {
                                final position =
                                    positionSnapshot.data ?? Duration.zero;
                                return Column(
                                  children: [
                                    Slider(
                                      min: 0,
                                      max: total.inSeconds.toDouble(),
                                      value:
                                          position.inSeconds
                                              .clamp(0, total.inSeconds)
                                              .toDouble(),
                                      onChanged: (value) {
                                        widget.player.seek(
                                          Duration(seconds: value.toInt()),
                                        );
                                      },
                                      activeColor: Colors.deepPurpleAccent,
                                      inactiveColor: Colors.grey,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(total),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _loopMode == LoopMode.off
                                    ? Icons.repeat
                                    : _loopMode == LoopMode.one
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                                color:
                                    _loopMode != LoopMode.off
                                        ? Colors.deepPurpleAccent
                                        : Colors.white70,
                              ),
                              onPressed: _toggleLoopMode,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_previous,
                                color: Colors.white70,
                              ),
                              iconSize: 40,
                              onPressed: widget.onPrevious,
                            ),
                            IconButton(
                              iconSize: 64,
                              icon: StreamBuilder<bool>(
                                stream: widget.player.playingStream,
                                builder: (context, snapshot) {
                                  final isPlaying = snapshot.data ?? false;
                                  return Icon(
                                    isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    color: Colors.deepPurpleAccent,
                                  );
                                },
                              ),
                              onPressed: () async {
                                final isPlaying = widget.player.playing;
                                isPlaying
                                    ? widget.player.pause()
                                    : widget.player.play();
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next,
                                color: Colors.white70,
                              ),
                              iconSize: 40,
                              onPressed: widget.onNext,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.shuffle,
                                color:
                                    _isShuffling
                                        ? Colors.deepPurpleAccent
                                        : Colors.white70,
                              ),
                              onPressed: _toggleShuffle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.volume_down,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 200,
                              child: Slider(
                                min: 0,
                                max: 1,
                                value: _currentVolume,
                                onChanged: (value) {
                                  _setVolume(value);
                                },
                                activeColor: Colors.deepPurpleAccent,
                                inactiveColor: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.volume_up, color: Colors.white70),
                          ],
                        ),
                        Text(
                          "Tovush: ${(100 * _currentVolume).toInt()}%",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _likedSongIds.contains(widget.song.id)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    _likedSongIds.contains(widget.song.id)
                                        ? Colors.redAccent
                                        : Colors.white70,
                              ),
                              onPressed: () {
                                _toggleLike(widget.song);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _likedSongIds.contains(widget.song.id)
                                          ? "${widget.song.title} yoqtirilganlardan olindi!"
                                          : "${widget.song.title} yoqtirildi!",
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                try {
                                  final file = File(widget.song.data);
                                  if (await file.exists()) {
                                    await file.delete();
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "${widget.song.title} o‘chirildi",
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("O‘chirishda xato: $e"),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
