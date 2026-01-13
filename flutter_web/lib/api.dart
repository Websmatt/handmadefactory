import 'dart:convert';
import 'package:dio/dio.dart';

Dio dioWithToken(String? token) {
  final dio = Dio(BaseOptions(baseUrl: "/api"));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Content-Type'] = 'application/json';
    return handler.next(options);
  }));
  return dio;
}

String friendlyError(Object e) {
  if (e is DioException) {
    final r = e.response;
    if (r != null) {
      if (r.data is Map && (r.data as Map).containsKey('detail')) return '${r.data['detail']}';
      return 'HTTP ${r.statusCode}: ${r.data}';
    }
    return e.message ?? e.toString();
  }
  return e.toString();
}

String jsonBody(Map<String, dynamic> body) => jsonEncode(body);
