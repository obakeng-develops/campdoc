# Campdoc

Campdoc sends files to one recipient through an expiring, revocable link. A sender can add a note and see when the delivery is first opened or when any file is first downloaded.

## Documentation

Choose the guide that matches what you're doing:

- **Tutorial:** [Run Campdoc locally](docs/tutorials/getting-started.md)
- **How-to guide:** [Deploy Campdoc](docs/how-to/deploy.md)
- **Reference:** [Configuration](docs/reference/configuration.md)
- **Reference:** [API stability](docs/reference/api-stability.md)
- **Explanation:** [Delivery and storage security](docs/explanation/security-model.md)

## Contributing

Run the project checks before opening a pull request:

```sh
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit check
bin/importmap audit
```

Campdoc is available under the [MIT License](LICENSE). See [SECURITY.md](SECURITY.md) to report a vulnerability privately.
