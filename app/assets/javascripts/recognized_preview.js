// app/assets/javascripts/recognized_preview.js

function displayRecognizedPreview() {
  const imgData = sessionStorage.getItem("capturedImage");
  const imgEl   = document.getElementById("recognized-preview-image");

  // alertで取得したデータを確認
  alert("[recognized_preview.js] sessionStorageから取得した画像データ(先頭):\n" + (imgData ? imgData.substring(0, 30) + "..." : "データなし"));
  alert("[recognized_preview.js] img要素の取得結果:\n" + (imgEl ? "要素あり" : "要素なし (null)"));

  if (imgData && imgEl) {
    imgEl.src            = imgData;
    imgEl.style.display  = "block";
    alert("[recognized_preview.js] プレビュー画像を設定しました。");
// sessionStorage.removeItem("capturedImage"); // 必要に応じて表示後に削除。デバッグ中はコメントアウトしておくと良い。
} else if (imgEl) { // imgElは存在するが、imgDataがない場合
    alert("[recognized_preview.js] 警告: sessionStorageに画像データがありませんでした。img要素は存在します。");
} else {
    alert("[recognized_preview.js] 警告: id='recognized-preview-image' のimg要素が見つかりませんでした。");
}
}
function setupPreviewDisplayListeners() {
  // DOMContentLoaded は最初のHTMLドキュメントが完全に読み込まれ解析されたときに発火
  document.addEventListener("DOMContentLoaded", displayRecognizedPreview);
  
  // turbo:load はTurbo Driveによるページ遷移後に発火
  document.addEventListener("turbo:load", displayRecognizedPreview);
  
  // pageshow はページが表示されるたびに発火 (bfcacheからの復元も含む)
  window.addEventListener("pageshow", function(event) {
    // event.persisted が true の場合、ページが bfcache (Back/forward cache) から復元されたことを示す
    // この場合、DOMContentLoaded や turbo:load が再度発火しないことがあるため、明示的に呼び出す
    if (event.persisted) {
      // console.log("[recognized_preview.js] Page restored from bfcache, attempting to display preview."); // alertにすると煩雑なので、ここはconsole.logのままか削除
      displayRecognizedPreview();
    }
  });
  
  // 念のため、少し遅れて実行する処理も追加（DOMの準備が遅れる場合対策）
  // ただし、これは根本解決ではなく、タイミング問題の回避策の一つ
  // setTimeout(displayRecognizedPreview, 100); 
}

setupPreviewDisplayListeners();

// 開発中に sessionStorage の内容を確認しやすくするためのヘルパー
// ブラウザのコンソールで checkSessionStorage() を実行すると中身が見れる
// function checkSessionStorage() { // You can uncomment this and call it from the console
//   console.log("Current sessionStorage content for 'capturedImage':", sessionStorage.getItem("capturedImage"));
// }

// もし `application.js` で `require_tree .` を使っている場合、
// このファイルは自動的に読み込まれ、上記のイベントリスナーが設定されます。
