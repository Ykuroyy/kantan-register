// app/assets/javascripts/sales_analytics.js
document.addEventListener("DOMContentLoaded", () => {
  const container = document.getElementById("analytics-container");
  if (!container) return;

  // JSON.parse でデータを読み込む（data属性は文字列）
  const periodLabels  = JSON.parse(container.dataset.periodLabels);
  const periodData    = JSON.parse(container.dataset.periodData);
  const productLabels = JSON.parse(container.dataset.productLabels);
  const productData   = JSON.parse(container.dataset.productData);

  // ✅ 修正：日別売上グラフを「棒グラフ」にして beginAtZero を設定
  const ctx1 = document.getElementById("period-sales-chart").getContext("2d");
  new Chart(ctx1, {
    type: "bar",
    data: {
      labels: periodLabels,
      datasets: [{
        label: "売上金額（円）",
        data: periodData,
        borderWidth: 1
      }],
    },
    options: {
      scales: {
        y: {
          beginAtZero: true
        }
      }
    }
  });

  // 商品別販売数グラフ
  const ctx2 = document.getElementById("product-sales-chart").getContext("2d");
  new Chart(ctx2, {
    type: "bar",
    data: {
      labels: productLabels,
      datasets: [{
        label: "販売数",
        data: productData,
        backgroundColor: "rgba(75, 192, 192, 0.6)"
      }],
    },
  });
});
