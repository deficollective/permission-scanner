# Permission Analysis POC

### Dependencies

- Customised [Slither](https://github.com/deficollective/slither)

```shell
# create virtual env
python -m venv venv
# activate virtual environment
source venv/bin/activate
# install dependencies
pip install -r requirements.txt
# install & select solc compiler
solc-select install 0.8.20
solc-select use 0.8.20
# deactivate venv
source deactivate
```

```shell
python src/main.py <address> --etherscan-apikey=key --rpc-url https://mainnet.infura.io/v3/key

# Output in data.json
```
