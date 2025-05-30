// app/javascript/camera.js

// グローバルスコープまたは initCameraPage の外でハンドラを定義
const handleCaptureButtonClick = () => {
  console.log("Capture button clicked (handler)!"); // デバッグ用ログ
  const captureBtn = document.getElementById("capture-photo");
  // ボタンが存在しないか、既に無効なら何もしない (二重実行防止)
  if (!captureBtn || captureBtn.disabled) {
    console.log("Capture button not found or already disabled in handler.");
    return;
  }

  captureBtn.disabled = true; // ボタンを無効化

  // 必要な要素を再度取得 (initCameraPageから渡すか、ここで再取得)
  const video = document.getElementById("video");
  const canvas = document.getElementById("canvas");
  const preview = document.getElementById("preview");
  const container = document.getElementById("camera-container");

  if (!video || !canvas || !preview || !container) {
    console.error("❌ キャプチャに必要な要素が見つかりません (handler内)");
    if(captureBtn) captureBtn.disabled = false; // エラーなのでボタンを戻す
    return;
  }
  const ctx = canvas.getContext("2d"); // ctxもここで取得
  const mode = container.dataset.mode;
  const productId = container.dataset.productId;

  // 撮影画像を canvas に描画
  canvas.width  = video.videoWidth;
  canvas.height = video.videoHeight;
  ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

  // プレビュー表示
  const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
  preview.src = dataUrl;
  preview.style.display = "block";
  // alert("[camera.js] canvas.toDataURLの結果 (先頭30文字):\n" + (dataUrl ? dataUrl.substring(0, 30) + "..." : "データなしまたは不正")); // デバッグ完了後はコメントアウト

  // predict_result ページ用にセッションストレージに保存
  sessionStorage.setItem("capturedImage", dataUrl);
  // alert("[camera.js] sessionStorage.setItem直後、getItemの結果 (先頭30文字):\n" + (sessionStorage.getItem("capturedImage") ? sessionStorage.getItem("capturedImage").substring(0, 30) + "..." : "取得失敗または空")); // デバッグ完了後はコメントアウト

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
      .then(response => { // レスポンスオブジェクトを受け取る
        if (!response.ok) { // HTTPステータスコードでエラーを判断
          throw new Error(`Server responded with ${response.status}`);
        }
        window.location.href = path; // 成功時のみページ遷移
      })
      .catch(err => {
        console.error("キャプチャ保存エラー:", err);
        alert("画像の保存に失敗しました。もう一度お試しください。");
        if(captureBtn) captureBtn.disabled = false; // エラー時にボタンを再有効化
      });
      // 成功時はページ遷移するので finally での再有効化は不要

    // Flask 画像登録 モードは、以前の修正でDB保存処理を削除したため、
    // もしこのモードがまだ他の目的で必要であれば、同様のエラーハンドリングとボタン再有効化が必要です。
    // ここでは、そのモードのロジックは省略されていると仮定します。

    // — レジ（画像認識）モード —
    } else if (mode === "order") {
      // 元のフォーム送信方法に戻す
      const token = document.querySelector('meta[name="csrf-token"]').content;
      const form = document.createElement("form");
      form.method  = "POST";
      form.action  = "/products/predict";
      form.enctype = "multipart/form-data";

      const tokenInput = document.createElement("input");
      tokenInput.type  = "hidden";
      tokenInput.name  = "authenticity_token";
      tokenInput.value = token;
      form.appendChild(tokenInput);

      const fileInput = document.createElement("input");
      fileInput.type  = "file";
      fileInput.name  = "image";
      fileInput.style.display = "none";
      form.appendChild(fileInput);

      const dt = new DataTransfer();
      dt.items.add(new File([blob], "capture.jpg", { type: "image/jpeg" }));
      fileInput.files = dt.files;

      document.body.appendChild(form);
      setTimeout(() => {
        const checkDataBeforeSubmit = sessionStorage.getItem("capturedImage");
        // alert("[camera.js] フォーム送信直前 (setTimeout内)、sessionStorageの内容(先頭30文字):\n" + (checkDataBeforeSubmit ? checkDataBeforeSubmit.substring(0, 30) + "..." : "取得失敗または空")); // デバッグ用
        if (checkDataBeforeSubmit) {
          try {
            console.log("[camera.js] Submitting form to /products/predict");
            form.submit();
          } catch (e) {
            console.error("[camera.js] フォーム送信エラー:", e);
            alert("フォームの送信に失敗しました。");
            if(captureBtn) captureBtn.disabled = false;
          }
        } else {
          alert("[camera.js] ERROR: Data disappeared from sessionStorage before form submit!");
          if(captureBtn) captureBtn.disabled = false;
        }
      }, 200); // 遅延を 200ミリ秒に増やしてみる
    } else {
      // 他のモードや予期しないモードの場合
      console.warn(`不明なモード: ${mode} またはボタンは既に処理されました。`);
      if(captureBtn) captureBtn.disabled = false; // 念のためボタンを有効化
    }
  }, "image/jpeg", 0.8);
};

function initCameraPage() {
  console.log("📸 initCameraPage 実行開始");

  const video      = document.getElementById("video");
  const captureBtn = document.getElementById("capture-photo");
  const canvas     = document.getElementById("canvas");
  const ctx        = canvas.getContext("2d");
  const preview    = document.getElementById("preview");
  const container  = document.getElementById("camera-container");

  // captureBtnの存在を最初に確認
  if (!captureBtn || !video || !canvas || !preview || !container) { // ctxはcanvasから取得するのでここでは不要
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

  // イベントリスナーの重複登録を防ぐ
  // 既存のリスナーがアタッチされていれば削除
  if (captureBtn._handleCaptureButtonClick) {
    captureBtn.removeEventListener("click", captureBtn._handleCaptureButtonClick);
  }
  // 新しいハンドラをアタッチし、その参照をボタンのプロパティに保存
  captureBtn.addEventListener("click", handleCaptureButtonClick);
  captureBtn._handleCaptureButtonClick = handleCaptureButtonClick; // 後で削除できるように参照を保存
}

// 初期化登録
document.addEventListener("DOMContentLoaded", initCameraPage);
document.addEventListener("turbo:load", initCameraPage);

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
