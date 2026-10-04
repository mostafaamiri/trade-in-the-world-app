import 'models.dart';

class LifeStage {
  const LifeStage({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;

  factory LifeStage.fromJson(Json json) => LifeStage(
    id: jsonString(json['id']),
    title: jsonString(json['title']),
    description: jsonString(json['description']),
  );
}

class LifeStagesPower {
  const LifeStagesPower({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;

  factory LifeStagesPower.fromJson(Json json) => LifeStagesPower(
    id: jsonString(json['id']),
    title: jsonString(json['title']),
    description: jsonString(json['description']),
  );
}

class LifeStagesRole {
  const LifeStagesRole({
    required this.id,
    required this.title,
    required this.icon,
    required this.powers,
  });

  final String id;
  final String title;
  final String icon;
  final List<LifeStagesPower> powers;

  factory LifeStagesRole.fromJson(Json json) => LifeStagesRole(
    id: jsonString(json['id']),
    title: jsonString(json['title']),
    icon: jsonString(json['icon']),
    powers: jsonMaps(json['powers']).map(LifeStagesPower.fromJson).toList(),
  );
}

class LifeStagesPlayer {
  const LifeStagesPlayer({
    required this.userId,
    required this.displayName,
    required this.avatarId,
    required this.roleId,
    required this.role,
    required this.usedPowerIds,
    required this.isMe,
  });

  final String userId;
  final String displayName;
  final String avatarId;
  final String? roleId;
  final LifeStagesRole? role;
  final List<String> usedPowerIds;
  final bool isMe;

  factory LifeStagesPlayer.fromJson(Json json) => LifeStagesPlayer(
    userId: jsonString(json['userId']),
    displayName: jsonString(json['displayName'], 'بازیکن'),
    avatarId: jsonString(json['avatarId'], 'merchant_purple'),
    roleId: json['roleId']?.toString(),
    role: json['role'] is Map
        ? LifeStagesRole.fromJson((json['role'] as Map).cast<String, dynamic>())
        : null,
    usedPowerIds: (json['usedPowerIds'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(),
    isMe: jsonBool(json['isMe']),
  );
}

class LifeStagesEvent {
  const LifeStagesEvent({
    required this.stageIndex,
    required this.type,
    required this.actorName,
    required this.title,
    required this.message,
    this.createdAt,
  });

  final int stageIndex;
  final String type;
  final String actorName;
  final String title;
  final String message;
  final DateTime? createdAt;

  factory LifeStagesEvent.fromJson(Json json) => LifeStagesEvent(
    stageIndex: jsonInt(json['stageIndex']),
    type: jsonString(json['type']),
    actorName: jsonString(json['actorName']),
    title: jsonString(json['title']),
    message: jsonString(json['message']),
    createdAt: DateTime.tryParse(jsonString(json['createdAt'])),
  );
}

class LifeStagesRoom {
  const LifeStagesRoom({
    required this.roomId,
    required this.name,
    required this.roomCode,
    required this.ownerId,
    required this.status,
    required this.maxPlayers,
    required this.playerCount,
    required this.currentStageIndex,
    required this.currentStage,
    required this.stages,
    required this.roles,
    required this.teamPoints,
    required this.canStart,
    required this.isOwner,
    required this.players,
    required this.events,
  });

  final String roomId;
  final String name;
  final String roomCode;
  final String ownerId;
  final String status;
  final int maxPlayers;
  final int playerCount;
  final int currentStageIndex;
  final LifeStage currentStage;
  final List<LifeStage> stages;
  final List<LifeStagesRole> roles;
  final int teamPoints;
  final bool canStart;
  final bool isOwner;
  final List<LifeStagesPlayer> players;
  final List<LifeStagesEvent> events;

  LifeStagesPlayer? get me {
    for (final player in players) {
      if (player.isMe) return player;
    }
    return null;
  }

  factory LifeStagesRoom.fromJson(Json json) {
    final stageValue = (json['currentStage'] as Map? ?? const {})
        .cast<String, dynamic>();
    return LifeStagesRoom(
      roomId: jsonString(json['roomId']),
      name: jsonString(json['name']),
      roomCode: jsonString(json['roomCode']),
      ownerId: jsonString(json['ownerId']),
      status: jsonString(json['status']),
      maxPlayers: jsonInt(json['maxPlayers'], 5),
      playerCount: jsonInt(json['playerCount']),
      currentStageIndex: jsonInt(json['currentStageIndex']),
      currentStage: LifeStage.fromJson(stageValue),
      stages: jsonMaps(json['stages']).map(LifeStage.fromJson).toList(),
      roles: jsonMaps(json['roles']).map(LifeStagesRole.fromJson).toList(),
      teamPoints: jsonInt(json['teamPoints']),
      canStart: jsonBool(json['canStart']),
      isOwner: jsonBool(json['isOwner']),
      players: jsonMaps(json['players'])
          .map(LifeStagesPlayer.fromJson)
          .toList(),
      events: jsonMaps(json['events']).map(LifeStagesEvent.fromJson).toList(),
    );
  }
}

String lifeStagesStatusTitle(String status) {
  switch (status) {
    case 'lobby':
      return 'در انتظار گروه';
    case 'active':
      return 'در حال برگزاری';
    case 'completed':
      return 'پایان‌یافته';
    default:
      return 'بسته';
  }
}
