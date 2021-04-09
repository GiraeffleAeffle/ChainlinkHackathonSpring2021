pragma solidity >=0.6 <0.9.0;
//SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
//import "@aave/protocol-v2/contracts/misc/WETHGateway.sol";
import "@aave/protocol-v2/contracts/misc/interfaces/IWETHGateway.sol";
//import "@aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "@aave/protocol-v2/contracts/interfaces/IAToken.sol";
//import "hardhat/console.sol";

//, IAToken
contract YourContract is ChainlinkClient {
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
  
    address payable[] public stakerReg;
    address public stakingpool = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    uint256[] public oracleData;
    uint256[] public relativeGHG;
    uint256 public averageRelGHGV;
    address[] public requesters;
    address[] public penalized;
    address[] public rewarded;

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
    
    constructor() public {
    setPublicChainlinkToken();
    oracle = 0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b;
    jobId = "c7dd72ca14b44f0c9b6cfcd4b7ec0a2c";
    fee = 0.1 * 10 ** 18; // 0.1 LINK
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

    /**
    * Set "oracle" data. 
    * Just for testing purpose without the need to use an oracle.
     */
    function setData(uint256 _data) public {
      dataToAddress[msg.sender].push(_data);
      SetData(msg.sender, _data);
    }

    /**
    * Get data. Only with caller address.
     */
    function getData() public view returns (uint256[] memory) {
        return dataToAddress[msg.sender];
    }
    
    /**
    * Stake ETH
     */
    function stake() 
    public
    payable {
      require(msg.value > 0, "Staking amount must be higher than 0");
      stakers[msg.sender] = true;
      stakerReg.push(msg.sender);
      gateway.depositETH(msg.sender, 0);
      balances[msg.sender] += aWETH.balanceOf(msg.sender);
    }
 /*
    * Get the relative Change of the GHG values.
    * TODO: Set one starting value and take the average of the following. Eventually needs to be signed integer
    */
    function getRelChange() public {
        for (uint8 ii= 0;ii<stakerReg.length;ii++) {
            for (uint8 jj=0; jj<dataToAddress[stakerReg[ii]].length;jj++) {
                if (jj == 0) {
                    relativeGHG[ii] = dataToAddress[stakerReg[ii]][jj]; // expecting that second value is lower than first
                    emit GetRelChange(relativeGHG[ii]);
                } else {
                    relativeGHG[ii] -= dataToAddress[stakerReg[ii]][jj]; // expecting that second value is lower than first
                    emit GetRelChange(relativeGHG[ii]);    
                }
            }
        }
    }

    function averageRelGHG() internal {
        for(uint16 ii=0; ii<relativeGHG.length; ii++) {
            averageRelGHGV += relativeGHG[ii];
        }
        averageRelGHGV /= relativeGHG.length;
    }

    /*
    * If your relative GHG reduction is over the average value you get a reward
    * paid by the ones under the average. 
    * TODO: Events
    */
    function payOrGetPaid() public {
        averageRelGHG();
        for(uint256 jj=0; jj<relativeGHG.length;jj++) {
            if(relativeGHG[jj] < averageRelGHGV) {
                rewarded.push(stakerReg[jj]);
            }  else {
                penalized.push(stakerReg[jj]);
                balances[stakingpool] += balances[penalized[jj]];
                balances[penalized[jj]] = 0;
            }
        }
        for(uint256 ii=0; ii<rewarded.length;ii++) {
            balances[rewarded[ii]] += balances[stakingpool]/rewarded.length;
            //send eth to address ?
        }
        balances[stakingpool] = 0;
    }
    
    /**
    * Compare GHG values and send them to the winner address
    * TODO: Collect penalties from the others to pay the winner
    * TODO: Events
    */
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


// AAVE integration missing
// deposit ETH to get aWETH