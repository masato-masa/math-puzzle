/// マネタイズ用の差し替え可能インターフェース。
///
/// 現時点ではどの SDK にも依存しない no-op 実装のみを提供する
/// （広告・課金は今回のスコープ外）。将来 AdMob や StoreKit を導入する際は、
/// ここに実装クラス（例: AdMobAdService, StoreKitPurchaseService）を追加して
/// main.dart の生成箇所を差し替えるだけでよく、画面側のコードは変更不要。
abstract class AdService {
  Future<void> initialize();

  /// バナー等を表示してよいタイミングかどうかは呼び出し側が判断する。
  /// no-op 実装は常に何もしない。
  Future<void> showInterstitialIfAvailable();
}

class NoopAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> showInterstitialIfAvailable() async {}
}

/// コース・レベルパックの購入状態を問い合わせる窓口。
/// no-op 実装は「全て未購入だが全コース無料開放」として振る舞う
/// （現状は課金コースが存在しないため、実質的に無効化と同じ）。
abstract class PurchaseService {
  Future<void> initialize();
  Future<bool> isUnlocked(String courseId);
  Future<void> purchase(String courseId);
  Future<void> restorePurchases();
}

class NoopPurchaseService implements PurchaseService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isUnlocked(String courseId) async => true;

  @override
  Future<void> purchase(String courseId) async {}

  @override
  Future<void> restorePurchases() async {}
}
