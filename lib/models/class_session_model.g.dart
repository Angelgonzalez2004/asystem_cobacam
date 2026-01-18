// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClassSessionAdapter extends TypeAdapter<ClassSession> {
  @override
  final int typeId = 12;

  @override
  ClassSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassSession(
      startTime: fields[0] as String,
      endTime: fields[1] as String,
      subjectId: fields[2] as String?,
      teacherId: fields[3] as String?,
      subjectName: fields[4] as String,
      teacherName: fields[5] as String?,
      groupName: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ClassSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.startTime)
      ..writeByte(1)
      ..write(obj.endTime)
      ..writeByte(2)
      ..write(obj.subjectId)
      ..writeByte(3)
      ..write(obj.teacherId)
      ..writeByte(4)
      ..write(obj.subjectName)
      ..writeByte(5)
      ..write(obj.teacherName)
      ..writeByte(6)
      ..write(obj.groupName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
