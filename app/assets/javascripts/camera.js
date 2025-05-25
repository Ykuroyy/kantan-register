// app/assets/javascripts/camera.js

function initCameraPage() {
  const video      = document.getElementById("video");
  const captureBtn = document.getElementById("capture-photo");
  const canvas     = document.getElementById("canvas");
  const ctx        = canvas.getContext("2d");
  const preview    = document.getElementById("preview");
  const container  = document.getElementById("camera-container");

  // 必須要素チェック
  if (![video, captureBtn, canvas, ctx, preview, container].every(el => el)) {
    console.error("必須要素が見つかりません");
    return;
  }

  // モード／商品ID（"new" / "edit" / "order"）
  const mode      = container.dataset.mode;
  const productId = container.dataset.productId;

  // カメラ設定（スマホなら背面カメラ）
  const isMobile   = /Mobi|Android/i.test(navigator.userAgent);
  const constraints = isMobile
    ? { video: { facingMode: { ideal: "environment" } }, audio: false }
    : { video: { facingMode: "user" },                         audio: false };

  // ページロード時にカメラ起動
  navigator.mediaDevices.getUserMedia(constraints)
    .then(stream => {
      video.srcObject = stream;
      return video.play();
    })
    .catch(err => {
      alert("カメラが使用できません: " + err.message);
      console.error(err);
    });

  // 撮影ボタン：キャプチャ→プレビュー→sessionStorage→サーバ送信→リダイレクト
  captureBtn.addEventListener("click", () => {
    // 1) Canvas にキャプチャ
    canvas.width  = video.videoWidth;
    canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    // 2) プレビュー表示
    const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
    preview.src           = dataUrl;
    preview.style.display = "block";

    // 3) sessionStorage に保存
    sessionStorage.setItem("capturedImage", dataUrl);

    // 4) Blob 化してサーバに POST
    canvas.toBlob(blob => {
      const fd = new FormData();

      // --- Flask 登録用エンドポイントでは name が必須 ---
      // register モードなら一意の名前を付与
      if (mode === "register") {
        fd.append("name", `user_${Date.now()}`);
      }


      // どの場合も image キーは必須
      fd.append("image", blob, "capture.jpg");


      // モード別に送信先を切り替え
      if (mode === "new" || mode === "edit") {
        // 商品登録／編集モード
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
        // ここを登録：Flask の /register_image へ
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
        // レジ／画像認識モード：Flask の /predict へ
        const baseUrl = (["localhost","127.0.0.1"].includes(location.hostname))
          ? "http://localhost:10000"
          : "https://ai-server-f6si.onrender.com";

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
    }, "image/jpeg", 0.8);
  });
}

document.addEventListener("DOMContentLoaded", initCameraPage);
document.addEventListener("turbo:load",       initCameraPage);
