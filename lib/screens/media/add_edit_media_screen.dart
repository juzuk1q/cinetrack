import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_header.dart';

class AddEditMediaScreen extends ConsumerStatefulWidget {
  final String? mediaId;
  const AddEditMediaScreen({super.key, required this.mediaId});

  @override
  ConsumerState<AddEditMediaScreen> createState() =>
      _AddEditMediaScreenState();
}

class _AddEditMediaScreenState extends ConsumerState<AddEditMediaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleCtrl = TextEditingController();
  final _directorCtrl = TextEditingController();
  final _actorsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _posterCtrl = TextEditingController();
  final _reviewCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  // State
  String _type = 'movie';
  String _status = 'want_to_watch';
  List<String> _selectedGenres = [];
  int? _rating;
  DateTime? _plannedDate;

  bool _isLoading = false;
  bool _initialized = false;
  List<CatalogItem> _suggestions = [];

  bool get _isEdit => widget.mediaId != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _titleCtrl.dispose();
    _directorCtrl.dispose();
    _actorsCtrl.dispose();
    _descCtrl.dispose();
    _posterCtrl.dispose();
    _reviewCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (_isEdit) return;
    final text = _titleCtrl.text.trim().toLowerCase();
    if (text.length >= 2) {
      final matches = CuratedCatalog.items.where((item) {
        return item.title.toLowerCase().contains(text) ||
            item.director.toLowerCase().contains(text);
      }).take(4).toList();
      setState(() => _suggestions = matches);
    } else {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
    }
  }

  void _applySuggestion(CatalogItem item) {
    setState(() {
      _titleCtrl.text = item.title;
      _type = item.type;
      _selectedGenres = List.from(item.genres);
      _posterCtrl.text = item.posterUrl;
      _yearCtrl.text = item.year.toString();
      _directorCtrl.text = item.director;
      _actorsCtrl.text = item.actors;
      _descCtrl.text = item.description;
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Данные для «${item.title}» подтянуты!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF7C3AED),
      ),
    );
  }

  void _initFromItem(MediaItem item) {
    if (_initialized) return;
    _initialized = true;
    _titleCtrl.text = item.title;
    _type = item.type;
    _status = item.status;
    _selectedGenres = List.from(item.genres);
    _rating = item.rating;
    _plannedDate = item.plannedDate;
    _directorCtrl.text = item.director ?? '';
    _actorsCtrl.text = item.actors ?? '';
    _descCtrl.text = item.description ?? '';
    _posterCtrl.text = item.posterUrl ?? '';
    _reviewCtrl.text = item.review ?? '';
    _yearCtrl.text = item.year?.toString() ?? '';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _plannedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    final item = MediaItem(
      id: widget.mediaId ?? '',
      userId: user.id,
      title: _titleCtrl.text.trim(),
      type: _type,
      genres: _selectedGenres,
      year: _yearCtrl.text.isNotEmpty ? int.tryParse(_yearCtrl.text) : null,
      director: _directorCtrl.text.trim().isEmpty
          ? null
          : _directorCtrl.text.trim(),
      actors:
          _actorsCtrl.text.trim().isEmpty ? null : _actorsCtrl.text.trim(),
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      posterUrl:
          _posterCtrl.text.trim().isEmpty ? null : _posterCtrl.text.trim(),
      status: _status,
      rating: _rating,
      review:
          _reviewCtrl.text.trim().isEmpty ? null : _reviewCtrl.text.trim(),
      plannedDate: _plannedDate,
      watchedAt: _status == 'watched' ? now : null,
      createdAt: now,
      updatedAt: now,
    );

    try {
      if (_isEdit) {
        await ref
            .read(mediaNotifierProvider.notifier)
            .update(widget.mediaId!, item);
      } else {
        await ref.read(mediaNotifierProvider.notifier).create(item);
      }

      ref.invalidate(mediaListProvider);
      ref.invalidate(plannedMediaProvider);
      ref.invalidate(statsDataProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isEdit ? 'Запись обновлена!' : 'Запись успешно добавлена!'),
        ),
      );
      context.go('/library');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      final itemAsync = ref.watch(mediaItemProvider(widget.mediaId!));
      return itemAsync.when(
        data: (item) {
          if (item != null) _initFromItem(item);
          return _buildScaffold(context);
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text('Ошибка: $e'))),
      );
    }
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(activeRoute: '/library'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go('/library'),
                  ),
                  title: Text(_isEdit
                      ? 'Редактировать запись'
                      : 'Добавить в коллекцию'),
                  actions: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(_isEdit ? 'Сохранить' : 'Добавить'),
                        ),
                      ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Form(
                        key: _formKey,
                        child: _buildSimpleForm(context),
                      ),
                      const SizedBox(height: 60),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Title input with Autocomplete Suggestions
        _buildLabel('Название фильма, сериала или мультфильма *'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            hintText: 'Начните вводить название (например, «Брат», «Интерстеллар»)...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _titleCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _titleCtrl.clear();
                      setState(() {
                        _suggestions = [];
                        _posterCtrl.clear();
                      });
                    },
                  )
                : null,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Введите название' : null,
        ),

        // Suggestions Dropdown/List
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF252540),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Text(
                    'Найдено в библиотеке (нажмите для автозаполнения):',
                    style: TextStyle(
                      color: Color(0xFF9F67FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                ...List.generate(_suggestions.length, (i) {
                  final sug = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        sug.posterUrl,
                        width: 36,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.movie_rounded,
                            size: 24,
                            color: Colors.white38),
                      ),
                    ),
                    title: Text(
                      '${sug.title} (${sug.year})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${AppConstants.mediaTypes[sug.type]} • ${sug.genres.take(2).join(', ')}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.auto_fix_high_rounded,
                        color: Color(0xFF7C3AED), size: 18),
                    onTap: () => _applySuggestion(sug),
                  );
                }),
              ],
            ),
          ),
        ],

        // Visual preview of found poster
        if (_posterCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _posterCtrl.text,
                  width: 50,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Постер найден автоматически',
                        style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      _posterCtrl.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Удалить постер',
                onPressed: () => setState(() => _posterCtrl.clear()),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // 2. Type selector
        _buildLabel('Категория'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: AppConstants.mediaTypes.entries.map((e) {
            final selected = _type == e.key;
            return ChoiceChip(
              avatar: Icon(
                e.key == 'movie'
                    ? Icons.movie_outlined
                    : (e.key == 'series'
                        ? Icons.tv_outlined
                        : Icons.animation_outlined),
                size: 16,
                color: selected ? Colors.white : Colors.white60,
              ),
              label: Text(e.value),
              selected: selected,
              onSelected: (_) => setState(() => _type = e.key),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // 3. Status selector
        _buildLabel('Статус просмотра'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: AppConstants.statuses.entries.map((e) {
            final selected = _status == e.key;
            return ChoiceChip(
              avatar: Text(AppConstants.statusIcons[e.key] ?? ''),
              label: Text(e.value),
              selected: selected,
              onSelected: (_) => setState(() => _status = e.key),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // 4. Conditional: Planned Date (if want_to_watch)
        if (_status == 'want_to_watch') ...[
          _buildLabel('Когда планируете посмотреть? (необязательно)'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF252540),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      size: 20, color: Color(0xFF9F67FF)),
                  const SizedBox(width: 12),
                  Text(
                    _plannedDate != null
                        ? DateFormat('d MMMM y', 'ru').format(_plannedDate!)
                        : 'Выбрать дату в планировщике...',
                    style: TextStyle(
                      color: _plannedDate != null
                          ? Colors.white
                          : Colors.white38,
                    ),
                  ),
                  const Spacer(),
                  if (_plannedDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _plannedDate = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 5. Conditional: Rating & Review (if watched or watching)
        if (_status == 'watched' || _status == 'watching') ...[
          _buildLabel('Ваша оценка (1–10)'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                RatingBar.builder(
                  initialRating: (_rating ?? 0) / 2.0,
                  minRating: 0.5,
                  maxRating: 5,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemSize: 32,
                  itemBuilder: (context, _) => const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFCA28),
                  ),
                  onRatingUpdate: (v) {
                    setState(() => _rating = (v * 2).round());
                  },
                ),
                const SizedBox(width: 12),
                if (_rating != null)
                  Text(
                    '$_rating/10',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFCA28),
                    ),
                  ),
                if (_rating != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => setState(() => _rating = null),
                    tooltip: 'Сбросить оценку',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildLabel('Ваш отзыв / впечатление'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _reviewCtrl,
            decoration: const InputDecoration(
              hintText: 'Напишите кратко, как вам фильм...',
              prefixIcon: Icon(Icons.rate_review_outlined),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
        ],

        // 6. Genres (Quick chips)
        _buildLabel('Жанры'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: AppConstants.genres.map((g) {
            final selected = _selectedGenres.contains(g);
            return FilterChip(
              label: Text(g),
              selected: selected,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _selectedGenres.add(g);
                  } else {
                    _selectedGenres.remove(g);
                  }
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // 7. Accordion: Optional advanced details (year, director, actors, poster url, desc)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E34),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: const Text(
                'Дополнительные сведения (необязательно)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              subtitle: const Text(
                'Год, режиссёр, актёры, описание и ручной URL постера',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
              leading: const Icon(Icons.tune_rounded, color: Color(0xFF9F67FF)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    children: [
                      // Year
                      TextFormField(
                        controller: _yearCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Год выпуска',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Director
                      TextFormField(
                        controller: _directorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Режиссёр',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Actors
                      TextFormField(
                        controller: _actorsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Актёры',
                          prefixIcon: Icon(Icons.people_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Custom Poster URL
                      TextFormField(
                        controller: _posterCtrl,
                        decoration: const InputDecoration(
                          labelText: 'URL постера (картинки)',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Описание сюжета',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9F67FF),
        fontWeight: FontWeight.w600,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }
}
