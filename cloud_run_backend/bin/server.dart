import 'dart:convert';
import 'dart:io';

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/youtube/v3.dart' as youtube;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

// Configuration
const _spreadsheetId = '1WDPGYi_u2rxl1r3RCDwLG32mhwPNuCQMncDTLT_bNyw';
const _serviceAccountFile = 'dex-tags-1e80efd082ac.json';

void main(List<String> arguments) async {
  final app = Router();

  // Health check
  app.get('/', (Request request) => Response.ok('Giveaway API is running.'));

  // The main submission endpoint
  app.post('/submit', _handleSubmit);

  // Start Server
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware()) // Needed for browser fetch
      .addHandler(app.call);

  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}

Future<Response> _handleSubmit(Request request) async {
  try {
    // 1. Extract the User's Access Token from the Authorization Header
    final authHeader = request.headers['Authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden('Missing or invalid Authorization header');
    }
    final userAccessToken = authHeader.substring(7);

    // 2. Parse Form Data
    final body = await request.readAsString();
    final formData = jsonDecode(body) as Map<String, dynamic>;
    
    // 3. VERIFICATION STEP (Critical)
    // We do NOT trust the username/email sent in the form body.
    // We use the token to fetch the actual identity from Google.
    final verifiedUser = await _verifyUserIdentity(userAccessToken);
    
    if (verifiedUser == null) {
       return Response.forbidden('Invalid or expired token');
    }

    print('Verified User: ${verifiedUser['channelTitle']}');

    // 4. Write to Google Sheets
    await _appendToSheet(verifiedUser, formData);

    return Response.ok(jsonEncode({'status': 'success', 'verifiedAs': verifiedUser['channelTitle']}),
        headers: {'content-type': 'application/json'});

  } catch (e, stack) {
    print('Error: $e\n$stack');
    return Response.internalServerError(body: 'Something went wrong');
  }
}

// --- Helper: Verify User Identity ---
Future<Map<String, String>?> _verifyUserIdentity(String accessToken) async {
  // Create an authenticated HTTP client using the USER'S token
  final authClient = authenticatedClient(
      http.Client(),
      AccessCredentials(
        AccessToken('Bearer', accessToken, DateTime.now().toUtc().add(Duration(hours: 1))),
        null, // Refresh token not needed for this
        [],
      ));

  try {
    // A. Get YouTube Channel Name
    final ytApi = youtube.YouTubeApi(authClient);
    final channels = await ytApi.channels.list(
      ['snippet'], 
      mine: true,
    );

    if (channels.items == null || channels.items!.isEmpty) return null;
    final channelTitle = channels.items!.first.snippet!.title!;
    final channelId = channels.items!.first.id!;

    // B. Get Email (Requires 'email' scope on frontend)
    // We use the generic userinfo endpoint for this
    final infoResponse = await authClient.get(Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'));
    final infoJson = jsonDecode(infoResponse.body);
    final email = infoJson['email'] ?? 'No Email Scope';

    return {
      'channelTitle': channelTitle,
      'channelId': channelId,
      'email': email,
    };
  } catch (e) {
    print('Verification Failed: $e');
    return null;
  } finally {
    authClient.close();
  }
}

// --- Helper: Append to Google Sheet ---
Future<void> _appendToSheet(Map<String, String> user, Map<String, dynamic> form) async {
  // Load Service Account Credentials (The "Server's" identity)
  final accountCredentials = ServiceAccountCredentials.fromJson(
      File(_serviceAccountFile).readAsStringSync());
      
  final scopes = [sheets.SheetsApi.spreadsheetsScope];
  final authClient = await clientViaServiceAccount(accountCredentials, scopes);

  try {
    final sheetsApi = sheets.SheetsApi(authClient);

    // Construct the row data
    final rowData = [
      DateTime.now().toIso8601String(), // Timestamp
      user['channelId'],                // Verified ID (Primary Key)
      user['channelTitle'],             // Verified Username
      user['email'],                    // Verified Email
      form['what-you-won'] ?? '',       // What was won (from form)
      form['full-name'] ?? '',          // Full Name (from form)
      form['address-line1'] ?? '',      // Address Line 1 (from form)
      form['city'] ?? '',               // City (from form)
      form['state'] ?? '',              // State (from form)
      form['zip'] ?? '',                // ZIP Code (from form)
      form['local-pickup'] == 'true' ? 'Yes' : 'No', // Local Pickup (from form)
      form['shipping-issues'] == 'true' ? 'Yes' : 'No', // Shipping Issues (from form)
      form['comments'] ?? '',           // Comments (from form)
    ];

    final valueRange = sheets.ValueRange()..values = [rowData];

    await sheetsApi.spreadsheets.values.append(
      valueRange,
      _spreadsheetId,
      'Sheet1!A1', // Range to append to
      valueInputOption: 'USER_ENTERED',
    );
  } finally {
    authClient.close();
  }
}

// Middleware to allow CORS (since frontend is on localhost or different domain)
Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Authorization, Content-Type',
        });
      }
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
      });
    };
  };
}
