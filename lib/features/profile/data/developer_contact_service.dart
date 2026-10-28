import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const developerEmail = '1786857315@qq.com';

class DeveloperFeedback {
  const DeveloperFeedback({
    required this.content,
    required this.version,
    this.subject = '',
    this.contact = '',
  });
  final String content, version, subject, contact;

  String get mailSubject =>
      'LifeAtlas 反馈 [$version] ${subject.trim().replaceAll(RegExp(r'[\r\n]+'), ' ')}'
          .trim();
  String get body =>
      '${content.trim()}\n\n联系方式：${contact.trim().isEmpty ? '未填写' : contact.trim()}\n软件版本：$version';
  Uri get uri => Uri(
    scheme: 'mailto',
    path: developerEmail,
    query: {'subject': mailSubject, 'body': body}.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&'),
  );
  String get copyText => '收件人：$developerEmail\n主题：$mailSubject\n\n$body';
}

class DeveloperContactService {
  Future<String> loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (info.version.trim().isEmpty) throw StateError('版本未读取');
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  }

  Future<bool> openMail(DeveloperFeedback feedback) =>
      launchUrl(feedback.uri, mode: LaunchMode.externalApplication);
}
