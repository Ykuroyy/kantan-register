// camera.js

// カメラ画面の初期化ロジックを関数として定義
function initCameraPage() {
  const video      = document.getElementById("video");
  const startBtn   = document.getElementById("start-camera");
  const captureBtn = document.getElementById("capture-photo");
  const nextBtn    = document.getElementById("next-button");
  const canvas     = document.getElementById("canvas");
  const ctx        = canvas.getContext("2d");
  const preview    = document.getElementById("preview");
  const container  = document.getElementById("camera-container");

  // 必須要素が揃っていなければ何もしない
  if (![video, startBtn, captureBtn, nextBtn, canvas, preview, container].every(el => el)) {
    console.error("カメラ画面の必須要素が見つかりません");
    return;
  }

  const mode      = container.dataset.mode;
  const productId = container.dataset.productId;

  // カメラ設定
  const isMobile = /Mobi|Android/i.test(navigator.userAgent);
  const constraints = isMobile
    ? { video: { facingMode: { ideal: "environment" } }, audio: false }
    : { video: { facingMode: "user" },                 audio: false };

  // 起動ボタン
  startBtn.addEventListener("click", async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      video.srcObject = stream;
      await video.play();
    } catch (err) {
      alert("カメラが使用できません: " + err.message);
      console.error(err);
    }
  });

  // 撮影ボタン
  captureBtn.addEventListener("click", () => {
    // カメラ映像を canvas に転写
    canvas.width  = video.videoWidth;
    canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    // プレビュー表示
    const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
    preview.src           = dataUrl;
    preview.style.display = "block";

    // 「次へ」表示
    nextBtn.style.display = "inline-block";

    // セッションにも保存しておく（不要なら削除）
    sessionStorage.setItem("capturedImage", dataUrl);
  });

  // 次へボタン：ここでサーバ送信＆リダイレクト
  nextBtn.addEventListener("click", () => {
    canvas.toBlob(blob => {
      const fd = new FormData();
      fd.append("image", blob, "capture.jpg");

      if (mode === "new" || mode === "edit") {
        const path = mode === "new"
          ? "/products/new?from_camera=1"
          : `/products/${productId}/edit?from_camera=1`;
        fetch("/products/capture_product", { method: "POST", body: fd })
          .then(() => window.location.href = path);
      } else {
        const baseUrl = (["localhost","127.0.0.1"].includes(location.hostname))
          ? "http://localhost:10000"
          : "https://ai-server-f6si.onrender.com";

        fetch(`${baseUrl}/predict`, { method: "POST", body: fd })
          .then(r => r.json())
          .then(json => {
            const name  = json.name  || "";
            const score = json.score || 0;
            window.location.href =
              `/products/predict_result?predicted_name=${encodeURIComponent(name)}&score=${score}`;
          })
          .catch(err => {
            console.error("予測エラー:", err);
            alert("予測処理に失敗しました");
          });
      }
    }, "image/jpeg", 0.8);
  });
}

// ページ読み込み（初回＆Turboロード時）に初期化を実行
document.addEventListener("DOMContentLoaded", initCameraPage);
document.addEventListener("turbo:load",       initCameraPage);
