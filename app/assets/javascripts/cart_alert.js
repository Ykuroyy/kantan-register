// app/assets/javascripts/cart_alert.js

document.addEventListener("turbo:load", () => {
  const name = localStorage.getItem("recognized_name");
  if (name) {
    alert("前回認識された商品: " + name);
    localStorage.removeItem("recognized_name");
  }
});
