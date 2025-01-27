# GitHub binary downloader

Downloads release binaries from github repos (extracts them from archives if necessary too).

## Features
- single sh file
- single command
- auto platform + architecture detection
- auto extract binary from archives
- download from tagged releases too

It's just a single sh file, that don't necessarily need to be installed before. Just run command in terminal and it will download targeted binary from github repos.

# Usage

### Download latest release:
```sh
curl -SsfL https://marcisbee.github.io/gh/dl.sh | bash -s -- --repo caddyserver/caddy
```

### Download specific tag:
```sh
curl -SsfL https://marcisbee.github.io/gh/dl.sh | bash -s -- --repo caddyserver/caddy --tag v2.9.1
```

---

You can also use versioned url if security is on the line:

```sh
curl -SsfL https://raw.githubusercontent.com/Marcisbee/gh/refs/tags/v1.0.1/dl.sh | bash -s -- --repo caddyserver/caddy
```

# Motivation
I was sick and tired of apps like brew, just needed a simple app that pulls release binaries from github. Saving them in current directory was also a plan so that it's easy to preload binaries in e.g. github actions.

# License
[MIT](LICENCE) &copy; [Marcis Bergmanis](https://twitter.com/marcisbee)
