/// 登録時に選べる、よく使うサービスの候補(名前とカテゴリだけ。料金は変わりやすいので入れない)
class ServicePreset {
  final String name;
  final String genre; // 標準カテゴリ名。ユーザーが削除済みなら反映しない
  const ServicePreset(this.name, this.genre);
}

const List<ServicePreset> servicePresets = [
  // 動画
  ServicePreset('Netflix', '動画'),
  ServicePreset('Amazon Prime', '動画'),
  ServicePreset('U-NEXT', '動画'),
  ServicePreset('Disney+', '動画'),
  ServicePreset('Hulu', '動画'),
  ServicePreset('YouTube Premium', '動画'),
  ServicePreset('ABEMAプレミアム', '動画'),
  ServicePreset('DAZN', '動画'),
  // 音楽
  ServicePreset('Apple Music', '音楽'),
  ServicePreset('Spotify', '音楽'),
  ServicePreset('YouTube Music', '音楽'),
  ServicePreset('Amazon Music Unlimited', '音楽'),
  ServicePreset('LINE MUSIC', '音楽'),
  // ゲーム
  ServicePreset('Nintendo Switch Online', 'ゲーム'),
  ServicePreset('PlayStation Plus', 'ゲーム'),
  ServicePreset('Xbox Game Pass', 'ゲーム'),
  // AI
  ServicePreset('ChatGPT', 'AI'),
  ServicePreset('Claude', 'AI'),
  ServicePreset('Gemini', 'AI'),
  ServicePreset('Perplexity', 'AI'),
  // 家計・仕事のツール
  ServicePreset('マネーフォワード', '家計管理'),
  ServicePreset('Notion', 'その他'),
  ServicePreset('Adobe Creative Cloud', 'その他'),
  ServicePreset('Microsoft 365', 'その他'),
  ServicePreset('Google One', 'その他'),
  ServicePreset('iCloud+', 'その他'),
  ServicePreset('Dropbox', 'その他'),
  // 読書・その他
  ServicePreset('Kindle Unlimited', 'その他'),
  ServicePreset('Audible', 'その他'),
];
