document.addEventListener("DOMContentLoaded", () => {
  const dailySales = window.dailySalesData || {};
  const labels = Object.keys(dailySales);    // ["2025-05-20", "2025-05-21", ...]
  const values = Object.values(dailySales);  // [1000, 1500, ...]

  const ctx = document.getElementById('daily-sales-chart').getContext('2d');
  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [{
        label: '日別売上 (円)',
        data: values,
        backgroundColor: 'rgba(54, 162, 235, 0.6)',
        borderColor: 'rgba(54, 162, 235, 1)',
        borderWidth: 1
      }]
    },
    options: {
      responsive: true,
      scales: {
        y: {
          beginAtZero: true
        }
      }
    }
  });
});
