const path = require('path');

module.exports = {
  entry: './src/assets/src.js',
  output: {
    filename: 'ktistec.js',
    path: path.resolve(__dirname, 'public', 'dist'),
  },
  module: {
    rules: [
      {
        test: /\.css$/i,
        use: ['style-loader', 'css-loader'],
      },
      {
        test: /\.(png|svg|jpg|jpeg|gif)$/i,
        type: 'asset/resource',
      },
      {
        test: /\.(woff|woff2|eot|ttf|otf)$/i,
        type: 'asset/resource',
      },
    ],
  },
  externals: {
    jquery: 'jQuery',
  },
};
