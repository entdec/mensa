module.exports = {
  parser: 'postcss-scss',
  loader: 'postcss-scss',
  plugins: [
    require('postcss-import'),
    require('tailwindcss/nesting'),
    require('tailwindcss'),
    require('autoprefixer'),
  ]
}