// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceRecordAdapter extends TypeAdapter<AttendanceRecord> {
  @override
  final int typeId = 5;

  @override
  AttendanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceRecord(
      studentId: fields[0] as String,
      studentFullName: fields[1] as String,
      group: fields[2] as String,
      date: fields[3] as String,
      entryTime: fields[4] as String?,
      exitTime: fields[5] as String?,
      status: fields[6] as String?,
      reasonTardy: fields[7] as String?,
      reasonEarlyExit: fields[8] as String?,
      isSynced: fields[9] as bool,
      campusId: fields[10] as String,
      schoolCycle: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceRecord obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.studentId)
      ..writeByte(1)
      ..write(obj.studentFullName)
      ..writeByte(2)
      ..write(obj.group)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.entryTime)
      ..writeByte(5)
      ..write(obj.exitTime)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.reasonTardy)
      ..writeByte(8)
      ..write(obj.reasonEarlyExit)
      ..writeByte(9)
      ..write(obj.isSynced)
      ..writeByte(10)
      ..write(obj.campusId)
      ..writeByte(11)
      ..write(obj.schoolCycle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
