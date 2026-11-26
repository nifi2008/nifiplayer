import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const NifiPlayerApp());

class NifiPlayerApp extends StatefulWidget {
  const NifiPlayerApp({super.key});

  @override
  State<NifiPlayerApp> createState() => _NifiPlayerAppState();
}

class _NifiPlayerAppState extends State<NifiPlayerApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C4DFF),
        brightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nifiplayer',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomeScreen(onToggleTheme: _toggleTheme),
    );
  }
}

class NifiLogo extends StatelessWidget {
  final double size;
  const NifiLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(Icons.music_note_rounded,
          size: size * 0.5, color: cs.onPrimary),
    );
  }
}

String formatDuration(int ms) {
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.toString();
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// صفحه‌ی اصلی: فهرست همه‌ی فایل‌های صوتی گوشی
class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();

  List<SongModel> _songs = [];
  bool _loading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });

    final granted = await _audioQuery.permissionsRequest() ||
        await Permission.audio.request().isGranted ||
        await Permission.storage.request().isGranted;

    if (!granted) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      return;
    }

    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
  }

  Future<void> _playSong(int index) async {
    final sources = _songs
        .where((s) => s.uri != null)
        .map((s) => AudioSource.uri(Uri.parse(s.uri!)))
        .toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: index,
    );
    _player.play();

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(player: _player, songs: _songs),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('nifiplayer',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSongs,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'برای پیدا کردن آهنگ‌ها، دسترسی به فایل‌های صوتی لازم است.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadSongs,
                child: const Text('دادن دسترسی'),
              ),
            ],
          ),
        ),
      );
    }

    if (_songs.isEmpty) {
      return const Center(child: Text('هیچ فایل صوتی‌ای در گوشی پیدا نشد.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _songs.length,
      itemBuilder: (_, i) {
        final song = _songs[i];
        return ListTile(
          leading: const NifiLogo(size: 48),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            song.artist ?? 'ناشناخته',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(formatDuration(song.duration ?? 0)),
          onTap: () => _playSong(i),
        );
      },
    );
  }
}

/// صفحه‌ی پخش با کنترل‌ها
class PlayerScreen extends StatefulWidget {
  final AudioPlayer player;
  final List<SongModel> songs;
  const PlayerScreen({super.key, required this.player, required this.songs});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  AudioPlayer get _player => widget.player;

  void _cycleLoop(LoopMode current) {
    final next = switch (current) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    _player.setLoopMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('در حال پخش')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const NifiLogo(size: 220),
            const SizedBox(height: 32),

            StreamBuilder<int?>(
              stream: _player.currentIndexStream,
              builder: (_, snap) {
                final i = snap.data ?? 0;
                final name = i < widget.songs.length ? widget.songs[i].title : '';
                return Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                );
              },
            ),
            const SizedBox(height: 16),

            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (_, pos) => StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (_, dur) {
                  final total = dur.data?.inMilliseconds ?? 0;
                  final current = pos.data?.inMilliseconds ?? 0;
                  return Column(
                    children: [
                      Slider(
                        value: (current > total ? total : current).toDouble(),
                        max: total == 0 ? 1 : total.toDouble(),
                        onChanged: (v) =>
                            _player.seek(Duration(milliseconds: v.toInt())),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDuration(current)),
                          Text(formatDuration(total)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (_, snap) {
                final playing = snap.data?.playing ?? false;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed:
                          _player.hasPrevious ? _player.seekToPrevious : null,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 48,
                        color: cs.onPrimary,
                        icon: Icon(playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        onPressed: () =>
                            playing ? _player.pause() : _player.play(),
                      ),
                    ),
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: _player.hasNext ? _player.seekToNext : null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StreamBuilder<bool>(
                  stream: _player.shuffleModeEnabledStream,
                  builder: (_, snap) {
                    final on = snap.data ?? false;
                    return IconButton(
                      icon: Icon(Icons.shuffle_rounded,
                          color: on ? cs.primary : null),
                      onPressed: () => _player.setShuffleModeEnabled(!on),
                    );
                  },
                ),
                StreamBuilder<LoopMode>(
                  stream: _player.loopModeStream,
                  builder: (_, snap) {
                    final mode = snap.data ?? LoopMode.off;
                    final icon = mode == LoopMode.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded;
                    return IconButton(
                      icon: Icon(icon,
                          color: mode == LoopMode.off ? null : cs.primary),
                      onPressed: () => _cycleLoop(mode),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
