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

class GameMember {
  const GameMember({
    required this.id,
    required this.name,
    required this.avatarId,
  });

  final String id;
  final String name;
  final String avatarId;

  factory GameMember.fromJson(Json json) => GameMember(
    id: jsonString(json['id']),
    name: jsonString(json['name'], 'بازرگان'),
    avatarId: jsonString(json['avatarId'], 'merchant_purple'),
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

class BusinessRequirement {
  const BusinessRequirement({
    required this.id,
    required this.label,
    required this.current,
    required this.required,
    required this.complete,
  });

  final String id;
  final String label;
  final int current;
  final int required;
  final bool complete;

  factory BusinessRequirement.fromJson(Json json) => BusinessRequirement(
    id: jsonString(json['id']),
    label: jsonString(json['label']),
    current: jsonInt(json['current']),
    required: jsonInt(json['required']),
    complete: jsonBool(json['complete']),
  );
}

class BusinessFeature {
  const BusinessFeature({required this.id, required this.label});

  final String id;
  final String label;

  factory BusinessFeature.fromJson(Json json) => BusinessFeature(
    id: jsonString(json['id']),
    label: jsonString(json['label']),
  );
}

class BusinessMission {
  const BusinessMission({
    required this.id,
    required this.title,
    required this.description,
    required this.stage,
    required this.current,
    required this.target,
    required this.complete,
    required this.claimed,
    required this.capitalReward,
    required this.reputationReward,
    required this.experienceReward,
  });

  final String id;
  final String title;
  final String description;
  final int stage;
  final int current;
  final int target;
  final bool complete;
  final bool claimed;
  final int capitalReward;
  final int reputationReward;
  final int experienceReward;

  factory BusinessMission.fromJson(Json json) {
    final reward = (json['reward'] as Map? ?? const {}).cast<String, dynamic>();
    return BusinessMission(
      id: jsonString(json['id']),
      title: jsonString(json['title']),
      description: jsonString(json['description']),
      stage: jsonInt(json['stage'], 1),
      current: jsonInt(json['current']),
      target: jsonInt(json['target'], 1),
      complete: jsonBool(json['complete']),
      claimed: jsonBool(json['claimed']),
      capitalReward: jsonInt(reward['capital']),
      reputationReward: jsonInt(reward['reputation']),
      experienceReward: jsonInt(reward['experience']),
    );
  }
}

class DailyBusinessMission {
  const DailyBusinessMission({
    required this.id,
    required this.issuedOn,
    required this.title,
    required this.description,
    required this.stage,
    required this.current,
    required this.target,
    required this.complete,
    required this.claimed,
    required this.coinReward,
    required this.capitalReward,
    required this.reputationReward,
    required this.experienceReward,
  });

  final String id;
  final String issuedOn;
  final String title;
  final String description;
  final int stage;
  final int current;
  final int target;
  final bool complete;
  final bool claimed;
  final int coinReward;
  final int capitalReward;
  final int reputationReward;
  final int experienceReward;

  factory DailyBusinessMission.fromJson(Json json) {
    final reward = (json['reward'] as Map? ?? const {}).cast<String, dynamic>();
    return DailyBusinessMission(
      id: jsonString(json['id']),
      issuedOn: jsonString(json['issuedOn']),
      title: jsonString(json['title']),
      description: jsonString(json['description']),
      stage: jsonInt(json['stage'], 1),
      current: jsonInt(json['current']),
      target: jsonInt(json['target'], 1),
      complete: jsonBool(json['complete']),
      claimed: jsonBool(json['claimed']),
      coinReward: jsonInt(reward['coins']),
      capitalReward: jsonInt(reward['capital']),
      reputationReward: jsonInt(reward['reputation']),
      experienceReward: jsonInt(reward['experience']),
    );
  }
}

class BusinessBuildingOption {
  const BusinessBuildingOption({
    required this.type,
    required this.title,
    required this.cost,
    required this.stage,
    required this.capacity,
    required this.unlocked,
    required this.affordable,
    required this.count,
  });

  final String type;
  final String title;
  final int cost;
  final int stage;
  final int capacity;
  final bool unlocked;
  final bool affordable;
  final int count;

  factory BusinessBuildingOption.fromJson(Json json) => BusinessBuildingOption(
    type: jsonString(json['type']),
    title: jsonString(json['title']),
    cost: jsonInt(json['cost']),
    stage: jsonInt(json['stage']),
    capacity: jsonInt(json['capacity']),
    unlocked: jsonBool(json['unlocked']),
    affordable: jsonBool(json['affordable']),
    count: jsonInt(json['count']),
  );
}

class BusinessMarket {
  const BusinessMarket({
    required this.id,
    required this.name,
    required this.shippingCost,
    required this.revenue,
    required this.unlocked,
  });

  final String id;
  final String name;
  final int shippingCost;
  final int revenue;
  final bool unlocked;

  factory BusinessMarket.fromJson(Json json) => BusinessMarket(
    id: jsonString(json['id']),
    name: jsonString(json['name']),
    shippingCost: jsonInt(json['shippingCost']),
    revenue: jsonInt(json['revenue']),
    unlocked: jsonBool(json['unlocked']),
  );
}

class BusinessContract {
  const BusinessContract({
    required this.id,
    required this.title,
    required this.status,
    required this.projectedRevenue,
    required this.availableAt,
  });

  final String id;
  final String title;
  final String status;
  final int projectedRevenue;
  final DateTime? availableAt;

  factory BusinessContract.fromJson(Json json) => BusinessContract(
    id: jsonString(json['contractId']),
    title: jsonString(json['title']),
    status: jsonString(json['status']),
    projectedRevenue: jsonInt(json['projectedRevenue']),
    availableAt: DateTime.tryParse(jsonString(json['availableAt'])),
  );
}

class BusinessInvestment {
  const BusinessInvestment({
    required this.id,
    required this.title,
    required this.amount,
    required this.returnAmount,
    required this.status,
    required this.availableAt,
  });

  final String id;
  final String title;
  final int amount;
  final int returnAmount;
  final String status;
  final DateTime? availableAt;

  factory BusinessInvestment.fromJson(Json json) => BusinessInvestment(
    id: jsonString(json['investmentId']),
    title: jsonString(json['title']),
    amount: jsonInt(json['amount']),
    returnAmount: jsonInt(json['returnAmount']),
    status: jsonString(json['status']),
    availableAt: DateTime.tryParse(jsonString(json['availableAt'])),
  );
}

class BusinessProgress {
  const BusinessProgress({
    required this.businessName,
    required this.businessStage,
    required this.businessLevel,
    required this.coins,
    required this.coinRewardPerWin,
    required this.capital,
    required this.reputation,
    required this.experience,
    required this.experienceForNextLevel,
    required this.stageName,
    required this.stageIcon,
    required this.isFinalStage,
    required this.nextStageName,
    required this.nextStageIcon,
    required this.nextStageCost,
    required this.canUpgrade,
    required this.requirements,
    required this.features,
    required this.capacities,
    required this.revenue,
    required this.expenses,
    required this.profit,
    required this.totalAssets,
    required this.netWorth,
    required this.dashboard,
    required this.missions,
    required this.dailyMissions,
    required this.buildingOptions,
    required this.rawMaterials,
    required this.producedGoods,
    required this.productionBatch,
    required this.materialUnitPrice,
    required this.materialBatchCost,
    required this.productionAvailable,
    required this.markets,
    required this.contracts,
    required this.investments,
  });

  final String businessName;
  final int businessStage;
  final int businessLevel;
  final int coins;
  final int coinRewardPerWin;
  final int capital;
  final int reputation;
  final int experience;
  final int experienceForNextLevel;
  final String stageName;
  final String stageIcon;
  final bool isFinalStage;
  final String nextStageName;
  final String nextStageIcon;
  final int nextStageCost;
  final bool canUpgrade;
  final List<BusinessRequirement> requirements;
  final List<BusinessFeature> features;
  final Json capacities;
  final int revenue;
  final int expenses;
  final int profit;
  final int totalAssets;
  final int netWorth;
  final Json dashboard;
  final List<BusinessMission> missions;
  final List<DailyBusinessMission> dailyMissions;
  final List<BusinessBuildingOption> buildingOptions;
  final int rawMaterials;
  final int producedGoods;
  final int productionBatch;
  final int materialUnitPrice;
  final int materialBatchCost;
  final bool productionAvailable;
  final List<BusinessMarket> markets;
  final List<BusinessContract> contracts;
  final List<BusinessInvestment> investments;

  factory BusinessProgress.fromJson(Json json) {
    final stage = (json['stage'] as Map? ?? const {}).cast<String, dynamic>();
    final next = (json['nextStage'] as Map? ?? const {})
        .cast<String, dynamic>();
    final financial = (json['financial'] as Map? ?? const {})
        .cast<String, dynamic>();
    final production = (json['production'] as Map? ?? const {})
        .cast<String, dynamic>();
    return BusinessProgress(
      businessName: jsonString(json['businessName'], 'کسب‌وکار من'),
      businessStage: jsonInt(json['businessStage'], 1),
      businessLevel: jsonInt(json['businessLevel'], 1),
      coins: jsonInt(json['coins']),
      coinRewardPerWin: jsonInt(json['coinRewardPerWin'], 100),
      capital: jsonInt(json['capital']),
      reputation: jsonInt(json['reputation']),
      experience: jsonInt(json['experience']),
      experienceForNextLevel: jsonInt(json['experienceForNextLevel'], 500),
      stageName: jsonString(stage['name'], 'مغازه کوچک'),
      stageIcon: jsonString(stage['icon'], 'storefront'),
      isFinalStage: jsonBool(json['isFinalStage']),
      nextStageName: jsonString(next['name']),
      nextStageIcon: jsonString(next['icon']),
      nextStageCost: jsonInt(next['upgradeCost']),
      canUpgrade: jsonBool(next['canUpgrade']),
      requirements: jsonMaps(next['requirements'])
          .map(BusinessRequirement.fromJson)
          .toList(),
      features: jsonMaps(json['unlockedFeatures'])
          .map(BusinessFeature.fromJson)
          .toList(),
      capacities: (json['capacities'] as Map? ?? const {})
          .cast<String, dynamic>(),
      revenue: jsonInt(financial['revenue']),
      expenses: jsonInt(financial['expenses']),
      profit: jsonInt(financial['profit']),
      totalAssets: jsonInt(financial['totalAssets']),
      netWorth: jsonInt(financial['netWorth']),
      dashboard: (json['dashboard'] as Map? ?? const {})
          .cast<String, dynamic>(),
      missions: jsonMaps(json['missions'])
          .map(BusinessMission.fromJson)
          .toList(),
      dailyMissions: jsonMaps(json['dailyMissions'])
          .map(DailyBusinessMission.fromJson)
          .toList(),
      buildingOptions: jsonMaps(json['buildingOptions'])
          .map(BusinessBuildingOption.fromJson)
          .toList(),
      rawMaterials: jsonInt(production['rawMaterials']),
      producedGoods: jsonInt(production['producedGoods']),
      productionBatch: jsonInt(production['batchSize']),
      materialUnitPrice: jsonInt(production['materialUnitPrice']),
      materialBatchCost: jsonInt(production['materialBatchCost']),
      productionAvailable: jsonBool(production['available']),
      markets: jsonMaps(json['markets']).map(BusinessMarket.fromJson).toList(),
      contracts: jsonMaps(json['contracts'])
          .map(BusinessContract.fromJson)
          .toList(),
      investments: jsonMaps(json['investments'])
          .map(BusinessInvestment.fromJson)
          .toList(),
    );
  }
}

class BusinessActionResult {
  const BusinessActionResult(this.business, this.message);

  final BusinessProgress business;
  final String message;
}

class GameSnapshot {
  const GameSnapshot({
    required this.match,
    required this.players,
    required this.cards,
    required this.events,
    required this.trades,
    required this.business,
  });

  final MatchInfo match;
  final List<MatchPlayer> players;
  final List<TradeCard> cards;
  final List<Json> events;
  final List<PendingTrade> trades;
  final BusinessProgress business;

  MatchPlayer? player(String userId) {
    for (final item in players) {
      if (item.uid == userId) return item;
    }
    return null;
  }
}
