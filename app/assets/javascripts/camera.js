document.addEventListener("turbo:load", () => {
  const video      = document.getElementById("video");
  const startBtn   = document.getElementById("start-camera");
  const captureBtn = document.getElementById("capture-photo");
  const canvas     = document.getElementById("canvas");
  const ctx        = canvas.getContext("2d");
  const preview    = document.getElementById("preview");
  const container  = document.getElementById("camera-container");

  // どれか見つからなければ何もしない（早期 return）
  if (![video, startBtn, captureBtn, canvas, preview, container].every(el => el)) {
    console.error("カメラ画面の必須要素が見つかりません");
    return;
  }

  const mode      = container.dataset.mode;
  const productId = container.dataset.productId;

  // スマホかどうかでカメラを切り替え
  const isMobile = /Mobi|Android/i.test(navigator.userAgent);
  const constraints = isMobile
    ? { video: { facingMode: { ideal: "environment" } }, audio: false }
    : { video: { facingMode: "user" },                 audio: false };

  // カメラ起動（ボタンクリックで）
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

  // 撮影処理
  captureBtn.addEventListener("click", () => {
    // canvas を video の解像度に合わせる
    canvas.width  = video.videoWidth;
    canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    // JPEG 形式でプレビュー表示
    const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
    preview.src           = dataUrl;
    preview.style.display = "block";
    sessionStorage.setItem("capturedImage", dataUrl);

    // JPEG Blob を生成して送信
    canvas.toBlob(blob => {
      const fd = new FormData();
      fd.append("image", blob, "capture.jpg");

      if (mode === "new" || mode === "edit") {
        fetch("/products/capture_product", { method: "POST", body: fd })
          .then(() => {
            const path = mode === "new"
              ? "/products/new?from_camera=1"
              : `/products/${productId}/edit?from_camera=1`;
            window.location.href = path;
          });
      } else {
        const isLocal = ["localhost","127.0.0.1"].includes(location.hostname);
        const baseUrl = isLocal
          ? "http://localhost:10000"
          : "https://ai-server-f6si.onrender.com";
        fetch(`${baseUrl}/predict`, { method: "POST", body: fd })
          .then(r => r.json())
          .then(json => {
            const name = json.name||"", score = json.score||0;
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
});

