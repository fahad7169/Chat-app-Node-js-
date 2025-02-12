import 'package:chat_app/features/conversations/domain/entitites/conversation_entity.dart';

class ConversationModel extends ConversationEntity{
  ConversationModel({required String id, required String participantName, required String lastMessage, required String lastMessageTime}):super(
    id: id,
    participantName: participantName,
    lastMessage: lastMessage,
    lastMessageTime: lastMessageTime
  );

  factory ConversationModel.fromJson(Map<String,dynamic> json){
    return ConversationModel(
      id: json['id'],
      participantName: json['participantName'],
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime']
    );
  }
  
}