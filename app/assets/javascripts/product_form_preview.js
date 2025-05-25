// app/assets/javascripts/product_form_preview.js

function initProductFormPreview() {
  const dataUrl = sessionStorage.getItem("capturedImage");
  const main    = document.getElementById("camera-preview-main");
  const thumb   = document.getElementById("camera-preview-thumb");
  const server  = document.getElementById("server-preview-image");
  const upload  = document.getElementById("upload-preview-image");

  // カメラ撮影プレビュー表示
  if (dataUrl) {
    if (main) {
      main.src           = dataUrl;
      main.style.display = "block";
    }
    if (thumb) {
      thumb.src           = dataUrl;
      thumb.style.display = "block";
    }
    if (server) {
      server.style.display = "none";
    }
    sessionStorage.removeItem("capturedImage");
  }

  // ファイル選択プレビュー
  const fileInput = document.getElementById("product_image");
  if (fileInput && upload) {
    fileInput.addEventListener("change", e => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = evt => {
        upload.src           = evt.target.result;
        upload.style.display = "block";
        if (server)  server.style.display  = "none";
        if (main)    main.style.display    = "none";
        if (thumb)   thumb.style.display   = "none";
      };
      reader.readAsDataURL(file);
    });
  }
}

document.addEventListener("DOMContentLoaded", initProductFormPreview);
document.addEventListener("turbo:load",       initProductFormPreview);
