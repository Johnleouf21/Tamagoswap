import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import Contract from './artifacts/contracts/TamagoSwap.sol/TamagoSwap.json';
import React from 'react';
import './App.css';

const address = "0xa166a057B75161f4412608ffA5c97Ba7d10Fb66f";

function App() {

  const [loader, setLoader] = useState(true);
  const [accounts, setAccounts] = useState([]);
  const [balance, setBalance] = useState();
  const [data, setData] = useState({});

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
        const totalSupply = await contract.totalSupply();
        const wlSalePrice = await contract.wlSalePrice();
        const wlSalePrice2 = await contract.wlSalePrice2();
        const publicSalePrice = await contract.publicSalePrice();

        const object = {"wlSalePrice": String(wlSalePrice),"wlSalePrice2": String(wlSalePrice2),"publicSalePrice": String(publicSalePrice),"totalSupply": String(totalSupply)}
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

  async function proposeSwap(secondUser, nftAddresses, nftIds) {
    if(typeof window.ethereum !== 'undefined') {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const contract = new ethers.Contract(address, Contract.abi, provider);

      contract.proposeSwap(secondUser, nftAddresses, nftIds).then(() => {
        console.log("Swap proposed");
      }
        ).catch(err => {
        console.log(err);
      }
        );
    
    }
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