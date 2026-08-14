# Campdoc

Campdoc is a private, file-first delivery tool. A sender adds files, a recipient, and a note. The recipient gets a private link, and the sender can see when the delivery is opened or downloaded.

## Documentation

Choose the guide that matches what you're doing:

- **Tutorial:** [Run Campdoc locally](docs/tutorials/getting-started.md)
- **How-to guide:** [Deploy Campdoc](docs/how-to/deploy.md)
- **Reference:** [Configuration](docs/reference/configuration.md)
- **Explanation:** [Private delivery and storage security](docs/explanation/security-model.md)

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
