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

  navigator.mediaDevices.getUserMedia(constraints)
    .then(stream => {
      video.srcObject = stream;
      return video.play().catch(e => {
        console.warn("📛 自動再生がブロックされました:", e);
      });
    })
    .catch(err => {
      console.error("📛 カメラ起動失敗:", err);
      if (err.name !== "NotAllowedError" && err.name !== "PermissionDeniedError") {
        const errorMsg = document.createElement("p");
        errorMsg.textContent = "📛 カメラを起動できませんでした: " + err.message;
        errorMsg.style = "color:#c00; font-weight:bold; text-align:center; margin-top:1rem;";
        container.appendChild(errorMsg);
      }
    });

  captureBtn.addEventListener("click", () => {
    canvas.width  = video.videoWidth;
    canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
    preview.src = dataUrl;
    preview.style.display = "block";

    sessionStorage.setItem("capturedImage", dataUrl);

    canvas.toBlob(blob => {
      const fd = new FormData();
      if (mode === "register") {
        fd.append("name", `user_${Date.now()}`);
      }
      fd.append("image", blob, "capture.jpg");

      // 商品登録・編集
      if (mode === "new" || mode === "edit") {
        const path = mode === "new"
          ? "/products/new?from_camera=1"
          : `/products/${productId}/edit?from_camera=1`;

        fetch("/products/capture_product", { method: "POST", body: fd })
            .then(() => window.location.href = path)
            .catch(err => {
              console.error("キャプチャ保存エラー:", err);
              // alert("画像保存に失敗しました");  ← 削除
              // 必要なら画面内にメッセージ要素を挿入する例：
              // const msg = document.createElement("p");
              // msg.textContent = "画像保存に失敗しました";
              // msg.style = "color:#c00; text-align:center;";
              // container.appendChild(msg);
            });


      // Flask画像登録
      } else if (mode === "register") {
        fetch("http://127.0.0.1:10000/register_image", {
          method: "POST",
          body: fd
        })
        .then(res => {
          if (!res.ok) throw new Error(`登録失敗: ${res.status}`);
          console.log("✅ 登録に成功しました");
        })
        // 必要なら画面内にメッセージを挿入するなど、alert は使わない
    

      // レジモード（画像認識）
      } else if (mode === "order") {
        const baseUrl = (["localhost", "127.0.0.1"].includes(location.hostname))
          ? "http://localhost:10000"
          : "https://ai-server-f6si.onrender.com";

        // 本番：画像URL送信
        if (!["localhost", "127.0.0.1"].includes(location.hostname)) {
          const s3ImageUrl = container.dataset.imageUrl;
          console.log("📦 image_url:", s3ImageUrl);

          if (!s3ImageUrl || s3ImageUrl === "null" || s3ImageUrl === "undefined") {
            console.warn("画像URLがありません");
            return;
          }

          const formData = new FormData();
          formData.append("image_url", s3ImageUrl);

          fetch(`${baseUrl}/predict`, { method: "POST", body: formData })
            .then(res => res.json())
            .then(json => {
              const name  = json.name  || "";
              const score = json.score || 0;
              window.location.href =
                `/products/predict_result?predicted_name=${encodeURIComponent(name)}&score=${score}`;
            })
            .catch(err => {
              console.error("予測エラー:", err);
              console.warn("予測処理に失敗しました");
            });

        // 開発：blob送信
        } else {
          fetch(`${baseUrl}/predict`, { method: "POST", body: fd })
            .then(res => res.json())
            .then(json => {
              const name  = json.name || "";
              const score = json.score || 0;
              if (!name) {
                console.warn("⚠️ 商品認識はできましたが、登録済み商品にはマッチしませんでした");
                return; // 何も表示せずに終了
              }
              // ヒットあり → 結果ページへ
              window.location.href =
                `/products/predict_result?predicted_name=${encodeURIComponent(name)}&score=${score}`;           
            })
            .catch(err => {
              console.error("予測エラー:", err);
              // console.warn("予測処理に失敗しました");
            });
        }
      }
    }, "image/jpeg", 0.8);
  });
}



// ⇒ ここまでが initCameraPage() の定義 と イベント登録
document.addEventListener("DOMContentLoaded", initCameraPage);
document.addEventListener("turbo:load", initCameraPage);

// 編集画面→カメラ→戻り の name/price 保存＆復元
document.addEventListener("DOMContentLoaded", function() {
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
  cameraBtn.addEventListener("click", function() {
    // 値の退避
    if (nameField)  sessionStorage.setItem("product_name",  nameField.value);
    if (priceField) sessionStorage.setItem("product_price", priceField.value);

    const mode      = cameraBtn.dataset.mode;       // "edit" or "new"
    const productId = cameraBtn.dataset.productId;  // undefined on new

    // 遷移URLを組み立て
    let url = `/products/camera?mode=${mode}`;
    if (mode === "edit" && productId) {
      url += `&product_id=${productId}`;
    }

    window.location.href = url;
  });
}); 

  // ② 認識結果ページで撮影画像のプレビュー表示
  document.addEventListener("DOMContentLoaded", function() {
    const resultPreview = document.getElementById("recognized-preview-image");
    if (!resultPreview) return;

    const dataUrl = sessionStorage.getItem("capturedImage");
    if (dataUrl) {
      resultPreview.src           = dataUrl;
      resultPreview.style.display = "block";
      sessionStorage.removeItem("capturedImage");
    }
  });

