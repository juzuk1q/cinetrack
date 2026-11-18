import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/episode_comment.dart';
import '../models/movie_review.dart';

class ReviewRepository {
  ReviewRepository();

  Future<List<MovieReview>> getReviews(int kinopoiskId) async {
    try {
      final res = await supabase
          .from('reviews')
          .select()
          .eq('kinopoisk_id', kinopoiskId)
          .order('created_at', ascending: false);

      return (res as List)
          .map((e) => MovieReview.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<MovieReview> addReview({
    required int kinopoiskId,
    required String movieTitle,
    required String authorName,
    String authorTitle = 'Зритель CineTrack 🍿',
    required double rating,
    required String type,
    required String title,
    required String text,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw 'Для публикации рецензии необходимо войти в аккаунт';
    }

    final res = await supabase.from('reviews').insert({
      'kinopoisk_id': kinopoiskId,
      'movie_title': movieTitle,
      'user_id': user.id,
      'author_name': authorName,
      'author_title': authorTitle,
      'rating': rating,
      'type': type,
      'title': title,
      'text': text,
    }).select().single();

    return MovieReview.fromJson(res);
  }

  Future<void> deleteReview(String reviewId) async {
    await supabase.from('reviews').delete().eq('id', reviewId);
  }

  Future<List<EpisodeComment>> getEpisodeComments(
    int kinopoiskId, {
    int? episode,
    int? season,
  }) async {
    try {
      var query = supabase
          .from('episode_comments')
          .select()
          .eq('kinopoisk_id', kinopoiskId);

      if (episode != null) {
        query = query.eq('episode', episode);
      }
      if (season != null) {
        query = query.eq('season', season);
      }

      final res = await query.order('created_at', ascending: true);

      return (res as List)
          .map((e) => EpisodeComment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<EpisodeComment> addEpisodeComment({
    required int kinopoiskId,
    int episode = 1,
    int season = 1,
    String? timecode,
    required String authorName,
    required String text,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw 'Для добавления комментария необходимо войти в аккаунт';
    }

    final res = await supabase.from('episode_comments').insert({
      'kinopoisk_id': kinopoiskId,
      'episode': episode,
      'season': season,
      'timecode': timecode,
      'user_id': user.id,
      'author_name': authorName,
      'text': text,
    }).select().single();

    return EpisodeComment.fromJson(res);
  }

  Future<void> deleteEpisodeComment(String commentId) async {
    await supabase.from('episode_comments').delete().eq('id', commentId);
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

final movieReviewsProvider =
    FutureProvider.family<List<MovieReview>, int>((ref, kinopoiskId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getReviews(kinopoiskId);
});

final episodeCommentsProvider = FutureProvider.family<List<EpisodeComment>,
    ({int kinopoiskId, int episode, int season})>((ref, query) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getEpisodeComments(
    query.kinopoiskId,
    episode: query.episode,
    season: query.season,
  );
});
