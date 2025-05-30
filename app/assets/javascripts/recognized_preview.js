// app/assets/javascripts/recognized_preview.js

function displayRecognizedPreview() {
  const imgData = sessionStorage.getItem("capturedImage");
  const imgEl   = document.getElementById("recognized-preview-image");
  if (imgData && imgEl) {
    imgEl.src            = imgData;
    imgEl.style.display  = "block";
// sessionStorage.removeItem("capturedImage"); // 必要に応じて表示後に削除。デバッグ中はコメントアウトしておくと良い。
} else if (imgEl) { // imgElは存在するが、imgDataがない場合
  console.warn("撮影された画像データがsessionStorageに見つかりません。recognized-preview-imageは存在します。");
} else {
  console.warn("recognized-preview-image のimg要素が見つかりません。");
}
}

document.addEventListener("DOMContentLoaded", displayRecognizedPreview);
document.addEventListener("turbo:load", displayRecognizedPreview);

// ページが完全に表示された後にもう一度試す（保険的な処理）
window.addEventListener("pageshow", function(event) {
  // persistedがtrueの場合、ブラウザのキャッシュからページが復元されたことを示す
  if (event.persisted) {
    displayRecognizedPreview();
  }
});

