// tailwind.config.js

module.exports = {
  content: [
    "./app/views/**/*.html.erb",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js"
  ],
  safelist: [
    'bg-gray-500',
    'hover:bg-gray-600',
    'text-white',
    'bg-blue-500',
    'hover:bg-blue-600',
    'transition',
    'transform',
    'hover:scale-95',
    'cursor-pointer'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          'Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont',
          'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'
        ]
      }
    }
  },
  plugins: []
}
