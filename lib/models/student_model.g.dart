// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentAdapter extends TypeAdapter<Student> {
  @override
  final int typeId = 0;

  @override
  Student read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Student(
      id: fields[0] as String,
      fullName: fields[1] as String,
      guardianFullName: fields[2] as String,
      age: fields[3] as int,
      guardianPhone: fields[4] as String,
      studentPhone: fields[5] as String?,
      gender: fields[6] as String,
      placeOfResidence: fields[7] as String,
      schoolCycle: fields[8] as String,
      group: fields[9] as String,
      institutionalEmail: fields[10] as String,
      studentId: fields[11] as String,
      isActive: fields[12] as bool,
      deactivationReason: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.guardianFullName)
      ..writeByte(3)
      ..write(obj.age)
      ..writeByte(4)
      ..write(obj.guardianPhone)
      ..writeByte(5)
      ..write(obj.studentPhone)
      ..writeByte(6)
      ..write(obj.gender)
      ..writeByte(7)
      ..write(obj.placeOfResidence)
      ..writeByte(8)
      ..write(obj.schoolCycle)
      ..writeByte(9)
      ..write(obj.group)
      ..writeByte(10)
      ..write(obj.institutionalEmail)
      ..writeByte(11)
      ..write(obj.studentId)
      ..writeByte(12)
      ..write(obj.isActive)
      ..writeByte(13)
      ..write(obj.deactivationReason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
