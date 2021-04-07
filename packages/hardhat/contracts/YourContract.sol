// This example code is designed to quickly deploy an example contract using Remix.

pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "hardhat/console.sol";

contract YourContract is ChainlinkClient{
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
  
    address payable[] public stakerReg;
    address public stakingpool = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    uint256[] public oracleData;
    uint256[] public relativeGHG;
    address[] public requesters;

    mapping(address => uint256) balances;
    mapping(address => uint256[] ) dataToAddress;
    mapping(address => bool) stakers;
    
    //EVENTS

    event RequesterToData(address indexed _requester, uint256 indexed _oracleData);
    event SetData(address indexed _requester, uint256 indexed _data);
    event GetRelChange(uint256 _relChange);
    event PayoutTo(address _winner, uint _amount);

    /**
     * Network: Kovan
     * Chainlink - 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e
     * Chainlink - 29fa9aa13bf1468788b7cc4a500a45b8
     * Fee: 0.1 LINK
     */
     
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
    
    
    function requesterToData() public {
        require(requesters.length == oracleData.length);
        for (uint256 ii = 0; ii < requesters.length; ii++) {
            dataToAddress[requesters[ii]].push(oracleData[ii]);
            emit RequesterToData(_requesters[ii], _oracleData[ii]);
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
      dataToAddress[msg.sender] = _data;
      SetData(msg.sender, _Data);
    }

    /**
    * Get data. Only with caller address.
     */
    function getData() public view returns (uint256[] memory) {
        return dataToAddress[msg.sender];
    }
    
    
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
    
    
    function stake() 
    public
    payable {
      require(msg.value > 0, "Staking amount must be higher than 0");
      stakers[msg.sender] = true;
      stakerReg.push(msg.sender);
      balances[stakingpool] += msg.value; //should normally be msg.sender but easier to put it together into stakingpool
    }

    function balanceOf(address _user) public view returns(uint256) {
      return balances[_user];
    }

    function compareGHG() public{
      require(relativeGHG[0] != 0 && relativeGHG[1] != 0, "Wait for Oracle to answer");
      if(relativeGHG[0] > relativeGHG[1]){ //has a higher relative negative impact on GHG
        //company1 wins
        balances[stakerReg[0]] += balanceOf(stakingpool);
        balances[stakingpool] -= balanceOf(stakingpool);
        stakerReg[0].transfer(balanceOf(stakerReg[0]));
        emit PayoutTo(stakerReg[0], balanceOf(stakerReg[0]) );
        balances[stakerReg[1]] -= balanceOf(stakerReg[1]);
      } else if(relativeGHG[0] < relativeGHG[1]){
        //company2 wins
        balances[stakerReg[1]] += balanceOf(stakingpool);
        balances[stakingpool] -= balanceOf(stakingpool);
        stakerReg[1].transfer(balanceOf(stakerReg[1]));
        emit PayoutTo(stakerReg[1], balanceOf(stakerReg[1]) );
        balances[stakerReg[1]] -= balanceOf(stakerReg[1]);
      } else {
        //do nothing
      }
    }
}

