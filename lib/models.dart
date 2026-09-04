typedef Json = Map<String, dynamic>;

String jsonString(Object? value, [String fallback = '']) =>
    value?.toString() ?? fallback;

int jsonInt(Object? value, [int fallback = 0]) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;

bool jsonBool(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

List<Json> jsonMaps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : const [];

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    this.email = '',
  });

  final String id;
  final String name;
  final String avatarId;
  final String email;

  factory PlayerProfile.fromJson(Json json) => PlayerProfile(
    id: jsonString(json['id']),
    name: jsonString(json['name']),
    avatarId: jsonString(json['avatarId'], 'merchant_purple'),
    email: jsonString(json['email']),
  );
}

class MatchInfo {
  const MatchInfo({
    required this.matchId,
    required this.roomCode,
    required this.name,
    required this.section,
    required this.hostId,
    required this.status,
    required this.maxPlayers,
    required this.minPlayers,
    required this.currentTurnPlayerId,
    required this.turnNumber,
    this.endsAt,
    this.winnerId,
  });

  final String matchId;
  final String roomCode;
  final String name;
  final String section;
  final String hostId;
  final String status;
  final int maxPlayers;
  final int minPlayers;
  final String currentTurnPlayerId;
  final int turnNumber;
  final DateTime? endsAt;
  final String? winnerId;

  factory MatchInfo.fromJson(Json json) => MatchInfo(
    matchId: jsonString(json['matchId']),
    roomCode: jsonString(json['roomCode']),
    name: jsonString(json['name']),
    section: jsonString(json['section']),
    hostId: jsonString(json['hostId']),
    status: jsonString(json['status']),
    maxPlayers: jsonInt(json['maxPlayers'], 6),
    minPlayers: jsonInt(json['minPlayers'], 2),
    currentTurnPlayerId: jsonString(json['currentTurnPlayerId']),
    turnNumber: jsonInt(json['turnNumber']),
    endsAt: DateTime.tryParse(jsonString(json['endsAt'])),
    winnerId: json['winnerId']?.toString(),
  );
}

class MatchPlayer {
  const MatchPlayer({
    required this.uid,
    required this.displayName,
    required this.avatarId,
    required this.position,
    required this.cashBalance,
    required this.cardIds,
    required this.hasSheriffShield,
    required this.isReady,
    required this.turnOrder,
    required this.totalWealth,
    required this.appVersion,
  });

  final String uid;
  final String displayName;
  final String avatarId;
  final int position;
  final int cashBalance;
  final List<String> cardIds;
  final bool hasSheriffShield;
  final bool isReady;
  final int turnOrder;
  final int totalWealth;
  final String appVersion;

  factory MatchPlayer.fromJson(Json json) => MatchPlayer(
    uid: jsonString(json['uid']),
    displayName: jsonString(json['displayName'], 'بازرگان'),
    avatarId: jsonString(json['avatarId'], 'merchant_purple'),
    position: jsonInt(json['position']),
    cashBalance: jsonInt(json['cashBalance']),
    cardIds: (json['cardIds'] as List? ?? const []).map(jsonString).toList(),
    hasSheriffShield: jsonBool(json['hasSheriffShield']),
    isReady: jsonBool(json['isReady']),
    turnOrder: jsonInt(json['turnOrder']),
    totalWealth: jsonInt(json['totalWealth']),
    appVersion: jsonString(json['appVersion'], 'نامشخص'),
  );
}

class TradeCard {
  const TradeCard({
    required this.cardId,
    required this.type,
    required this.title,
    required this.description,
    required this.cityId,
    required this.purchasePrice,
    required this.currentValue,
    required this.ownerId,
    required this.imageAsset,
    required this.riskLevel,
  });

  final String cardId;
  final String type;
  final String title;
  final String description;
  final String cityId;
  final int purchasePrice;
  final int currentValue;
  final String? ownerId;
  final String imageAsset;
  final int riskLevel;

  factory TradeCard.fromJson(Json json) => TradeCard(
    cardId: jsonString(json['cardId']),
    type: jsonString(json['type']),
    title: jsonString(json['title']),
    description: jsonString(json['description']),
    cityId: jsonString(json['cityId']),
    purchasePrice: jsonInt(json['purchasePrice']),
    currentValue: jsonInt(json['currentValue']),
    ownerId: json['ownerId']?.toString(),
    imageAsset: jsonString(json['imageAsset']),
    riskLevel: jsonInt(json['riskLevel']),
  );
}

class PendingTrade {
  const PendingTrade({
    required this.tradeId,
    required this.sellerId,
    required this.buyerId,
    required this.cardIds,
    required this.price,
  });

  final String tradeId;
  final String sellerId;
  final String buyerId;
  final List<String> cardIds;
  final int price;

  factory PendingTrade.fromJson(Json json) => PendingTrade(
    tradeId: jsonString(json['tradeId']),
    sellerId: jsonString(json['sellerId']),
    buyerId: jsonString(json['buyerId']),
    cardIds: (json['cardIds'] as List? ?? const []).map(jsonString).toList(),
    price: jsonInt(json['price']),
  );
}

class GameSnapshot {
  const GameSnapshot({
    required this.match,
    required this.players,
    required this.cards,
    required this.events,
    required this.trades,
  });

  final MatchInfo match;
  final List<MatchPlayer> players;
  final List<TradeCard> cards;
  final List<Json> events;
  final List<PendingTrade> trades;

  MatchPlayer? player(String userId) {
    for (final item in players) {
      if (item.uid == userId) return item;
    }
    return null;
  }
}
