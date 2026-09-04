import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'form_configuration.dart';

class PasswordVerificationResult {
  const PasswordVerificationResult({
    required this.success,
    this.remainingAttempts = 0,
    this.lockedUntil,
  });

  final bool success;
  final int remainingAttempts;
  final DateTime? lockedUntil;

  bool get locked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now().toUtc());
}

class IntakeSettingsStore {
  IntakeSettingsStore({Directory? directory, int iterations = 120000})
    : _directoryOverride = directory,
      _iterations = iterations;

  static const _fileName = 'patient_intake_settings_v1.json';
  static const _maximumFailures = 5;
  static const _lockDuration = Duration(seconds: 30);

  final Directory? _directoryOverride;
  final int _iterations;
  Map<String, dynamic> _password = const {};
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  IntakeFormConfiguration configuration = IntakeFormConfiguration.defaults();

  bool get hasPassword =>
      _password['salt'] is String && _password['verifier'] is String;

  Future<Directory> get _supportDirectory async {
    final directory =
        _directoryOverride ?? await getApplicationSupportDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> get _file async => File(
    '${(await _supportDirectory).path}${Platform.pathSeparator}$_fileName',
  );

  Future<String> importCustomLogo(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('The selected logo could not be read.');
    }
    final length = await source.length();
    if (length == 0 || length > 12 * 1024 * 1024) {
      throw const FormatException('Choose a logo smaller than 12 MB.');
    }
    final directory = await _supportDirectory;
    final destination = File(
      '${directory.path}${Platform.pathSeparator}practice_logo_custom',
    );
    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      if (json['configuration'] is Map) {
        configuration = IntakeFormConfiguration.fromJson(
          Map<String, dynamic>.from(json['configuration'] as Map),
        );
      }
      if (json['password'] is Map) {
        _password = Map<String, dynamic>.from(json['password'] as Map);
      }
      _failedAttempts =
          int.tryParse(json['failed_attempts']?.toString() ?? '') ?? 0;
      _lockedUntil = DateTime.tryParse(
        json['locked_until']?.toString() ?? '',
      )?.toUtc();
    } catch (_) {
      // A corrupt local preference file must not prevent the intake form
      // opening. The safe defaults remain active.
      configuration = IntakeFormConfiguration.defaults();
      _password = const {};
      _failedAttempts = 0;
      _lockedUntil = null;
    }
  }

  Future<void> setInitialPassword(String password) async {
    if (hasPassword) throw StateError('A settings password already exists.');
    _validateNewPassword(password);
    await _replacePassword(password);
  }

  Future<void> changePassword(String password) async {
    if (!hasPassword) throw StateError('No settings password exists.');
    _validateNewPassword(password);
    await _replacePassword(password);
  }

  Future<PasswordVerificationResult> verifyPassword(String password) async {
    final now = DateTime.now().toUtc();
    if (_lockedUntil != null && _lockedUntil!.isAfter(now)) {
      return PasswordVerificationResult(
        success: false,
        lockedUntil: _lockedUntil,
      );
    }
    if (!hasPassword) {
      return const PasswordVerificationResult(success: false);
    }

    final salt = base64Decode(_password['salt'] as String);
    final expected = base64Decode(_password['verifier'] as String);
    final iterations =
        int.tryParse(_password['iterations']?.toString() ?? '') ?? _iterations;
    final actual = await Isolate.run(
      () => _pbkdf2Sha256(password, salt, iterations, expected.length),
    );
    final success = _constantTimeEquals(actual, expected);
    if (success) {
      _failedAttempts = 0;
      _lockedUntil = null;
      await _save();
      return const PasswordVerificationResult(success: true);
    }

    _failedAttempts += 1;
    if (_failedAttempts >= _maximumFailures) {
      _failedAttempts = 0;
      _lockedUntil = now.add(_lockDuration);
    }
    await _save();
    return PasswordVerificationResult(
      success: false,
      remainingAttempts: _lockedUntil == null
          ? _maximumFailures - _failedAttempts
          : 0,
      lockedUntil: _lockedUntil,
    );
  }

  Future<void> saveConfiguration(IntakeFormConfiguration value) async {
    value.markChanged();
    configuration = value.copy();
    await _save();
  }

  Future<void> resetConfiguration() async {
    configuration = IntakeFormConfiguration.defaults();
    await _save();
  }

  Future<void> _replacePassword(String password) async {
    final salt = Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final verifier = await Isolate.run(
      () => _pbkdf2Sha256(password, salt, _iterations, 32),
    );
    _password = {
      'algorithm': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'verifier': base64Encode(verifier),
    };
    _failedAttempts = 0;
    _lockedUntil = null;
    await _save();
  }

  void _validateNewPassword(String password) {
    if (password.length < 8) {
      throw const FormatException('Use at least 8 characters.');
    }
  }

  Future<void> _save() async {
    final file = await _file;
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'configuration': configuration.toJson(),
        'password': _password,
        'failed_attempts': _failedAttempts,
        if (_lockedUntil != null)
          'locked_until': _lockedUntil!.toIso8601String(),
      }),
      flush: true,
    );
  }
}

Uint8List _pbkdf2Sha256(
  String password,
  List<int> salt,
  int iterations,
  int length,
) {
  final output = BytesBuilder(copy: false);
  final hmac = Hmac(sha256, utf8.encode(password));
  var block = 1;
  while (output.length < length) {
    final blockBytes = <int>[
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];
    var u = hmac.convert(blockBytes).bytes;
    final accumulator = Uint8List.fromList(u);
    for (var round = 1; round < iterations; round++) {
      u = hmac.convert(u).bytes;
      for (var index = 0; index < accumulator.length; index++) {
        accumulator[index] ^= u[index];
      }
    }
    output.add(accumulator);
    block += 1;
  }
  return Uint8List.fromList(output.takeBytes().take(length).toList());
}

bool _constantTimeEquals(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
