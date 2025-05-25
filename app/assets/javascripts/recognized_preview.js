// app/assets/javascripts/recognized_preview.js

document.addEventListener("turbo:load", () => {
  const imgData = sessionStorage.getItem("capturedImage");
  const imgEl   = document.getElementById("recognized-preview-image");
  if (imgData && imgEl) {
    imgEl.src            = imgData;
    imgEl.style.display  = "block";
    sessionStorage.removeItem("capturedImage");
  }
});
