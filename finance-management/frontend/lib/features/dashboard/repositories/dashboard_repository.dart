import '../../../core/network/api_client.dart';
import '../models/weekly_collections_model.dart';

class DashboardRepository {
  final ApiClient _client;

  DashboardRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// Retrieve weekly collections grouped by weekday
  Future<WeeklyCollectionsResponse> getWeeklyCollections({
    DateTime? weekDate,
    String? weekStart,
    String? weekEnd,
  }) async {
    final query = <String, dynamic>{};
    if (weekDate != null) {
      final y = weekDate.year.toString();
      final m = weekDate.month.toString().padLeft(2, '0');
      final d = weekDate.day.toString().padLeft(2, '0');
      query['week_date'] = '$y-$m-$d';
    }
    if (weekStart != null) query['week_start'] = weekStart;
    if (weekEnd != null) query['week_end'] = weekEnd;

    final response = await _client.get(
      '/dashboard/weekly-collections',
      queryParameters: query.isEmpty ? null : query,
    );

    final data = response['data'] as Map<String, dynamic>;
    return WeeklyCollectionsResponse.fromJson(data);
  }
}

