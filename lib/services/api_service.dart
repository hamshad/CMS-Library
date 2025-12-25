import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/exceptions.dart';

/// Response model for login API
class LoginResponse {
  final String uid;
  final String fullName;
  final String role;

  LoginResponse({
    required this.uid,
    required this.fullName,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      uid: json['Uid']?.toString() ?? '',
      fullName: json['FullName']?.toString() ?? '',
      role: json['Role']?.toString() ?? '',
    );
  }
}

/// API service for all backend calls
class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  final String _baseUrl = AppConstants.baseUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Login with username and password
  Future<LoginResponse> login({
    required String Email,
    required String Password,
  }) async {
    final url = Uri.parse('$_baseUrl${AppConstants.loginEndpoint}');

    developer.log('LOGIN REQUEST: $url');
    developer.log('LOGIN BODY: {"Email": "$Email", "Password": "$Password"}');

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'Email': Email, 'Password': Password}),
      );

      developer.log('LOGIN RESPONSE STATUS: ${response.statusCode}');
      developer.log('LOGIN RESPONSE BODY: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LoginResponse.fromJson(data);
      } else {
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('LOGIN ERROR: $e');
      rethrow;
    }
  }

  /// Issue a book to a student
  Future<String> issueBook({
    required String cid,
    required String uid,
    required String bookId,
    String type = 'Student',
  }) async {
    final url = Uri.parse('$_baseUrl${AppConstants.bookIssuedEndpoint}');

    developer.log('ISSUE BOOK REQUEST: $url');
    developer.log('ISSUE BOOK FORM DATA: Cid=$cid, Uid=$uid, BookId=$bookId, Type=$type');

    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['Cid'] = cid;
      request.fields['Uid'] = uid;
      request.fields['BookId'] = bookId;
      request.fields['Type'] = type;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);

    } catch (e) {
      developer.log('ISSUE BOOK ERROR: $e');
      rethrow;
    }
  }

  Future<String> _handleResponse(http.Response response) async {
    developer.log('RESPONSE STATUS: ${response.statusCode}');
    developer.log('RESPONSE BODY: ${response.body}');

    String? message;
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic> && json.containsKey('Message')) {
        message = json['Message']?.toString();
      }
    } catch (_) {
      // Not JSON or parse error, fallback to raw string
    }

    if (response.statusCode == 200) {
      return message ?? response.body;
    } else {
      // If error status code, throw ApiException with the message if available
      throw ApiException(message ?? 'Request failed with status: ${response.statusCode}');
    }
  }

  /// Return a book from a student
  Future<String> returnBook({
    required String cid,
    required String uid,
    required String bookId,
    required String returnNote,
  }) async {
    final url = Uri.parse('$_baseUrl${AppConstants.bookReturnedEndpoint}');

    developer.log('RETURN BOOK REQUEST: $url');
    developer.log('RETURN BOOK FORM DATA: Cid=$cid, Uid=$uid, BookId=$bookId, ReturnNote=$returnNote');

    try {
      final request = http.MultipartRequest('POST', url);
      request.fields['Cid'] = cid;
      request.fields['Uid'] = uid;
      request.fields['BookId'] = bookId;
      request.fields['ReturnNote'] = returnNote;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } catch (e) {
      developer.log('RETURN BOOK ERROR: $e');
      rethrow;
    }
  }
}
