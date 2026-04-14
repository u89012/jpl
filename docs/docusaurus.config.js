const config = {
  title: 'Jaya',
  tagline: 'A language for applications, DSLs, and practical tooling',
  favicon: 'img/favicon.ico',

  url: 'https://u89012.github.io',
  baseUrl: '/jpl/',

  organizationName: 'u89012',
  projectName: 'jpl',
  trailingSlash: false,
  scripts: [
    {
      src: 'https://www.googletagmanager.com/gtag/js?id=G-X9C1H1DPPP',
      async: true,
    },
  ],
  headTags: [
    {
      tagName: 'script',
      attributes: {},
      innerHTML: `window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', 'G-X9C1H1DPPP');`,
    },
  ],

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
      copyright: `Made with love by <a href="https://github.com/u89012">@u89012</a>`,
    },
    prism: {
      additionalLanguages: ['lua', 'bash', 'json'],
    },
  },
};

module.exports = config;
