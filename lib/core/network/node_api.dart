import 'package:dio/dio.dart';

/// REST client for the Janzeer node. The node is non-custodial: it serves read queries and accepts
/// already-signed transactions — never keys. Responses use the `{timestamp, version, payload}` envelope;
/// a 404 means the address has no on-chain state yet (fresh wallet), treated as a zero default.
class NodeApi {
  NodeApi(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
          headers: {'Content-Type': 'application/json'},
          // Don't throw on 404 — handled per-call; throw only on 5xx via _payload checks.
          validateStatus: (s) => s != null && s < 500,
        ));

  final Dio _dio;

  Future<dynamic> _get(String path, {Object? notFound}) async {
    final r = await _dio.get(path);
    if (r.statusCode == 404 && notFound != null) return notFound;
    if (r.statusCode != 200) {
      throw Exception(_message(r) ?? 'Request failed (${r.statusCode})');
    }
    return (r.data as Map)['payload'];
  }

  Future<dynamic> _post(String path, Map<String, Object?> body) async {
    final r = await _dio.post(path, data: body);
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception(_message(r) ?? 'Transaction rejected (${r.statusCode})');
    }
    return (r.data as Map)['payload'];
  }

  String? _message(Response r) {
    final p = r.data is Map ? (r.data as Map)['payload'] : null;
    return p is Map ? p['message'] as String? : null;
  }

  Future<String> getBalance(String address) async => '${await _get('wallets/$address', notFound: '0')}';
  Future<int> getNonce(String address) async =>
      int.parse('${await _get('wallets/$address/nonce', notFound: 0)}');
  Future<String> getAccruedReward(String address) async =>
      '${await _get('wallets/$address/accruedReward', notFound: '0')}';

  /// Current delegation (VoteResponse) or null if not delegating.
  Future<Map<String, dynamic>?> getDelegation(String address) async {
    final p = await _get('wallets/promoters/$address', notFound: null);
    return p == null ? null : Map<String, dynamic>.from(p as Map);
  }

  /// Recent transfers (sender or recipient), newest first → { total, list, ... }.
  Future<Map<String, dynamic>> getTransfers(String address, {int size = 15}) async {
    final p = await _get('transactions/transfers?address=$address&size=$size',
        notFound: {'total': 0, 'list': []});
    return Map<String, dynamic>.from(p as Map);
  }

  /// Paginated promoters list (for delegation discovery) → { total, list, ... }.
  Future<Map<String, dynamic>> getPromoters({int size = 20}) async {
    final p = await _get('promoters?size=$size', notFound: {'total': 0, 'list': []});
    return Map<String, dynamic>.from(p as Map);
  }

  Future<dynamic> postTransfer(Map<String, Object?> body) => _post('transactions/transfers', body);
  Future<dynamic> postVote(Map<String, Object?> body) => _post('transactions/votes', body);
  Future<dynamic> postPromoter(Map<String, Object?> body) => _post('transactions/promoters', body);
  Future<dynamic> postClaimReward(Map<String, Object?> body) => _post('transactions/claim-rewards', body);
}
