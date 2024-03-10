module.exports = {
  parser: require('postcss-comment'),
  plugins: {
    'postcss-advanced-variables': {},
    'postcss-mixins': {},
    'postcss-import': {},
    'tailwindcss/nesting': {},
    'tailwindcss': {},
    'autoprefixer': {}
  }
}