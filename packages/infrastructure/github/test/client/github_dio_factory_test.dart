import 'package:infrastructure_github/src/client/github_dio_factory.dart';
import 'package:test/test.dart';

void main() {
  group('createGitHubDio', () {
    test('baseUrlがGitHub APIを指す', () {
      final dio = createGitHubDio();

      expect(dio.options.baseUrl, 'https://api.github.com');
    });

    test('必須ヘッダーが設定される', () {
      final dio = createGitHubDio(userAgent: 'test-agent');

      expect(dio.options.headers['Accept'], 'application/vnd.github+json');
      expect(dio.options.headers['X-GitHub-Api-Version'], '2022-11-28');
      expect(dio.options.headers['User-Agent'], 'test-agent');
    });

    test('Authorizationヘッダーは設定されない', () {
      final dio = createGitHubDio();

      expect(dio.options.headers.containsKey('Authorization'), isFalse);
    });

    test('接続・受信タイムアウトが設定される', () {
      final dio = createGitHubDio();

      expect(dio.options.connectTimeout, isNotNull);
      expect(dio.options.receiveTimeout, isNotNull);
    });
  });
}
