import 'package:dio/dio.dart';

/// REST client for the Janzeer node. The node is non-custodial: it serves read queries and accepts
/// already-signed transactions — never keys. Responses use the `{timestamp, version, payload}` envelope;
/// a 404 means the address has no on-chain state yet (fresh wallet), treated as a zero default.
class NodeApi {
  NodeApi(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
          headers: {'Content-Type': 'application/json'},
          // Bounded timeouts: without them a wrong/unreachable node URL makes every call hang until the OS
          // TCP timeout (minutes) with the button spinner stuck — indistinguishable from a freeze. Now a bad
          // node surfaces a clear error in seconds instead. (wallet freeze fix)
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          // Don't throw on 404 — handled per-call; throw only on 5xx via _payload checks.
          validateStatus: (s) => s != null && s < 500,
        ));

  final Dio _dio;

  /// Turn Dio's low-level errors (esp. timeouts) into a short, user-readable message instead of a raw
  /// DioException / indefinite hang. (wallet freeze fix)
  Never _fail(DioException e, String action) {
    final msg = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Node not responding — check the node URL in Settings.',
      DioExceptionType.connectionError => 'Cannot reach the node — check your connection and the node URL.',
      _ => _message(e.response) ?? '$action failed (${e.response?.statusCode ?? 'no response'})',
    };
    throw Exception(msg);
  }

  Future<dynamic> _get(String path, {Object? notFound}) async {
    final Response r;
    try {
      r = await _dio.get(path);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && notFound != null) return notFound;
      _fail(e, 'Request');
    }
    if (r.statusCode == 404 && notFound != null) return notFound;
    if (r.statusCode != 200) {
      throw Exception(_message(r) ?? 'Request failed (${r.statusCode})');
    }
    return (r.data as Map)['payload'];
  }

  Future<dynamic> _post(String path, Map<String, Object?> body) async {
    final Response r;
    try {
      r = await _dio.post(path, data: body);
    } on DioException catch (e) {
      _fail(e, 'Transaction');
    }
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception(_message(r) ?? 'Transaction rejected (${r.statusCode})');
    }
    return (r.data as Map)['payload'];
  }

  String? _message(Response? r) {
    final p = r?.data is Map ? (r!.data as Map)['payload'] : null;
    return p is Map ? p['message'] as String? : null;
  }

  Future<String> getBalance(String address) async => '${await _get('wallets/$address', notFound: '0')}';
  Future<int> getNonce(String address) async =>
      int.parse('${await _get('wallets/$address/nonce', notFound: 0)}');

  /// Recent transfers (sender or recipient), newest first → { total, list, ... }.
  Future<Map<String, dynamic>> getTransfers(String address, {int size = 15}) async {
    final p = await _get('transactions/transfers?address=$address&size=$size',
        notFound: {'total': 0, 'list': []});
    return Map<String, dynamic>.from(p as Map);
  }

  /// Paginated validators list → { total, list, ... }.
  Future<Map<String, dynamic>> getPromoters({int size = 20}) async {
    final p = await _get('promoters?size=$size', notFound: {'total': 0, 'list': []});
    return Map<String, dynamic>.from(p as Map);
  }

  Future<dynamic> postTransfer(Map<String, Object?> body) => _post('transactions/transfers', body);
  Future<dynamic> postPromoter(Map<String, Object?> body) => _post('transactions/promoters', body);
  Future<dynamic> postExitPromoter(Map<String, Object?> body) => _post('transactions/exit-promoters', body);
}
