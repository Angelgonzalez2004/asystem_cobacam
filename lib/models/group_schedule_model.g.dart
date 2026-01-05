// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_schedule_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GroupScheduleAdapter extends TypeAdapter<GroupSchedule> {
  @override
  final int typeId = 2;

  @override
  GroupSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GroupSchedule(
      id: fields[0] as String,
      groupId: fields[1] as String,
      schoolCycle: fields[2] as String,
      dayOfWeek: fields[3] as String,
      entryTime: fields[4] as String,
      exitTime: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GroupSchedule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.groupId)
      ..writeByte(2)
      ..write(obj.schoolCycle)
      ..writeByte(3)
      ..write(obj.dayOfWeek)
      ..writeByte(4)
      ..write(obj.entryTime)
      ..writeByte(5)
      ..write(obj.exitTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
