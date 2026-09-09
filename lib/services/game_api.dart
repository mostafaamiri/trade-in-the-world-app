import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

const apiBaseUrl = 'https://mojtabaamiri.ir/api';

class GameApiException implements Exception {
  const GameApiException(this.message, [this.statusCode = 0]);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class GameApi {
  GameApi._(this._preferences);

  final SharedPreferences _preferences;
  String? _token;
  String? _userId;

  String? get token => _token;
  String? get userId => _userId;
  bool get hasSession => _token != null && _userId != null;

  static Future<GameApi> create() async {
    final api = GameApi._(await SharedPreferences.getInstance());
    api._token = api._preferences.getString('game_token');
    api._userId = api._preferences.getString('game_user_id');
    return api;
  }

  Future<void> _saveSession(String token, String userId) async {
    _token = token;
    _userId = userId;
    await _preferences.setString('game_token', token);
    await _preferences.setString('game_user_id', userId);
  }

  Future<void> clearSession() async {
    _token = null;
    _userId = null;
    await _preferences.remove('game_token');
    await _preferences.remove('game_user_id');
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Json> _request(String method, String path, [Json? body]) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    late final http.Response response;
    final payload = body == null ? null : jsonEncode(body);
    if (method == 'GET') {
      response = await http.get(uri, headers: _headers);
    } else if (method == 'PUT') {
      response = await http.put(uri, headers: _headers, body: payload);
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: _headers);
    } else {
      response = await http.post(uri, headers: _headers, body: payload);
    }
    Json data = <String, dynamic>{};
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = decoded.cast<String, dynamic>();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GameApiException(
        jsonString(data['error'], 'ارتباط با سرور بازی برقرار نشد.'),
        response.statusCode,
      );
    }
    return data;
  }

  Future<PlayerProfile> createGuest(String name, String avatarId) async {
    final data = await _request('POST', '/auth/guest', {
      'name': name,
      'avatarId': avatarId,
    });
    final token = jsonString(data['token']);
    final user = (data['user'] as Map? ?? const {}).cast<String, dynamic>();
    final profile = PlayerProfile.fromJson(user);
    if (token.isEmpty || profile.id.isEmpty) {
      throw const GameApiException('پاسخ ورود سرور کامل نیست.');
    }
    await _saveSession(token, profile.id);
    return profile;
  }

  Future<PlayerProfile> profile() async {
    final data = await _request('GET', '/game/profile');
    return PlayerProfile.fromJson(
      (data['user'] as Map).cast<String, dynamic>(),
    );
  }

  Future<PlayerProfile> updateProfile(String name, String avatarId) async {
    final data = await _request('PUT', '/game/profile', {
      'name': name,
      'avatarId': avatarId,
    });
    return PlayerProfile.fromJson(
      (data['user'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> deleteProfile() async {
    await _request('DELETE', '/game/profile');
    await clearSession();
  }

  Future<List<MatchInfo>> publicMatches() async {
    final data = await _request('GET', '/game/matches/public');
    return jsonMaps(data['items']).map(MatchInfo.fromJson).toList();
  }

  Future<List<Json>> league() async {
    final data = await _request('GET', '/game/league');
    return jsonMaps(data['items']);
  }

  Future<List<GameMember>> members() async {
    final data = await _request('GET', '/game/members');
    return jsonMaps(data['items']).map(GameMember.fromJson).toList();
  }

  Future<String> createMatch({
    required String name,
    required String section,
    required bool isPrivate,
    required String appVersion,
    required String appBuild,
  }) async {
    final data = await _request('POST', '/game/matches', {
      'name': name,
      'section': section,
      'isPrivate': isPrivate,
      'appVersion': appVersion,
      'appBuild': appBuild,
    });
    return jsonString(data['matchId']);
  }

  Future<String> joinMatch(
    String roomCode,
    String appVersion,
    String appBuild,
  ) async {
    final data = await _request('POST', '/game/matches/join', {
      'roomCode': roomCode,
      'appVersion': appVersion,
      'appBuild': appBuild,
    });
    return jsonString(data['matchId']);
  }

  Future<void> deleteMatch(String matchId) =>
      _request('DELETE', '/game/matches/$matchId');

  Future<GameSnapshot> snapshot(String matchId) async {
    final responses = await Future.wait([
      _request('GET', '/game/matches/$matchId'),
      _request('GET', '/game/matches/$matchId/players'),
      _request('GET', '/game/matches/$matchId/cards'),
      _request('GET', '/game/matches/$matchId/events'),
      _request('GET', '/game/matches/$matchId/trades'),
      _request('GET', '/game/matches/$matchId/business'),
    ]);
    return GameSnapshot(
      match: MatchInfo.fromJson(
        (responses[0]['match'] as Map).cast<String, dynamic>(),
      ),
      players: jsonMaps(responses[1]['items'])
          .map(MatchPlayer.fromJson)
          .toList(),
      cards: jsonMaps(responses[2]['items']).map(TradeCard.fromJson).toList(),
      events: jsonMaps(responses[3]['items']),
      trades: jsonMaps(responses[4]['items'])
          .map(PendingTrade.fromJson)
          .toList(),
      business: BusinessProgress.fromJson(
        (responses[5]['business'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  Future<BusinessProgress> business() async {
    final data = await _request('GET', '/game/business');
    return BusinessProgress.fromJson(
      (data['business'] as Map).cast<String, dynamic>(),
    );
  }

  Future<BusinessActionResult> _businessAction(
    String path, [
    Json? body,
  ]) async {
    final data = await _request('POST', path, body);
    return BusinessActionResult(
      BusinessProgress.fromJson(
        (data['business'] as Map).cast<String, dynamic>(),
      ),
      jsonString(data['message']),
    );
  }

  Future<BusinessActionResult> upgradeBusiness(String matchId) =>
      _businessAction('/game/matches/$matchId/business/upgrade');

  Future<BusinessActionResult> upgradeBusinessProfile() =>
      _businessAction('/game/business/upgrade');

  Future<BusinessActionResult> claimBusinessMission(
    String matchId,
    String missionId,
  ) => _businessAction(
    '/game/matches/$matchId/business/missions/$missionId/claim',
  );

  Future<BusinessActionResult> claimBusinessMissionProfile(String missionId) =>
      _businessAction('/game/business/missions/$missionId/claim');

  Future<BusinessActionResult> claimDailyBusinessMission(String missionId) =>
      _businessAction('/game/business/daily-missions/$missionId/claim');

  Future<BusinessActionResult> buildBusinessAsset(
    String matchId,
    String type,
  ) => _businessAction('/game/matches/$matchId/business/buildings/$type');

  Future<BusinessActionResult> buyBusinessMaterials(String matchId) =>
      _businessAction('/game/matches/$matchId/business/production/materials');

  Future<BusinessActionResult> produceBusinessGoods(String matchId) =>
      _businessAction('/game/matches/$matchId/business/production/run');

  Future<BusinessActionResult> sellBusinessGoods(String matchId) =>
      _businessAction('/game/matches/$matchId/business/production/sell');

  Future<BusinessActionResult> startInternationalContract(
    String matchId,
    String countryId,
  ) => _businessAction(
    '/game/matches/$matchId/business/international-contracts',
    {'countryId': countryId},
  );

  Future<BusinessActionResult> completeInternationalContract(
    String matchId,
    String contractId,
  ) => _businessAction(
    '/game/matches/$matchId/business/international-contracts/$contractId/complete',
  );

  Future<BusinessActionResult> startBusinessInvestment(String matchId) =>
      _businessAction('/game/matches/$matchId/business/investments');

  Future<BusinessActionResult> claimBusinessInvestment(
    String matchId,
    String investmentId,
  ) => _businessAction(
    '/game/matches/$matchId/business/investments/$investmentId/claim',
  );

  Future<void> ready(String matchId, bool isReady) =>
      _request('POST', '/game/matches/$matchId/ready', {'isReady': isReady});

  Future<void> start(String matchId) =>
      _request('POST', '/game/matches/$matchId/start');

  Future<Json> roll(String matchId) =>
      _request('POST', '/game/matches/$matchId/roll');

  Future<Json> useSouvenirWheel(String matchId) =>
      _request('POST', '/game/matches/$matchId/souvenir-wheel');

  Future<Json> useZooWheel(String matchId) =>
      _request('POST', '/game/matches/$matchId/zoo-wheel');

  Future<Json> resolveBandit(String matchId) =>
      _request('POST', '/game/matches/$matchId/bandit/resolve');

  Future<void> chooseBanditCard(String matchId, String cardId) => _request(
    'POST',
    '/game/matches/$matchId/bandit/choose',
    {'cardId': cardId},
  );

  Future<void> buyLegal(String matchId, String cardId) =>
      _request('POST', '/game/matches/$matchId/buy/legal', {'cardId': cardId});

  Future<void> buyContraband(String matchId, String cardId) => _request(
    'POST',
    '/game/matches/$matchId/buy/contraband',
    {'cardId': cardId},
  );

  Future<void> createTrade(
    String matchId,
    String buyerId,
    List<String> cardIds,
    int price,
  ) => _request('POST', '/game/matches/$matchId/trades', {
    'buyerId': buyerId,
    'cardIds': cardIds,
    'price': price,
  });

  Future<void> changeTrade(String matchId, String tradeId, String action) =>
      _request('POST', '/game/matches/$matchId/trades/$tradeId/$action');

  Future<Json> uploadProduct(String matchId, String title, XFile image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBaseUrl/game/matches/$matchId/products'),
    );
    request.headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields['title'] = title;
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = body.trim().isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(body) as Map).cast<String, dynamic>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GameApiException(
        jsonString(data['error'], 'آپلود محصول ناموفق بود.'),
        response.statusCode,
      );
    }
    return data;
  }

  Future<void> registerPushToken(String token, String version, String build) =>
      _request('POST', '/game/push-tokens', {
        'token': token,
        'platform': 'android',
        'appVersion': version,
        'appBuild': build,
      });
}
