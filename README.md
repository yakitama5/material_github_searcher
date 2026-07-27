# material_github_searcher

A new Flutter project.

## 開発環境のセットアップ

このリポジトリでは [mise](https://mise.jdx.dev/) でFlutterのバージョンを固定管理している。
開発者間・CI間でのバージョン差異を防ぐため、`mise.toml` に記載されたバージョンを使用すること。

```sh
mise install
```

実行後、`flutter --version` で `mise.toml` の `flutter` に指定したバージョンが
解決されていることを確認する。

`pubspec.yaml` の `environment.sdk` / `environment.flutter` も、`mise.toml` と同じ
Dart / Flutterのバージョンに固定している。`mise.toml` を更新した際は、
`pubspec.yaml` の `environment` も合わせて更新すること。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
