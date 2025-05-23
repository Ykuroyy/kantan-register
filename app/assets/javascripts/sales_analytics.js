// app/assets/javascripts/sales_analytics.js
document.addEventListener("DOMContentLoaded", () => {
  // ── 日別売上グラフ（折れ線） ──
  const dailyEl = document.getElementById("daily-sales-chart");
  if (dailyEl && typeof Chart !== "undefined") {
    new Chart(dailyEl.getContext("2d"), {
      type: "line",
      data: {
        labels: dailyLabels,
        datasets: [{
          label: "日別売上 (¥)",
          data: dailyData,
          borderWidth: 2,
          fill: false
        }]
      },
      options: {
        scales: { y: { beginAtZero: true } }
      }
    });
  }

  // ── 商品別販売数グラフ（棒グラフ） ──
  const productEl = document.getElementById("product-sales-chart");
  if (productEl && typeof Chart !== "undefined") {
    new Chart(productEl.getContext("2d"), {
      type: "bar",
      data: {
        labels: productLabels,
        datasets: [{
          label: "商品別販売数",
          data: productData,
          borderWidth: 1
        }]
      },
      options: {
        scales: { y: { beginAtZero: true } }
      }
    });
  }
});
