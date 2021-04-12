# Reduction of Greenhouse gas (GHG) emissions through incentivization

## Goal: Automate carbon tax, increasing transparency, security, and speed.

## Approaches

### Idea 1: Companies stake capital on reward/penalized base (MVP was implemented)

Staking between companies acts as incentive to reduce emissions
- Those whose relative emissions increase over time are penalized
- Those whose relative emissions decrease over time are rewarded

#### Pro
- Has direct incentive, because companies most likely reinvest money into renewable energies with less emissions to be still eligible for rewards
- Competition between companies?

#### Con
Unclear what happens if all the participants have a low carbon emission
General public doesn’t get benefits from it, because it is reinvested only in the company.
Harder to implement?

### Idea 2: Have companies stake and compete for rewards based on their emissions (MVP was implemented)

For example two companies are given a quarter year to reduce GHG to a relative amount. The one that manages to reduce their GHG more will get the stake of the other company.


### Idea 3: Governance protocol decides the spending (Eventual future implementation)

Proof of Humanity to reduce manipulation (sybil resistance), also the proper citizens vote for their local expenditure

#### Pro
- Local communities could directly vote for carbon-emission related projects. 
- Fairest?  Option on what to do with newly taxed money
- Easier to implement?
#### Con
- Democracy is very slow.
- Potential disputes about funding of projects.

### Additional: NFT- additional reputation layer on top of the already transparent emissions. (Eventual future implementation)

Extends all ideas should time allow


# 🏃 Quick Start

```bash
git clone https://github.com/GiraeffleAeffle/ChainlinkHackathonSpring2021.git

cd ChainlinkHackathonSpring2021
```

```bash

yarn install

```

```bash

yarn start

```

> in a second terminal window:

```bash
cd ChainlinkHackathonSpring2021
yarn deploy

```
> In the browser app

stake()
* First both will stake ETH in the smart contract which will be send to Aave to be exchanged for aWETH.

setData() OR requestVolumeData() and requesterToData()

* After that the data will be requested from the external API that we chose, by chainlink. However, the API only refreshes every hour. That’s why I will set GHG values manually. In this case I will set a GHG value of 100 and the following 50 for company A and values of 100 and 80 for company B. 

GetRelChange()

* Next the relative change of the GHG data will be calculated, which is 50 for company A and 20 for company B. 

rewardPenalize()

* After that the average of the GHG data will be taken in this case 35 to form a threshold to determine which companies will be penalized and which ones will be rewarded. The stake of the penalized company will be kept (Company B).

approveERC20s()

* Next the ERC20 Tokens like the aWETH and WETH have to be approved by the rewarded company B, so the WETHGateway  is allowed to use them.

payOut()

* Finally the stake of the penalized company B and the one from the rewarded company A is paid out to the rewarded company A.
