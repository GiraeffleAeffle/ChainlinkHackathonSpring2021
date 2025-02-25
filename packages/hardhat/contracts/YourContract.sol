pragma solidity >=0.6 <0.9.0;
//SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "@aave/protocol-v2/contracts/misc/interfaces/IWETHGateway.sol";
import "@aave/protocol-v2/contracts/interfaces/IAToken.sol";
import "hardhat/console.sol";

contract YourContract is ChainlinkClient {
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
  
    address payable[] public stakerReg;
    uint256[] public oracleData;
    uint256[] public relativeGHG;
    uint256 public averageRelGHGV;
    address[] requesters;
    address[] public penalized;
    address[] public rewarded;
    uint256 lastAWETHBalance = 0;

    mapping(address => uint256) balances;
    mapping(address => uint256[] ) dataToAddress;
    mapping(address => bool) stakers;
    
    //EVENTS

    event RequesterToData(address indexed _requester, uint256 indexed _oracleData);
    event SetData(address indexed _requester, uint256 indexed _data);
    event GetRelChange(uint256 _relChange);
    event PayoutTo(address _winner, uint _amount);
     
      // --- KOVAN --
    IWETHGateway gateway = IWETHGateway(0xf8aC10E65F2073460aAD5f28E1EABE807DC287CF);
    IAToken aWETH = IAToken(0x87b1f4cf9BD63f7BBD3eE1aD04E8F52540349347);
    IAToken WETH = IAToken(0xd0A1E359811322d97991E03f863a0C30C2cF029C);
    
    constructor() public {
    setPublicChainlinkToken();
    oracle = 0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b;
    jobId = "c7dd72ca14b44f0c9b6cfcd4b7ec0a2c";
    fee = 0.1 * 10 ** 18; // 0.1 LINK
  }
  
   /**
    * Stake ETH and deposit into Aave to get back aWETH
     */
    function stake() 
    public
    payable {
      require(msg.value > 0, "Staking amount must be higher than 0");
      stakers[msg.sender] = true;
      stakerReg.push(msg.sender);
      lastAWETHBalance = aWETH.balanceOf(address(this)); //before deposit
      gateway.depositETH{value: msg.value}(address(this), 0); //Exchanges ETH for aWETH
      balances[msg.sender] += aWETH.balanceOf(address(this)) - lastAWETHBalance;
    }
    
    
    /**
    * Set "oracle" data. 
    * Just for testing purpose without the need to use an oracle.
     */
    function setData(uint256 _data) public {
      dataToAddress[msg.sender].push(_data);
      SetData(msg.sender, _data);
    }
    
    /*
    * Get the relative Change of the GHG values.
    * TODO: Set one starting value and take the average of the following. Eventually needs to be signed integer
    */
    function getRelChange() public {
        for (uint256 ii= 0;ii<stakerReg.length;ii++) {
            for (uint256 jj=0; jj<dataToAddress[stakerReg[ii]].length;jj++) {
                if (jj == 0) {
                    relativeGHG.push(dataToAddress[stakerReg[ii]][jj]); // expecting that second value is lower than first
                    emit GetRelChange(relativeGHG[ii]);
                } else {
                    relativeGHG[ii] -= dataToAddress[stakerReg[ii]][jj]; // expecting that second value is lower than first
                    emit GetRelChange(relativeGHG[ii]);    
                }
            }
        }
    }
    
    /*
    * Calculates the relative GHG. 
    * If the relative GHG reduction of a company is over the average value you get a reward
    * paid by the ones under the average. 
    * TODO: Events
    */
    function rewardPenalize() public {
        averageRelGHG();
        for(uint256 jj=0; jj<relativeGHG.length;jj++) {
            if(relativeGHG[jj] > averageRelGHGV) { // Still something wrong // !!!!! relativeGHG[jj] > averageRelGHGV !!!!!
                rewarded.push(stakerReg[jj]);
            }  else {
                penalized.push(stakerReg[jj]);
            }
        }
        penalize();
    }
    
    /*
    * Take the stake of the penalized company.
    */
    function penalize() internal {
        for(uint256 ii=0; ii<penalized.length;ii++) {
            balances[address(this)] += balances[penalized[ii]];
            balances[penalized[ii]] = 0;
        }
    }
    
    /*
    * Approve aWETH and WETH that the Aave gateway contract can spend aWETH and withdraw ETH into the contract
    */
    function approveERC20s() public {
        aWETH.approve(0xf8aC10E65F2073460aAD5f28E1EABE807DC287CF, type(uint).max); // infinite approval / not sure if this works
        WETH.approve(0xf8aC10E65F2073460aAD5f28E1EABE807DC287CF, type(uint).max); 
    }
    
    /*
    * Pay out ETH to the rewarded companies
    */
    function payOut() public {
        for(uint256 ii=0; ii<rewarded.length;ii++) {
            if (rewarded[ii] == msg.sender) {
                balances[msg.sender] += balances[address(this)]/rewarded.length;
                gateway.withdrawETH(balances[msg.sender], msg.sender);
                balances[address(this)] -= balances[address(this)]/rewarded.length;
                emit PayoutTo(msg.sender, balances[msg.sender]);
                balances[msg.sender] = 0;
            }
        }
    }
    
     /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestVolumeData(string memory _API) public returns (bytes32 requestId) 
    {
        require(stakers[msg.sender], "Not a staker");
        requesters.push(msg.sender);
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", _API);
        
        // Set the path to find the desired data in the API response, where the response format is:
        request.add("path", "list.0.components.co");
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _data) public recordChainlinkFulfillment(_requestId)
    {
      oracleData.push(_data);
      relativeGHG.push(0);
    }
    
    /**
    * Map oracleData to requesters
     */
    function requesterToData() public {
        require(requesters.length == oracleData.length);
        for (uint256 ii = 0; ii < requesters.length; ii++) {
            dataToAddress[requesters[ii]].push(oracleData[ii]);
            emit RequesterToData(requesters[ii], oracleData[ii]);
        }
        delete requesters;
        delete oracleData;
    }
    
    /**
     * Withdraw LINK from this contract
     * 
     * NOTE: DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
     * THIS IS PURELY FOR EXAMPLE PURPOSES ONLY.
     */
    function withdrawLink() external {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }

    
    /*
    * TESTING FUNCTION
    */
    function prepareData() public {
        stakerReg.push(0xD8631E88f5A330FAF7424Def118A389E8405895c);
        stakerReg.push(0x497f35b5a2859343CdAA98aeDb7605B2c46136d7);
        dataToAddress[0xD8631E88f5A330FAF7424Def118A389E8405895c].push(100);
        dataToAddress[0xD8631E88f5A330FAF7424Def118A389E8405895c].push(50);
        dataToAddress[0x497f35b5a2859343CdAA98aeDb7605B2c46136d7].push(100);
        dataToAddress[0x497f35b5a2859343CdAA98aeDb7605B2c46136d7].push(80);
    }

    /**
    * Get data. Only with caller address.
     */
    function getData() public view returns (uint256[] memory) {
        return dataToAddress[msg.sender];
    }
    
    
    /*
    * returns the balance of aWETH in the account.
    */
    function aWethBalance() public view returns(uint256) {
        return aWETH.balanceOf(address(this));
    }
    
    /*
    * Calculates the average relative GHG data to determine a threshold which companies are rewarded or penalized.
    */
    function averageRelGHG() internal {
        for(uint16 ii=0; ii<relativeGHG.length; ii++) {
            averageRelGHGV += relativeGHG[ii];
        }
        averageRelGHGV /= relativeGHG.length;
    }
    
    /**
    * Compare GHG values and send them to the winner address
    * TODO: Collect penalties from the others to pay the winner
    * TODO: Events
    */
    /*
    function compareGHG() public{
      uint256 maxValue = 0;
      uint256 position = 0;
      for(uint256 jj=0; jj<relativeGHG.length-1;jj++) {
          if(relativeGHG[jj] > relativeGHG[jj+1]) {
              if (relativeGHG[jj] > maxValue) {
                  maxValue = relativeGHG[jj];
                  position = jj;
              }
          } else {
              if (relativeGHG[jj+1] > maxValue) {
                  maxValue = relativeGHG[jj+1];
                  position = jj+1;
              }
          }
      }
      stakerReg[position].transfer(balances[stakingpool]);
    }
}
*/
}