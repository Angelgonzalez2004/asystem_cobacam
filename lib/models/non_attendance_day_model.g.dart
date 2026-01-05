// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'non_attendance_day_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NonAttendanceDayAdapter extends TypeAdapter<NonAttendanceDay> {
  @override
  final int typeId = 3;

  @override
  NonAttendanceDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NonAttendanceDay(
      id: fields[0] as String,
      campusId: fields[1] as String,
      date: fields[2] as DateTime,
      reason: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NonAttendanceDay obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.campusId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.reason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NonAttendanceDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
