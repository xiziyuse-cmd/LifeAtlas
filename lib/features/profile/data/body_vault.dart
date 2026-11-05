import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/mobile_api.dart';

const bodyFields = <String, List<String>>{
  '基础信息': ['身高', '体重'],
  '上身尺寸': ['肩宽', '胸围', '腰围', '臂长', '上身长度'],
  '下身尺寸': ['臀围', '大腿围', '小腿围', '腿内长', '腿外长'],
};
final numericBodyFields = bodyFields.values.expand((v) => v).toSet();
String bodyUnit(String field) => field == '体重'
    ? 'kg'
    : numericBodyFields.contains(field)
    ? 'cm'
    : '';
const measurementHelp = {
  '身高': '脱鞋站直，从头顶至地面。',
  '体重': '使用同一台秤、相近条件记录。',
  '肩宽': '沿背部测量左右肩端之间距离；与衣服肩缝宽度区分。',
  '胸围': '软尺水平绕胸部最丰满处一周，不勒紧；记录整圈而非平铺宽度。',
  '腰围': '软尺水平绕自然腰部一周，不收腹；不是衣服的松紧腰范围。',
  '臂长': '肩端至手腕的身体长度；与衣服袖长口径不完全相同。',
  '上身长度': '肩颈交点至自然腰线，沿身体表面测量。',
  '臀围': '水平绕臀部最丰满处一周。',
  '大腿围': '水平绕大腿最粗处一周。',
  '小腿围': '水平绕小腿最粗处一周。',
  '腿内长': '裆部至脚踝沿腿内侧测量。',
  '腿外长': '自然腰线至脚踝沿腿外侧测量；不等同成衣裤长。',
};

class BodyRecord {
  BodyRecord({
    required this.id,
    required this.date,
    required Map<String, String> values,
    this.note = '',
    this.inherited = const [],
  }) : values = Map.unmodifiable(values);
  final String id, date, note;
  final Map<String, String> values;
  final List<String> inherited;
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'values': values,
    'note': note,
    'inherited': inherited,
  };
  factory BodyRecord.fromJson(Map<String, dynamic> v) => BodyRecord(
    id: v['id'],
    date: v['date'],
    values: Map<String, String>.from(v['values']),
    note: v['note'] ?? '',
    inherited: List<String>.from(v['inherited'] ?? []),
  );
  void validate() {
    final d = DateTime.tryParse(date);
    final today = DateTime.now();
    if (d == null ||
        date !=
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' ||
        d.isAfter(DateTime(today.year, today.month, today.day))) {
      throw const FormatException('请选择有效且不晚于今天的记录日期');
    }
    if (values.isEmpty) throw const FormatException('请至少填写一项身材数据');
    for (final e in values.entries) {
      if (e.value.length > 200) throw const FormatException('单项内容过长');
      if (numericBodyFields.contains(e.key)) {
        final n = double.tryParse(e.value);
        if (n == null || !n.isFinite || n <= 0 || n > 1000) {
          throw FormatException('${e.key}请填写0至1000之间的正数，单位${bodyUnit(e.key)}');
        }
      }
    }
    if (note.length > 2000) throw const FormatException('备注最多2000字');
  }
}

/// Records use an authenticated data key wrapped by the local password.
/// Legacy envelopes are migrated only after password authentication succeeds.
class BodyVault {
  BodyVault({MobileApi? api}) : api = api ?? MobileApi.shared;
  final MobileApi api;
  final cipher = AesGcm.with256bits();
  SecretKey? _key;
  Map<String, dynamic>? _envelope;
  int _epoch = 0, failures = 0;
  DateTime? blockedUntil;
  List<BodyRecord> _records = [];
  bool get unlocked => _key != null;
  List<BodyRecord> get records =>
      unlocked ? List.unmodifiable(_records) : const [];
  Future<bool> configured() async => await api.setting('body_vault_v1') != null;
  List<int> random(int n) {
    final r = Random.secure();
    return List.generate(n, (_) => r.nextInt(256));
  }

