// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContactEntityAdapter extends TypeAdapter<ContactEntity> {
  @override
  final int typeId = 1;

  @override
  ContactEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContactEntity(
      id: fields[6] as String,
      username: fields[7] as String,
      email: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ContactEntity obj) {
    writer
      ..writeByte(3)
      ..writeByte(6)
      ..write(obj.id)
      ..writeByte(7)
      ..write(obj.username)
      ..writeByte(8)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
