# Flask-based Survey Application on Kubernetes

This project deploys a Flask-based Survey Application on Kubernetes using Kind. The application survey users for questions on a political candidate (e.g., Trump vs. Biden) and display the results in a dashboard. The deployment uses Bash scripting for logs, error handling and updating the Kubernetes cluster easily.

## Prerequisites

- Docker
- Kubernetes (Kind)
- Helm
- Python
- Linux machine

## Usage

All of the project can be managed by the candidateapp.sh script.

Flags:
- -i Install
- -d Uninstall
- -f <arg> Upgrading Flask replicas to have 1-5 replicas
- -m <arg> Upgrading Mongodb replicas to have 1-5 replicas
- -h Display help

```bash
EXAMPLE USAGES

# Installing the application-
./candidateapp -i

# Deleting the application-
./candidateapp -i -d

# Upgrading Flask and Mongodb replicas to 3 and 3-
 ./candidateapp -i -f 3 -m 3
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for any improvements or bug fixes.


## License

[MIT](https://choosealicense.com/licenses/mit/)
