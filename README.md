# Flask-based Survey Application on Kubernetes

This project deploys a Flask-based Application on Kubernetes using Kind. The application asks users for which animal they like more (a dog or a cat) and display the results in a graph. The deployment uses Bash scripting for logs, error handling and updating the Kubernetes cluster easily.

## Prerequisites

- Docker
- Kubernetes (Kind)
- Helm
- Python
- Linux machine

## Usage

All of the project can be managed by the deploy.sh script.

Flags:
- -i Install
- -d Uninstall
- -f <arg> Upgrading Flask replicas to have 1-5 replicas
- -m <arg> Upgrading Mongodb replicas to have 1-5 replicas
- -h Display help

```bash
EXAMPLE USAGES

# First, give the script executable permissions.
chmod a+x

# Installing the application-
./deploy.sh -i

# Deleting the application-
./deploy.sh -i -d

# Upgrading Flask and Mongodb replicas to 3 and 3-
 ./deploy.sh -i -f 3 -m 3
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for any improvements or bug fixes.


## License

[MIT](https://choosealicense.com/licenses/mit/)
