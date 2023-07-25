# Dev server

![Dev server screenshot](https://github.com/darwin67/ex_inngest/assets/5746693/d8b80b54-5238-4c4b-bf76-6e15bee590a7)

Inngest provides a dev server you can run locally to aid with local development. You
can start the Dev server with:

```sh
npx inngest-cli@latest dev
```

This will download the latest version available and you should be able to access it
via http://localhost:8288.

If you prefer to download the CLI locally:

```sh
npm i -g inngest-cli
# or
npm i -g inngest-cli@<version>
```

then:

``` sh
inngest-cli dev
```

## Auto discovery

The Dev server will try to auto discover apps and functions via `http://localhost:3000/api/inngest`
by default. However, apps like Phoenix typically runs on port `4000`. You can provide the auto
discovery URL when starting the Dev server:

``` sh
npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest
```

This will tell the Dev server to look at `http://127.0.0.1:4000/api/inngest` to discover and
register apps/functions.

## Other options

For more options with the `Dev server`, use the `--help` option:

```bash
inngest-cli dev --help
```

### Note

The `inngest-cli` is a single executable binary. It's packaged and distributed with NPM for
the time being, but could change in the future.
