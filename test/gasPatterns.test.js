const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GasPatterns", function () {
  let gp;
  beforeEach(async function () {
    const Factory = await ethers.getContractFactory("GasPatterns");
    gp = await Factory.deploy();
    await gp.deployed();
  });

  it("sumUintArrayCalldata should sum properly", async function () {
    const arr = [1, 2, 3, 4, 5];
    const sum = await gp.sumUintArrayCalldata(arr);
    expect(sum).to.equal(15);
  });

  it("increment uses unchecked and returns +1", async function () {
    const val = await gp.increment(41);
    expect(val).to.equal(42);
  });

  it("set and get packed flags", async function () {
    await gp.setPackedFlags(0x1234, 0x4321, true);
    const res = await gp.getPackedFlags();
    expect(res.v1).to.equal(0x1234);
    expect(res.v2).to.equal(0x4321);
    expect(res.f).to.equal(true);
  });

  it("mintOptimized increases supply", async function () {
    await gp.mintOptimized("0x000000000000000000000000000000000000dEaD", ethers.utils.parseEther("1"));
    const s = await gp.totalSupply();
    expect(s).to.equal(ethers.utils.parseEther("1"));
  });

  it("concatTwo returns concatenated bytes", async function () {
    const a = "0x68656c6c6f"; // "hello"
    const b = "0x20776f726c64"; // " world"
    const out = await gp.concatTwo(a, b);
    expect(out).to.equal("0x68656c6c6f20776f726c64");
  });
});
