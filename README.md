# Maxi Gain - Multi Assets Strategy

Maxi gain is a multi asset strategy which covert the base asset into asset with the high yield and deposit that to reaper vault.

## Set up

```shell
git clone git@github.com:0xBcamp/Sept23_Granary_Strategy.git

cd Sept23_Granary_Strategy

forge install

```

- Now create .env file and add your RPC_URL. see .env.example

```
forge test
```

### Completed tasks

- [x] setup vault contract
- [x] deposit and borrow from aave successful
- [x] Fork test environment setup
- [x] Vault test for Deposit successful
- [x] Handled want token decimals for deposit

### TODO

- [ ] Complete vault test
- [ ] Maintain the collateral ratio to 200% while borrowing from aave
- [ ] Monitor health factor on every deposit, if health factor is < 2e18 then calculate the amount which can be repaid to rise the health factor to 2e18. We are still not sure how much min health factor should we maintain.
- [ ] Write test for strategy throughly
- [ ] Monitor if there is loss in the startegy by subtracting ReaperDeposit - Debt = profit/loss. If loss what to do ?
