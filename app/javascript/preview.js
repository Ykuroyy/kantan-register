document.addEventListener('DOMContentLoaded', () => {
  const input = document.getElementById('product_image');
  const preview = document.getElementById('preview-image');

  if (!input || !preview) return;

  input.addEventListener('change', () => {
    const file = input.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
      preview.src = e.target.result;
      preview.style.display = 'block';
    };
    reader.readAsDataURL(file);
  });
});
