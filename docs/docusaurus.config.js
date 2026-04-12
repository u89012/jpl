const config = {
  title: 'Jaya',
  tagline: 'A language for applications, DSLs, and practical tooling',
  favicon: 'img/favicon.ico',

  url: 'https://example.github.io',
  baseUrl: '/',

  organizationName: 'example',
  projectName: 'jaya',
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
          href: 'https://github.com/example/jaya',
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
