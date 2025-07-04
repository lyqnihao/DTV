import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'movie_detail_page.dart';

class SearchPage extends StatefulWidget {

  final String? initialQuery;

  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final Dio _dio = Dio()..interceptors.add(LogInterceptor());
  CancelToken _cancelToken = CancelToken();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _movies = [];
  bool _isLoading = false;
  bool _showSearchHint = true;

  // 颜色方案
  final Color _primaryColor = const Color(0xFF00C8FF);
  final Color _darkBackground = const Color(0xFF121212);
  final Color _cardBackground = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = const Color(0xFFAAAAAA);

  @override
  void initState() {
    super.initState();

    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _searchMovies(widget.initialQuery!);
    }
    _searchFocusNode.addListener(_onFocusChange);
    _searchController.addListener(_onSearchTextChange);
  }

  void _onFocusChange() {
    setState(() {});
  }

  void _onSearchTextChange() {
    setState(() {
      _showSearchHint = _searchController.text.isEmpty;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _searchMovies(String keyword) async {
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _movies = [];
    });

    try {
      final response = await _dio.get(
        'http://localhost:8023/api/search',
        queryParameters: {'wd': keyword, 'limit': 100},
        cancelToken: _cancelToken.isCancelled ? _cancelToken = CancelToken() : _cancelToken,
      );

      if (response.statusCode == 200 && response.data['code'] == 1) {
        setState(() {
          _movies = response.data['list'] ?? [];
        });
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      _showError('搜索失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFFB00020),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(32),
        color: _cardBackground,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: _searchFocusNode.hasFocus ? Border.all(color: _primaryColor, width: 3) : null,
            boxShadow: _searchFocusNode.hasFocus
                ? [BoxShadow(color: _primaryColor.withAlpha((255 * 0.3).toInt()), blurRadius: 12, spreadRadius: 2)]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    style: TextStyle(fontSize: 24, color: _textColor, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: '搜索电影、电视剧...',
                      hintStyle: TextStyle(fontSize: 22, color: _hintColor),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      _searchMovies(value.trim());
                    },
                  ),
                ),
              ),
              _buildSearchButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return Row(
      children: [
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
              _searchMovies(_searchController.text.trim());
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasFocus ? _primaryColor : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: hasFocus
                      ? [BoxShadow(color: _primaryColor.withAlpha(255 ~/ 2), blurRadius: 12, spreadRadius: 2)]
                      : null,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _searchMovies(_searchController.text.trim()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 32, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          '搜索',
                          style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 6, valueColor: AlwaysStoppedAnimation(Color(0xFF00C8FF))),
            const SizedBox(height: 32),
            Text(
              '正在搜索中...',
              style: TextStyle(fontSize: 24, color: _textColor.withAlpha((255 * 0.8).toInt())),
            ),
          ],
        ),
      );
    }

    if (_movies.isEmpty) {
      return _showSearchHint
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_creation, size: 120, color: _hintColor.withAlpha((255 * 0.3).toInt())),
            const SizedBox(height: 32),
            Text(
              '输入电影或电视剧名称',
              style: TextStyle(fontSize: 28, color: _hintColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              '使用遥控器方向键导航，确认键选择',
              style: TextStyle(fontSize: 20, color: _hintColor.withAlpha((255 * 0.7).toInt())),
            ),
          ],
        ),
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 120, color: _hintColor.withAlpha((255 * 0.3).toInt())),
            const SizedBox(height: 32),
            Text(
              '没有找到相关内容',
              style: TextStyle(fontSize: 28, color: _hintColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              '尝试其他关键词',
              style: TextStyle(fontSize: 20, color: _hintColor.withAlpha((255 * 0.7).toInt())),
            ),
          ],
        ),
      );
    }

    return _buildMovieGrid();
  }

  Widget _buildMovieGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 200).floor().clamp(2, 6);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              child: Row(
                children: [
                  Text(
                    '搜索结果 (${_movies.length})',
                    style: TextStyle(fontSize: 22, color: _textColor.withAlpha((255 * 0.8).toInt())),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _movies.length,
                itemBuilder: (context, index) {
                  final movie = _movies[index];
                  return _buildMovieCard(movie);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MovieDetailPage(movie: movie)),
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: hasFocus
                  ? [BoxShadow(color: _primaryColor.withAlpha((255 * 0.4).toInt()), blurRadius: 16, spreadRadius: 4)]
                  : [BoxShadow(color: Colors.black.withAlpha((255 * 0.4).toInt()), blurRadius: 8, spreadRadius: 2)],
            ),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: hasFocus ? BorderSide(color: _primaryColor, width: 3) : BorderSide.none,
              ),
              elevation: hasFocus ? 8 : 4,
              color: _cardBackground,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MovieDetailPage(movie: movie)),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: movie['vod_pic'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(color: Colors.grey[300]),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                        memCacheWidth: 200,
                        memCacheHeight: 300,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie['vod_name'] ?? '未知标题',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, color: _textColor, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (movie['vod_year']?.toString().isNotEmpty ?? false)
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withAlpha((255 * 0.2).toInt()),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      movie['vod_year'].toString(),
                                      style: TextStyle(fontSize: 12, color: _primaryColor),
                                    ),
                                  ),
                                ),
                              if (movie['type_name']?.toString().isNotEmpty ?? false) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    movie['type_name'],
                                    style: TextStyle(fontSize: 12, color: _hintColor),
                                  ),
                                ),
                              ],
                              if (movie['vod_play_from']?.toString().isNotEmpty ?? false) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '| ${movie['vod_play_from']}',
                                    style: TextStyle(fontSize: 12, color: _hintColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (hasFocus)
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_searchFocusNode.hasFocus && _searchController.text.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _cancelToken.cancel();
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          } else if (_searchController.text.isNotEmpty) {
            setState(() {
              _movies.clear();
              _searchController.clear();
            });
          } else {
            Navigator.maybePop(context);
          }
        }
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size(double.infinity, 200),
            child: _buildSearchField(),
          ),
          backgroundColor: _darkBackground,
          body: _buildContent(),
        ),
      ),
    );
  }
}