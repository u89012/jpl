---
id: std-html
title: html
---

# `html`

`html` provides HTML nodes, rendering, and a builder-style API for structured output.

## `html.tag(name, attrs = {}, children = [], body = nil)`

Creates an HTML node table explicitly.

Use this when you want a low-level node representation without going through the builder API.

## `html.escape(value)`

Escapes a value for safe HTML text output.

Special characters such as `&`, `<`, `>`, and quotes are converted to entity form.

## `html.render(value)`

Renders an HTML node or node tree to a string.

It accepts individual nodes, arrays of nodes, and primitive text values.

## `html.Builder()`

Creates a builder that collects HTML nodes internally.

This is the main high-level API for composing HTML programmatically in Jaya.

## `builder.tag(name, content = nil, **attrs, &body)`

Builds a tag node on the current builder target.

Use this when you want a generic tag helper instead of a generated tag-specific method.

## Generated tag methods

The builder also exposes common tag methods such as:

- `div(...)`
- `span(...)`
- `h1(...)`
- `ul(...)`
- `li(...)`

These methods follow the same calling shape as `builder.tag(...)`, but with the tag name already fixed.

## `builder.include(path)`

Adds a stylesheet or script include based on the file path.

Paths ending in `.css` render as `<link rel="stylesheet" ...>`, while `.js` and `.mjs` render as `<script src="..."></script>`.

## `builder.root()`

Returns the current root node array for the builder.

Use this if you need access to the retained node tree before rendering.

## `builder.render()`

Renders the builder’s current node tree to HTML text.

This is the explicit render call for the builder.

## `builder.s()`

Returns the rendered HTML string for the builder.

This is the short string-oriented form of `builder.render()`.
