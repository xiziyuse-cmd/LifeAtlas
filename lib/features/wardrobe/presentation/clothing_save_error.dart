import 'dart:io';

import 'package:sqflite/sqflite.dart';

/// Converts persistence failures into short messages that are safe to show.
String clothingSaveErrorMessage(Object error) {
  if (error is ArgumentError) {
    return _cleanMessage(error.message) ?? '衣服信息有误，请检查后重试';
  }
  if (error is StateError) {
    return _cleanMessage(error.message) ?? '衣服状态异常，请重新打开后重试';
  }
  if (error is FormatException) {
    final detail = _cleanMessage(error.message);
    return detail == null ? '衣服数据格式有误，请检查后重试' : '数据格式错误：$detail';
  }
  if (error is SocketException) {
    return '网络连接失败，请检查网络后重试';
  }
  if (error is HttpException) {
    return '服务请求失败，请稍后重试';
  }
  if (error is FileSystemException) {
    return '本地存储失败，请检查存储空间后重试';
  }
  if (error is DatabaseException) {
    return '本地数据库保存失败，请检查存储空间后重试';
  }
  return '保存失败，请稍后重试';
}

String? _cleanMessage(Object? message) {
  final value = message?.toString().trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  return value.endsWith('.') || value.endsWith('。')
      ? value.substring(0, value.length - 1)
      : value;
}
