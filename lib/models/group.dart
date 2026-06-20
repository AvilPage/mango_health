import 'package:pocketbase/pocketbase.dart';

class Group {
  final String id;
  final String name;
  final String inviteCode;

  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
  });

  factory Group.fromRecord(RecordModel record) {
    return Group(
      id: record.id,
      name: record.getStringValue('name'),
      inviteCode: record.getStringValue('invite_code'),
    );
  }
}

class GroupMember {
  final String userId;
  final String name;
  final String email;
  final int steps;
  final int rewardPoints;

  const GroupMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.steps,
    required this.rewardPoints,
  });
}
