// app/assets/javascripts/product_form_preview.js

// Turbo Drive 対応でページ読み込みごとに動くように
document.addEventListener("turbo:load", () => {
  const imageData   = sessionStorage.getItem("capturedImage");
  const cameraEl    = document.getElementById("camera-preview-image");
  const serverEl    = document.getElementById("server-preview-image");
  const uploadEl    = document.getElementById("upload-preview-image");

  // カメラ撮影から戻ってきたプレビュー表示
  if (imageData && cameraEl) {
    cameraEl.src              = imageData;
    cameraEl.style.display    = "block";
    if (serverEl) serverEl.style.display = "none";
    sessionStorage.removeItem("capturedImage");
  }

  // ファイル選択プレビュー
  const fileInput = document.getElementById("product_image");
  if (fileInput && uploadEl) {
    fileInput.addEventListener("change", e => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = evt => {
        uploadEl.src              = evt.target.result;
        uploadEl.style.display    = "block";
        if (serverEl) serverEl.style.display  = "none";
        if (cameraEl) cameraEl.style.display  = "none";
      };
      reader.readAsDataURL(file);
    });
  }
});
