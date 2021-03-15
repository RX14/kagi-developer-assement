# Example Search Engine

An example search engine written for Kagi developer assessment.

[API Documentation](https://rx14.co.uk/search-engine-example-docs/)

## Installation

Running `shards build` will build an executable in `bin/search-engine`.

## Usage

This application requires a Redis server for caching. Provide the URL of the
Redis server in the `REDIS_URL` env var, similar to `REDIS_URL=redis://host:port`.
Running `bin/search-engine` will start the web server on `0.0.0.0:3000`.
Change the server bind address and port with `--bind` and `--port`.

## Development

### Design

The core of the search engine logic is the `Crawler` and `DateExtraction` classes. These
classes implement fetching the page, and extracting the date from the page respectively.
The `SearchEngine` class contains all the transient state (database connection) for the
search engine, and provides a coordination point for the high level tasks including
dispatching searches in parallel.
The API documentation (linked above) provides further details on these classes.

## Contributing

1. Fork it (<https://github.com/RX14/vladimir-prelovac-job-opportunity/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stephanie Wilde-Hobbs](https://github.com/RX14) - creator and maintainer
