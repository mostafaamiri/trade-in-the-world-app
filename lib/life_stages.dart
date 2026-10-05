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
    required this.groupName,
    required this.title,
    required this.message,
    this.createdAt,
  });

  final int stageIndex;
  final String type;
  final String actorName;
  final String groupName;
  final String title;
  final String message;
  final DateTime? createdAt;

  factory LifeStagesEvent.fromJson(Json json) => LifeStagesEvent(
    stageIndex: jsonInt(json['stageIndex']),
    type: jsonString(json['type']),
    actorName: jsonString(json['actorName']),
    groupName: jsonString(json['groupName']),
    title: jsonString(json['title']),
    message: jsonString(json['message']),
    createdAt: DateTime.tryParse(jsonString(json['createdAt'])),
  );
}

class LifeStagesGroup {
  const LifeStagesGroup({
    required this.groupId,
    required this.name,
    required this.ownerId,
    required this.points,
    required this.maxPlayers,
    required this.playerCount,
    required this.isMember,
    required this.isOwner,
    required this.isComplete,
    required this.players,
  });

  final String groupId;
  final String name;
  final String ownerId;
  final int points;
  final int maxPlayers;
  final int playerCount;
  final bool isMember;
  final bool isOwner;
  final bool isComplete;
  final List<LifeStagesPlayer> players;

  LifeStagesPlayer? get me {
    for (final player in players) {
      if (player.isMe) return player;
    }
    return null;
  }

  factory LifeStagesGroup.fromJson(Json json) => LifeStagesGroup(
    groupId: jsonString(json['groupId']),
    name: jsonString(json['name']),
    ownerId: jsonString(json['ownerId']),
    points: jsonInt(json['points']),
    maxPlayers: jsonInt(json['maxPlayers'], 3),
    playerCount: jsonInt(json['playerCount']),
    isMember: jsonBool(json['isMember']),
    isOwner: jsonBool(json['isOwner']),
    isComplete: jsonBool(json['isComplete']),
    players: jsonMaps(json['players']).map(LifeStagesPlayer.fromJson).toList(),
  );
}

class LifeStagesRoom {
  const LifeStagesRoom({
    required this.roomId,
    required this.name,
    required this.roomCode,
    required this.ownerId,
    required this.status,
    required this.minGroups,
    required this.maxGroups,
    required this.playersPerGroup,
    required this.groupCount,
    required this.playerCount,
    required this.currentStageIndex,
    required this.currentStage,
    required this.stages,
    required this.roles,
    required this.canStart,
    required this.isOwner,
    required this.myGroupId,
    required this.groups,
    required this.events,
  });

  final String roomId;
  final String name;
  final String roomCode;
  final String ownerId;
  final String status;
  final int minGroups;
  final int maxGroups;
  final int playersPerGroup;
  final int groupCount;
  final int playerCount;
  final int currentStageIndex;
  final LifeStage currentStage;
  final List<LifeStage> stages;
  final List<LifeStagesRole> roles;
  final bool canStart;
  final bool isOwner;
  final String myGroupId;
  final List<LifeStagesGroup> groups;
  final List<LifeStagesEvent> events;

  LifeStagesGroup? get myGroup {
    for (final group in groups) {
      if (group.groupId == myGroupId || group.isMember) return group;
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
      minGroups: jsonInt(json['minGroups'], 2),
      maxGroups: jsonInt(json['maxGroups'], 4),
      playersPerGroup: jsonInt(json['playersPerGroup'], 3),
      groupCount: jsonInt(json['groupCount']),
      playerCount: jsonInt(json['playerCount']),
      currentStageIndex: jsonInt(json['currentStageIndex']),
      currentStage: LifeStage.fromJson(stageValue),
      stages: jsonMaps(json['stages']).map(LifeStage.fromJson).toList(),
      roles: jsonMaps(json['roles']).map(LifeStagesRole.fromJson).toList(),
      canStart: jsonBool(json['canStart']),
      isOwner: jsonBool(json['isOwner']),
      myGroupId: jsonString(json['myGroupId']),
      groups: jsonMaps(json['groups']).map(LifeStagesGroup.fromJson).toList(),
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
