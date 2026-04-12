module.exports = {
  docsSidebar: [
    'getting-started',
    'cli',
    {
      type: 'category',
      label: 'Language',
      items: [
        'language',
        'modules',
        'macros',
      ],
    },
    {
      type: 'category',
      label: 'Standard Library',
      items: [
        'stdlib',
        'stdlib-prelude',
        {
          type: 'category',
          label: 'Modules',
          items: [
            'std-sys',
            'std-fs',
            'std-test',
            'std-string',
            'std-number',
            'std-array',
            'std-hash',
            'std-bool',
            'std-object',
            'std-class',
            'std-module',
            'std-function',
            'std-json',
            'std-math',
            'std-html',
            'std-inflector',
          ],
        },
      ],
    },
    'testing',
    'roadmap',
  ],
};
