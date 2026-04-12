import React, { useState } from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';

const examples = {
  html: {
    label: 'HTML Builder',
    code: `html = require('html')

export fn page(users)
  b = html.Builder()
  b.div(class='panel') do
    b.h1('Users')
    b.ul() do
      for user in users
        b.li("#{user.name} (#{user.role})")
      end
    end
  end
  return b.s()
end`,
  },
  macros: {
    label: 'Macros',
    code: `macro deftags(*names)
  out = []
  for name in names
    out[#out + 1] = _q(
      macro name(*children, **attrs, &body) = _q(
        tag(_u(name), attrs, children, body)
      )
    )
  end
  return out
end`,
  },
  match: {
    label: 'Pattern Matching',
    code: `class User(name, age) end

export fn describe(value)
  match value
  when User(name, age)
    return "#{name} is #{age}"
  when nil
    return 'missing'
  else
    return 'other'
  end
end`,
  },
  json: {
    label: 'JSON and Stdlib',
    code: `json = require('json')

export fn payload(user)
  return json.encode({
    first_name = user.firstName,
    role = user.role,
    tags = ['team', 'active']
  }, casing=json.camel)
end`,
  },
};

export default function Home() {
  const [example, setExample] = useState('html');

  return (
    <Layout title="Jaya" description="Jaya language documentation">
      <header className="hero hero--jaya">
        <div className="container">
          <div className="row row--align-center">
            <div className="col col--6">
              <h1 className="hero__title">The Jaya Programming Language</h1>
              <p className="hero__subtitle">
                A fast, modern dynamic language, thoughtfully designed for applications, DSLs, and practical tooling.
                Jaya combines clean syntax, compile-time macros, classes,
                pattern matching, and a growing standard library.
              </p>
              <div>
                <Link className="button button--primary button--lg" to="/getting-started">
                  Get Started
                </Link>
              </div>
            </div>
            <div className="col col--6 heroExample">
              <div className="heroCodeCard">
                <div className="heroCodeHeader">
                  <span>Example</span>
                  <select
                    className="heroCodeSelect"
                    value={example}
                    onChange={(event) => setExample(event.target.value)}>
                    {Object.entries(examples).map(([key, value]) => (
                      <option key={key} value={key}>
                        {value.label}
                      </option>
                    ))}
                  </select>
                </div>
                <pre>
                  <code>{examples[example].code}</code>
                </pre>
              </div>
            </div>
          </div>
        </div>
      </header>
      <main className="container margin-vert--lg">
        <div className="row featureGrid">
          <div className="col col--4 margin-bottom--lg">
            <div className="featureCard">
              <h3>Classes</h3>
              <p>
                Build application code with classes, inheritance, visibility, reflection,
                and a standard object model.
              </p>
            </div>
          </div>
          <div className="col col--4 margin-bottom--lg">
            <div className="featureCard">
              <h3>Macros</h3>
              <p>
                Write compile-time macros with explicit quote and unquote support,
                and generate real language constructs programmatically.
              </p>
            </div>
          </div>
          <div className="col col--4 margin-bottom--lg">
            <div className="featureCard">
              <h3>Control Flow</h3>
              <p>
                Use `if`, `unless`, `case`, `match`, `for`, `let`, and `try` with
                syntax designed to stay compact and readable.
              </p>
            </div>
          </div>
          <div className="col col--4 margin-bottom--lg">
            <div className="featureCard">
              <h3>Core Types</h3>
              <p>
                Strings, numbers, arrays, hashes, functions, classes, and modules
                expose practical methods through the prelude and stdlib.
              </p>
            </div>
          </div>
          <div className="col col--4 margin-bottom--lg">
            <div className="featureCard">
              <h3>Tooling</h3>
              <p>
                The compiler includes a REPL, test runner, AST output, generated-code
                inspection, and bytecode compilation.
              </p>
            </div>
          </div>
          <div className="col col--4 margin-bottom--lg">
            <div className="featureCard">
              <h3>Standard Library</h3>
              <p>
                Start with JSON, HTML, filesystem, math, testing, and the prelude,
                then grow into larger application modules.
              </p>
            </div>
          </div>
        </div>
      </main>
    </Layout>
  );
}
