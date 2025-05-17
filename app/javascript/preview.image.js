document.addEventListener('DOMContentLoaded', () => {
  const input = document.getElementById('product_image');
  const preview = document.getElementById('preview-image');
  const fileNameDisplay = document.getElementById('selected-file');
  const MAX_SIZE_MB = 2;

  if (!input) return;

  input.addEventListener('change', () => {
    const file = input.files[0];
    if (!file) return;

    if (file.size > MAX_SIZE_MB * 1024 * 1024) {
      alert(`ファイルサイズが大きすぎます（最大 ${MAX_SIZE_MB}MB）`);
      input.value = '';
      preview.style.display = 'none';
      fileNameDisplay.classList.add('hidden');
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      preview.src = e.target.result;
      preview.style.display = 'block';
    };
    reader.readAsDataURL(file);


  });
});
