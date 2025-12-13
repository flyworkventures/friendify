
class AgentModel {
  final String name;
  final String creatorId;
  final String character;
  final String characterTags;
  final String photoURL;
  final int system;
  final int id;
  final String gender;
  final int age;
  final String? speakingStyle;
  final dynamic interests;
  final dynamic interestsType;
  final String? voiceId;
  final String country;
  AgentModel({
    required this.name,
    required this.creatorId,
    required this.character,
    required this.characterTags,
    required this.photoURL,
    required this.system,
    required this.id,
    required this.gender,
    required this.age,
    required this.speakingStyle,
    required this.interests,
    required this.interestsType,
    required this.voiceId,
    required this.country,
  });


  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'creatorId': creatorId,
      'character': character,
      'characterTags': characterTags,
      'photoURL': photoURL,
      'system': system,
      'id': id,
      'gender': gender,
      'age': age,
      'speakingStyle': speakingStyle,
      'interests': interests,
      'interestsType': interestsType,
      'voiceId': voiceId,
      'country': country,

    };
  }

  factory AgentModel.fromMap(Map<String, dynamic> map) {
    return AgentModel(
      id: map["id"],
      name: map['name'] as String,
      creatorId: map['creatorId'] as String,
      character: map['character'] as String,
      characterTags: map['characterTags'] as dynamic,
      photoURL: map['photoURL'] as String,
      system: map['system'] as int,
      gender: map['gender'] as String,
      age: map['age'] as int,
      speakingStyle: map['speakingStyle'],
      interests: map['interests'] as dynamic,
      interestsType: map['interestsType'] as dynamic,
      voiceId: map['voiceId'],
      country: map['country'] as String,
    );
  }
}
