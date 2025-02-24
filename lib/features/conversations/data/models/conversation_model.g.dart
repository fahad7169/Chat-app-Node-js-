// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConversationModelAdapter extends TypeAdapter<ConversationModel> {
  @override
  final int typeId = 0;

  @override
  ConversationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationModel(
      id: fields[0] as String,
      lastMessageId: fields[1] as String,
      participantName: fields[2] as String,
      lastMessage: fields[3] as String,
      lastMessageTime: fields[4] as DateTime?,
      lastMessageStatus: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ConversationModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.lastMessageId)
      ..writeByte(2)
      ..write(obj.participantName)
      ..writeByte(3)
      ..write(obj.lastMessage)
      ..writeByte(4)
      ..write(obj.lastMessageTime)
      ..writeByte(5)
      ..write(obj.lastMessageStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
