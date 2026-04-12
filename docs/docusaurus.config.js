const config = {
  title: 'Jaya',
  tagline: 'A language for applications, DSLs, and practical tooling',
  favicon: 'img/favicon.ico',

  url: 'https://u89012.github.io',
  baseUrl: '/jpl/',

  organizationName: 'u89012',
  projectName: 'jpl',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          path: 'site',
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ],

  themeConfig: {
    image: 'img/social-card.jpg',
    navbar: {
      title: 'Jaya',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          href: 'https://github.com/u89012/jpl',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            { label: 'Overview', to: '/' },
            { label: 'Language', to: '/language' },
            { label: 'Standard Library', to: '/stdlib' },
          ],
        },
        {
          title: 'Tooling',
          items: [
            { label: 'CLI', to: '/cli' },
            { label: 'Testing', to: '/testing' },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Jaya`,
    },
    prism: {
      additionalLanguages: ['lua', 'bash', 'json'],
    },
  },
};

module.exports = config;
