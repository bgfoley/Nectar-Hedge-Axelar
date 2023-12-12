// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

const { ethers, upgrades } = require('hardhat');

async function main() {
  // Deploy MyToken
  const MyToken = await ethers.getContractFactory('MyToken');
  const myToken = await MyToken.deploy();
  await myToken.deployed();
  console.log('MyToken deployed to:', myToken.address);

  // Deploy MyContractA with MyToken's address as an argument
  const MyContractA = await ethers.getContractFactory('MyContractA');
  const myContractA = await MyContractA.deploy(myToken.address);
  await myContractA.deployed();
  console.log('MyContractA deployed to:', myContractA.address);

  // Deploy MyContractB with MyContractA's address as an argument
  const MyContractB = await ethers.getContractFactory('MyContractB');
  const myContractB = await MyContractB.deploy(myContractA.address);
  await myContractB.deployed();
  console.log('MyContractB deployed to:', myContractB.address);

  // If you want to upgrade a contract, you can use the following pattern
  // const upgradedMyContractA = await upgrades.upgradeProxy(myContractA.address, MyContractA);
  // console.log('MyContractA upgraded to:', upgradedMyContractA.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
