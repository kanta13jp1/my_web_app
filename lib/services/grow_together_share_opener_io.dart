// 非 Web (VM / flutter test / native) 用スタブ。
// X シェアのサイズ付きポップアップは Web 専用機能のため、ここでは何もしない。
// `kIsWeb` ガードにより実行時にこの実装が Web 経路で呼ばれることはなく、
// 条件付き import の既定として VM コンパイルを通すためだけに存在する。
bool openXSharePopup(String url) => false;
