// app/assets/javascripts/sales_analytics.js

document.addEventListener("turbo:load", () => {
  const container = document.getElementById("analytics-container");
  if (!container) return;

  // HTML data-属性から文字列を取り出し、JSON.parse で JS の配列に戻す
  const periodLabels  = JSON.parse(container.dataset.periodLabels);
  const periodData    = JSON.parse(container.dataset.periodData);
  const productLabels = JSON.parse(container.dataset.productLabels);
  const productData   = JSON.parse(container.dataset.productData);

  // ② 期間別売上グラフ
  const ctx1 = document.getElementById("period-sales-chart").getContext("2d");
  new Chart(ctx1, {
    type: "line",
    data: {
      labels: periodLabels,
      datasets: [{
        label: "売上",
        data: periodData,
      }],
    },
    options: { /* 必要に応じて */ }
  });

  // ③ 商品別販売数グラフ
  const ctx2 = document.getElementById("product-sales-chart").getContext("2d");
  new Chart(ctx2, {
    type: "bar",
    data: {
      labels: productLabels,
      datasets: [{
        label: "販売数",
        data: productData,
      }],
    },
    options: { /* 必要に応じて */ }
  });
});
