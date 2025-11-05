# FireStarter

---
A starter application for a Phoenix Umbella project.

What do you get?

### Installed and configured packages

- [Credo](https://hexdocs.pm/credo)
- [Dialzyer](https://hexdocs.pm/dialyxir)
- [ExDoc](https://hexdocs.pm/ex_doc)
- [EctoErd](https://hexdocs.pm/ecto_erd)
- [Igniter](https://hexdocs.pm/igniter)

### Agentic Coding

- [Conductor](https://conductor.build/)
- `CLAUDE.md`
- [Tidewave](https://tidewave.ai/)
- [UsageRules](https://hexdocs.pm/usage_rules)

### Style Guide

- Macros; see [FireStarter Module](apps/fire_starter/lib/fire_starter.ex)

### CI and Deployment

- CI GitHub action

---

| Application                                   | Description                |
| --------------------------------------------- | -------------------------- |
| FireStarter [Docs](./fire_starter/index.html) | Business Application Logic |

## Setup

Prerequistes:

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Mise-en-place](https://mise.jdx.dev/)

Execute the following:

```sh
cp .env.template .env
# No configuration required
script/setup
```

## Documentation

```sh
mix docs
mix docs.open
```
