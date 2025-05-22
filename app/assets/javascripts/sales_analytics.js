document.addEventListener("DOMContentLoaded", () => {
  // 日別売上グラフ（折れ線）
  const ctxDaily = document.getElementById("daily-sales-chart").getContext("2d");
  new Chart(ctxDaily, {
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

  // 商品別販売数グラフ（棒グラフ）
  const ctxProduct = document.getElementById("product-sales-chart").getContext("2d");
  new Chart(ctxProduct, {
    type: "bar",
    data: {
      labels: productLabels,
      datasets: [{
        label: "販売数",
        data: productData,
        borderWidth: 1
      }]
    },
    options: {
      scales: { y: { beginAtZero: true } }
    }
  });
});
