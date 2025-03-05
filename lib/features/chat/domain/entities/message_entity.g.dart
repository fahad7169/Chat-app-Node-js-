// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageEntityAdapter extends TypeAdapter<MessageEntity> {
  @override
  final int typeId = 2;

  @override
  MessageEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MessageEntity(
      id: fields[9] as String,
      conversationId: fields[10] as String,
      senderId: fields[11] as String,
      content: fields[12] as String,
      createdAt: fields[13] as String,
      status: fields[14] as String?,
      contactId: fields[15] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MessageEntity obj) {
    writer
      ..writeByte(7)
      ..writeByte(9)
      ..write(obj.id)
      ..writeByte(10)
      ..write(obj.conversationId)
      ..writeByte(11)
      ..write(obj.senderId)
      ..writeByte(12)
      ..write(obj.content)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.status)
      ..writeByte(15)
      ..write(obj.contactId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
