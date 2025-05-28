// app/javascript/camera.js

function initCameraPage() {
  console.log("📸 initCameraPage 実行開始");

  const video      = document.getElementById("video");
  const captureBtn = document.getElementById("capture-photo");
  const canvas     = document.getElementById("canvas");
  const ctx        = canvas.getContext("2d");
  const preview    = document.getElementById("preview");
  const container  = document.getElementById("camera-container");

  if (![video, captureBtn, canvas, ctx, preview, container].every(el => el)) {
    console.error("❌ 必須要素が見つかりません");
    return;
  }

  const mode      = container.dataset.mode;
  const productId = container.dataset.productId;

  const isMobile = /Mobi|Android/i.test(navigator.userAgent);
  const constraints = isMobile
    ? { video: { facingMode: { ideal: "environment" } }, audio: false }
    : { video: { facingMode: "user" }, audio: false };

  // カメラ起動
  navigator.mediaDevices.getUserMedia(constraints)
    .then(stream => {
      video.srcObject = stream;
      return video.play().catch(e => {
        console.warn("📛 自動再生がブロックされました:", e);
      });
    })
    .catch(err => {
      console.error("📛 カメラ起動失敗:", err);
      if (!["NotAllowedError", "PermissionDeniedError"].includes(err.name)) {
        const errorMsg = document.createElement("p");
        errorMsg.textContent = "📛 カメラを起動できませんでした: " + err.message;
        errorMsg.style = "color:#c00; font-weight:bold; text-align:center; margin-top:1rem;";
        container.appendChild(errorMsg);
      }
    });

  // キャプチャボタン押下時
  captureBtn.addEventListener("click", () => {
    // 撮影画像を canvas に描画
    canvas.width  = video.videoWidth;
    canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    // プレビュー表示
    const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
    preview.src = dataUrl;
    preview.style.display = "block";

    // predict_result ページ用にセッションストレージに保存
    sessionStorage.setItem("capturedImage", dataUrl);

    // Blob をサーバに送信
    canvas.toBlob(blob => {
      const fd = new FormData();
      fd.append("image", blob, "capture.jpg");

      // — 新規登録 or 編集 モード —
      if (mode === "new" || mode === "edit") {
        const path = mode === "new"
          ? "/products/new?from_camera=1"
          : `/products/${productId}/edit?from_camera=1`;

        fetch("/products/capture_product", {
          method: "POST",
          headers: {
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
          },
          body: fd
        })
        .then(() => window.location.href = path)
        .catch(err => console.error("キャプチャ保存エラー:", err));

      // — Flask 画像登録 モード —
      } else if (mode === "register") {
        fetch("http://127.0.0.1:10000/register_image", {
          method: "POST",
          body: fd
        })
        .then(res => {
          if (!res.ok) throw new Error(`登録失敗: ${res.status}`);
          console.log("✅ 登録に成功しました");
        })
        .catch(err => console.error("登録エラー:", err));

      // — レジ（画像認識）モード —
      } else if (mode === "order") {
        // CSRF トークン取得
        const token = document.querySelector('meta[name="csrf-token"]').content;

        // フォーム生成
        const form = document.createElement("form");
        form.method  = "POST";
        form.action  = "/products/predict";
        form.enctype = "multipart/form-data";

        // authenticity_token hidden input
        const tokenInput = document.createElement("input");
        tokenInput.type  = "hidden";
        tokenInput.name  = "authenticity_token";
        tokenInput.value = token;
        form.appendChild(tokenInput);

        // ファイル input を作成し、Blob → File 変換してセット
        const fileInput = document.createElement("input");
        fileInput.type  = "file";
        fileInput.name  = "image";
        fileInput.style.display = "none";
        form.appendChild(fileInput);

        // DataTransfer に File を追加
        const dt = new DataTransfer();
        dt.items.add(new File([blob], "capture.jpg", { type: "image/jpeg" }));
        fileInput.files = dt.files;

        // フォーム送信
        document.body.appendChild(form);
        form.submit();
      }
    }, "image/jpeg", 0.8);
  });
}

// 初期化登録
document.addEventListener("DOMContentLoaded", initCameraPage);
document.addEventListener("turbo:load", initCameraPage);

// 認識結果ページでの撮影画像プレビュー表示
document.addEventListener("DOMContentLoaded", () => {
  const resultPreview = document.getElementById("recognized-preview-image");
  if (!resultPreview) return;
  const dataUrl = sessionStorage.getItem("capturedImage");
  if (dataUrl) {
    resultPreview.src           = dataUrl;
    resultPreview.style.display = "block";
    sessionStorage.removeItem("capturedImage");
  }
});

// 編集画面→カメラ→戻り の name/price 保存＆復元
document.addEventListener("DOMContentLoaded", () => {
  const nameField  = document.querySelector("input[name='product[name]']");
  const priceField = document.querySelector("input[name='product[price]']");
  const cameraBtn  = document.getElementById("to-camera-btn");
  if (!cameraBtn) return;

  // 戻ってきたときの復元
  if (nameField && priceField) {
    const storedName  = sessionStorage.getItem("product_name");
    const storedPrice = sessionStorage.getItem("product_price");
    if (storedName  != null) {
      nameField.value = storedName;
      sessionStorage.removeItem("product_name");
    }
    if (storedPrice != null) {
      priceField.value = storedPrice;
      sessionStorage.removeItem("product_price");
    }
  }

  // カメラ画面へ遷移する前に保存
  cameraBtn.addEventListener("click", () => {
    if (nameField)  sessionStorage.setItem("product_name",  nameField.value);
    if (priceField) sessionStorage.setItem("product_price", priceField.value);

    let url = `/products/camera?mode=${cameraBtn.dataset.mode}`;
    if (cameraBtn.dataset.mode === "edit" && cameraBtn.dataset.productId) {
      url += `&product_id=${cameraBtn.dataset.productId}`;
    }
    window.location.href = url;
  });
});