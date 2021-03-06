const { expect } = require("chai");
const { Contract } = require("ethers");
const { ethers } = require("hardhat");

describe("Locker", function () {
  let locker;
  let sender;
  let thief;
  let receiver;
  let erc1155;
  let erc721;

  beforeEach(async () => {

    // get some signers
    [sender, receiver, thief] = await ethers.getSigners();

    // deploy locker
    const Locker = await ethers.getContractFactory("Locker");
    locker = await Locker.deploy();
    await locker.deployed();

    // deploy test erc1155
    const ERC1155 = await ethers.getContractFactory("TestERC1155");
    erc1155 = await ERC1155.deploy();
    await erc1155.deployed();
    
    // deploy test erc721
    const ERC721 = await ethers.getContractFactory("TestERC721");
    erc721 = await ERC721.deploy();
    await erc721.deployed();

  })

  it("Should correctly store a token in the locker and allow retrieval", async function () {

    // set the approval on the token
    await erc1155.setApprovalForAll(locker.address, true);

    // drop off the token 2 using token 1 as key
    await locker.dropOff(
      erc1155.address,
      1,
      erc1155.address,
      2,
      1, { from: sender.address });

    // check the balances - sender should have 0 balance 
    expect(await erc1155.balanceOf(sender.address, 2)).to.equal(0);
    // receiber shoudl have 1 balance of the token being stored
    expect(await erc1155.balanceOf(locker.address, 2)).to.equal(1);

    // pick up the token 2 using token 1 as key
    await locker.pickUpTokenWithKey(
      1, { from: sender.address });
    
    // check the balances - sender should have 1 balance 
    expect(await erc1155.balanceOf(sender.address, 2)).to.equal(1);
    // locker shoudl have 0 balance of the token being stored
    expect(await erc1155.balanceOf(locker.address, 2)).to.equal(0);


  });

});
