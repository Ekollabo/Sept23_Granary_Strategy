# Maxi Gain - Multi Asset Strategy

MaxiVault is a smart contract-based solution that provides users with a secure and flexible way to manage their funds in DeFi. It offers features such as depositing, earning, and withdrawing funds while implementing risk management controls, deposit fees, and TVL caps. This README provides an overview of the MaxiVault project, how to use it, and important details for developers and users.

Maxi gain is a multi-asset strategy that converts the base asset into an asset with a high yield and deposits that into the reaper vault.

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
