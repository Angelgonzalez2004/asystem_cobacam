// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incidence_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IncidenceAdapter extends TypeAdapter<Incidence> {
  @override
  final int typeId = 6;

  @override
  Incidence read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Incidence(
      id: fields[0] as String,
      studentId: fields[1] as String,
      studentName: fields[2] as String,
      group: fields[3] as String,
      type: fields[4] as String,
      description: fields[5] as String,
      date: fields[6] as DateTime,
      campusId: fields[7] as String,
      isSynced: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Incidence obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.studentId)
      ..writeByte(2)
      ..write(obj.studentName)
      ..writeByte(3)
      ..write(obj.group)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.campusId)
      ..writeByte(8)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncidenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
