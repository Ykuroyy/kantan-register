function initCameraPage() {
  console.log("📸 initCameraPage 実行開始");

  const video      = document.getElementById("video");
  const captureBtn = document.getElementById("capture-photo");
  const canvas     = document.getElementById("canvas");
  const ctx        = canvas.getContext("2d");
  const preview    = document.getElementById("preview");
  const container  = document.getElementById("camera-container");

  console.log("🎯 video:", video);
  console.log("🎯 captureBtn:", captureBtn);
  console.log("🎯 container:", container);

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

      if (mode === "new" || mode === "edit") {
        const path = mode === "new"
          ? "/products/new?from_camera=1"
          : `/products/${productId}/edit?from_camera=1`;

        fetch("/products/capture_product", { method: "POST", body: fd })
          .then(() => window.location.href = path)
          .catch(err => {
            console.error("キャプチャ保存エラー:", err);
            alert("画像保存に失敗しました");
          });

      } else if (mode === "register") {
        fetch("http://127.0.0.1:10000/register_image", {
          method: "POST",
          body: fd
        })
          .then(res => {
            if (!res.ok) throw new Error(`登録失敗: ${res.status}`);
            alert("登録に成功しました");
          })
          .catch(err => {
            console.error("登録エラー:", err);
            alert("登録エラー: " + err.message);
          });

      } else {
        const baseUrl = (["localhost", "127.0.0.1"].includes(location.hostname))
          ? "http://localhost:10000"
          : "https://ai-server-f6si.onrender.com";

        if (!["localhost", "127.0.0.1"].includes(location.hostname)) {
          const s3ImageUrl = container.dataset.imageUrl;
          if (!s3ImageUrl) {
            alert("画像URLがありません");
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
              alert("予測処理に失敗しました");
            });

        } else {
          fetch(`${baseUrl}/predict`, { method: "POST", body: fd })
            .then(res => res.json())
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
      }
    }, "image/jpeg", 0.8);
  });
}

document.addEventListener("DOMContentLoaded", initCameraPage);
document.addEventListener("turbo:load",       initCameraPage);