  Future<SecretKey> _derive(String text, List<int> salt) async =>
      SecretKey(await compute(_deriveBodyKey, {'text': text, 'salt': salt}));
  Future<String> _seal(List<int> bytes, SecretKey key) async => base64Encode(
    (await cipher.encrypt(bytes, secretKey: key)).concatenation(),
  );
  Future<List<int>> _open(String text, SecretKey key) => cipher.decrypt(
    SecretBox.fromConcatenation(
      base64Decode(text),
      nonceLength: 12,
      macLength: 16,
    ),
    secretKey: key,
  );
  void _password(String password) {
    if (password.length < 8 || password.length > 128) {
      throw const FormatException('密码须为8至128位');
    }
  }

  Future<void> create(String password) async {
    _password(password);
    if (await configured()) throw StateError('档案已设密码，请先解锁');
    final epoch = _epoch;
    final key = await cipher.newSecretKey();
    final salt = random(16);
    final env = <String, dynamic>{
      'version': 2,
      'salt': base64Encode(salt),
      'password': await _seal(
        await key.extractBytes(),
        await _derive(password, salt),
      ),
      'records': await _seal(utf8.encode('[]'), key),
    };
    await api.saveSetting('body_vault_v1', env);
    if (epoch == _epoch) {
      _key = key;
      _envelope = env;
      _records = [];
    }
  }

  void lock() {
    _epoch++;
    _key = null;
    _envelope = null;
    _records = [];
  }

  Future<void> unlock(String password) async {
    if (blockedUntil?.isAfter(DateTime.now()) == true) {
      throw StateError('尝试过多，请30秒后重试');
    }
    final epoch = _epoch;
    try {
      final env = Map<String, dynamic>.from(
        await api.setting('body_vault_v1') as Map,
      );
      if (env['version'] != 1 && env['version'] != 2) {
        throw const FormatException('档案版本不支持');
      }
      final wrapping = await _derive(password, base64Decode(env['salt']));
      final key = SecretKey(await _open(env['password'], wrapping));
      final rows =
          (jsonDecode(utf8.decode(await _open(env['records'], key))) as List)
              .map((v) => BodyRecord.fromJson(Map<String, dynamic>.from(v)))
              .toList();
      if (epoch != _epoch) throw StateError('请重新解锁');
      if (env['version'] == 1 || env.containsKey('recovery')) {
        env.remove('recovery');
        env['version'] = 2;
        await api.saveSetting('body_vault_v1', env);
        if (epoch != _epoch) throw StateError('请重新解锁');
      }
      _key = key;
      _envelope = env;
      _records = rows;
      failures = 0;
    } catch (_) {
      failures++;
      if (failures >= 5) {
        blockedUntil = DateTime.now().add(const Duration(seconds: 30));
        failures = 0;
      }
      throw StateError('密码不正确或档案暂时无法读取');
    }
  }

  Future<void> changePassword(String password) async {
    _password(password);
    final key = _key;
    if (key == null) throw StateError('请先解锁');
    final epoch = _epoch;
    final salt = random(16);
    final env = {
      ..._envelope!,
      'salt': base64Encode(salt),
      'password': await _seal(
        await key.extractBytes(),
        await _derive(password, salt),
      ),
    };
    if (epoch != _epoch) throw StateError('已锁定，请重试');
    await api.saveSetting('body_vault_v1', env);
    if (epoch == _epoch) _envelope = env;
  }

  Future<void> save(BodyRecord record) async {
    record.validate();
    await _write([..._records.where((r) => r.id != record.id), record]);
  }

  Future<void> delete(String id) =>
      _write(_records.where((r) => r.id != id).toList());
  Future<void> _write(List<BodyRecord> rows) async {
    final key = _key;
    if (key == null) throw StateError('请先解锁');
    final epoch = _epoch;
    rows.sort((a, b) => b.date.compareTo(a.date));
    final env = {
      ..._envelope!,
      'records': await _seal(
        utf8.encode(jsonEncode(rows.map((r) => r.toJson()).toList())),
        key,
      ),
    };
    if (epoch != _epoch) throw StateError('已锁定，请重试');
    await api.saveSetting('body_vault_v1', env);
    if (epoch == _epoch) {
      _records = rows;
      _envelope = env;
    }
  }
}

Future<List<int>> _deriveBodyKey(Map<String, Object> input) async {
  final key =
      await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 210000,
        bits: 256,
      ).deriveKey(
        secretKey: SecretKey(utf8.encode(input['text'] as String)),
        nonce: input['salt'] as List<int>,
      );
  return key.extractBytes();
}
