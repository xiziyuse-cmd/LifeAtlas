/// The future implementation must use the signed-in account's verified phone.
/// It must restore/rewrap the archive key as well as reset the password; SMS
/// identity verification alone is never permission to discard encrypted data.
abstract interface class BodyPasswordResetService {
  Future<BodyResetChallenge> requestCode();
  Future<BodyResetAuthorization> verifyCode({
    required String requestId,
    required String code,
  });
  Future<void> resetPassword({
    required BodyResetAuthorization authorization,
    required String newPassword,
  });
}

class BodyResetChallenge {
  const BodyResetChallenge({
    required this.requestId,
    required this.maskedPhone,
    required this.resendAfterSeconds,
  });
  final String requestId, maskedPhone;
  final int resendAfterSeconds;
}

class BodyResetAuthorization {
  const BodyResetAuthorization({required this.token, required this.expiresAt});
  final String token;
  final DateTime expiresAt;
}

enum BodyResetFailure {
  unavailable,
  notSignedIn,
  phoneNotBound,
  invalidCode,
  expiredCode,
  retryLater,
  resetDenied,
  archiveUnavailable,
}

const bodyResetUnavailableMessage = '手机号找回将在账号功能上线后开放';

class BodyResetException implements Exception {
  const BodyResetException(this.reason, {this.retryAfterSeconds});
  final BodyResetFailure reason;
  final int? retryAfterSeconds;
  String get message => switch (reason) {
    BodyResetFailure.unavailable => bodyResetUnavailableMessage,
    BodyResetFailure.notSignedIn => '请先登录个人账号',
    BodyResetFailure.phoneNotBound => '账号尚未绑定手机号',
    BodyResetFailure.invalidCode => '验证码不正确',
    BodyResetFailure.expiredCode => '验证码已过期',
    BodyResetFailure.retryLater => '请稍后重新获取验证码',
    BodyResetFailure.resetDenied => '重置授权无效，请重新验证',
    BodyResetFailure.archiveUnavailable => '档案暂时无法恢复，请重试',
  };
  @override
  String toString() => message;
}

/// Explicitly unavailable: no SMS, fabricated challenge or local bypass.
class UnconfiguredBodyPasswordReset implements BodyPasswordResetService {
  const UnconfiguredBodyPasswordReset();
  @override
  Future<BodyResetChallenge> requestCode() async =>
      throw const BodyResetException(BodyResetFailure.unavailable);
  @override
  Future<BodyResetAuthorization> verifyCode({
    required String requestId,
    required String code,
  }) async => throw const BodyResetException(BodyResetFailure.unavailable);
  @override
  Future<void> resetPassword({
    required BodyResetAuthorization authorization,
    required String newPassword,
  }) async => throw const BodyResetException(BodyResetFailure.unavailable);
}
