class CatalogItem {
  final String title;
  final String type; // 'movie' | 'series' | 'cartoon'
  final List<String> genres;
  final int year;
  final String director;
  final String actors;
  final String description;
  final String posterUrl;
  final double rating;

  const CatalogItem({
    required this.title,
    required this.type,
    required this.genres,
    required this.year,
    required this.director,
    required this.actors,
    required this.description,
    required this.posterUrl,
    required this.rating,
  });
}
