const raycastConfig = require('@raycast/eslint-config')

module.exports = [
  ...raycastConfig.flat(),
  {
    files: ['src/**/*.{ts,tsx}'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: ['node:*'],
          paths: [
            {
              name: 'execa',
              message: 'Use Effect Platform Command for subprocess IO.',
            },
          ],
        },
      ],
    },
  },
]
