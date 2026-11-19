import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const GiphySearchApp());
}

class GiphySearchApp extends StatelessWidget {
  const GiphySearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giphy Search',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GifSearchScreen(),
    );
  }
}

class GifSearchScreen extends StatefulWidget {
  const GifSearchScreen({super.key});

  @override
  State<GifSearchScreen> createState() => _GifSearchScreenState();
}

class _GifSearchScreenState extends State<GifSearchScreen> {
  // Tava privātā Giphy API atslēga ir ievietota šeit:
  static const String giphyApiKey = 'p7sJFnZ9hwJtA4IGC8LVAth0kfOClXiy';

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _gifs = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _offset = 0;
  final int _limit = 20;
  String _currentQuery = 'trending';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchGifs(isNewSearch: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          !_isLoading) {
        _fetchGifs(isNewSearch: false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final trimmed = query.trim();
      setState(() {
        _currentQuery = trimmed.isEmpty ? 'trending' : trimmed;
      });
      _fetchGifs(isNewSearch: true);
    });
  }

  Future<void> _fetchGifs({required bool isNewSearch}) async {
    if (isNewSearch) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offset = 0;
        _gifs.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final String endpoint = _currentQuery == 'trending'
          ? 'https://api.giphy.com/v1/gifs/trending?api_key=$giphyApiKey&limit=$_limit&offset=$_offset'
          : 'https://api.giphy.com/v1/gifs/search?api_key=$giphyApiKey&q=${Uri.encodeComponent(_currentQuery)}&limit=$_limit&offset=$_offset';

      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newGifs = data['data'];

        setState(() {
          _gifs.addAll(newGifs);
          _offset += _limit;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Kļūda no servera: ${response.statusCode}';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Neizdevās savienoties. Pārbaudi interneta pieslēgumu!';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giphy Meklētājs'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Meklēt GIF (piem., cats, coding)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(isLandscape ? 4 : 2),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(int crossAxisCount) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _fetchGifs(isNewSearch: true),
                child: const Text('Mēģināt vēlreiz'),
              ),
            ],
          ),
        ),
      );
    }

    if (_gifs.isEmpty) {
      return const Center(child: Text('Nekas netika atrasts.'));
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _gifs.length,
            itemBuilder: (context, index) {
              final gif = _gifs[index];
              final previewUrl =
                  gif['images']?['fixed_width']?['url'] ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GifDetailScreen(gif: gif),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.grey[200],
                    child: Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

class GifDetailScreen extends StatelessWidget {
  final dynamic gif;

  const GifDetailScreen({super.key, required this.gif});

  @override
  Widget build(BuildContext context) {
    final String title = (gif['title'] as String?)?.isNotEmpty == true
        ? gif['title']
        : 'GIF Detaļas';
    final String originalUrl = gif['images']?['original']?['url'] ?? '';
    final String username = (gif['username'] as String?)?.isNotEmpty == true
        ? gif['username']
        : 'Nav norādīts';
    final String rating = gif['rating']?.toString().toUpperCase() ?? '-';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                originalUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('Autors: $username', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('Reitings: $rating', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

