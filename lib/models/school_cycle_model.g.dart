// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'school_cycle_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SchoolCycleAdapter extends TypeAdapter<SchoolCycle> {
  @override
  final int typeId = 4;

  @override
  SchoolCycle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SchoolCycle(
      id: fields[0] as String,
      type: fields[1] as String,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SchoolCycle obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolCycleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
