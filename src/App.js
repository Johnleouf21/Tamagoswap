import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import Contract from './artifacts/contracts/TamagoSwap.sol/TamagoSwap.json';
import React from 'react';
import './App.css';

const address = "0xa166a057B75161f4412608ffA5c97Ba7d10Fb66f";
const erc721 = require("./artifacts/@openzeppelin/contracts/token/ERC721/ERC721.sol/ERC721.json");

function App() {

  const [loader, setLoader] = useState(true);
  const [accounts, setAccounts] = useState([]);
  const [balance, setBalance] = useState();
  const [data, setData] = useState({});
  const [secondUser, setSecondUser] = useState("");
  const [nftAddresses, setNftAddresses] = useState("");
  const [nftIds, setNftIds] = useState("");
  const [approved, setApproved] = useState(null);
  const [signer, setSigner] = useState(null);
  const [txLoad, setTxLoad] = useState(false);

  useEffect(() => {
    getAccounts();
    setLoader(false);
    fetchData(); 
  }, [])


  async function fetchData() {
    if(typeof window.ethereum !== 'undefined') {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const contract = new ethers.Contract(address, Contract.abi, provider);

      try {
       

        const object = {}
        setData(object);
      }
      catch(err) {
        console.log(err);
      }
    }
  }

  async function getAccounts() {
    if(typeof window.ethereum !== 'undefined') {
      let accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
      setAccounts(accounts);
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const balance = await provider.getBalance(accounts[0]);
      const balanceInEth = ethers.utils.formatEther(balance);
      setBalance(balanceInEth);
    }
  }

  const approveNft = async (nftAddresses, nftIds) => {
    const tokenContract = new ethers.Contract(nftAddresses, erc721.abi, signer);
    const tx = await tokenContract.approve(address, nftIds);
    setTxLoad(true);
    const result = await tx.wait();
    setTxLoad(false);
    setApproved({nftAddresses, nftIds: nftIds});
  }

  const proposeSwap = async () => {
    const contract = new ethers.Contract(address, Contract.abi, signer);
    const tx = await contract.proposeSwap(secondUser, [approved.nftAddresses], [approved.nftIds]);
    setTxLoad(true);
    const result = await tx.wait();
    setTxLoad(false);
        
    }
  

    async function acceptSwap(secondUser, nftAddresses, nftIds) {
        if(typeof window.ethereum !== 'undefined') {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const contract = new ethers.Contract(address, Contract.abi, provider);

        contract.acceptSwap(secondUser, nftAddresses, nftIds).then(() => {
            console.log("Swap accepted");
        }
            ).catch(err => {
            console.log(err);
        }
            );
        }
    }

    return (
        <div className="root ">
                
                    <section className="hero">
                        <div className="logo"><br></br>
                        </div>
                        <div className="heroG">
                        <div><br></br><br></br>
                              <div className="App">
                              </div>
                                <h1>Welcome on <span className="red">TAMAGOSWAP</span></h1>
                                <p>
                                  <input type="text" onChange={(e) => setSecondUser(e.target.secondUser)} mt="2rem" placeholder='Select the starting hour'/>
                                  <input type="text" onChange={(e) => setNftAddresses(e.target.nftAddresses)} mt="2rem" placeholder='Select the starting hour'/>
                                  <input type="text" onChange={(e) => setNftIds(e.target.nftIds)} mt="2rem" placeholder='Select the starting hour'/>                   
                                  <button className="btn" onClick={proposeSwap}>propose swap</button>
                              </p></div>
                        </div>
                        <div className='heroD'>
                          <button className="btn" onClick={getAccounts}>CONNECT WALLET</button>
                        </div>
                    </section>
            </div>
    );

}

export default App;