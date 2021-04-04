// This example code is designed to quickly deploy an example contract using Remix.

pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";

contract YourContract is ChainlinkClient {
  
    uint256[] public volume;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    address[] public stakers;

    mapping(address => uint256) balances;
    mapping(address => string) addrAPI;
    
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
    function fulfill(bytes32 _requestId, uint256 _volume) public recordChainlinkFulfillment(_requestId)
    {
        volume.push(_volume);
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

    function stake() 
    public
    payable {
      require(msg.value > 0, "Staking amount must be higher than 0");
      stakers.push(msg.sender);
      balances[0x9B38A28C1BfCC5B41D510E336cDbed35a46f0beb] += msg.value; //should normally be msg.sender but easier to put it together into stakingpool
    }

    function balanceOf(address _user) public view returns(uint256) {
      return balances[_user];
    }

    function setAPI(string memory _API) public {
      addrAPI[msg.sender] = _API;
    }

    function getGHG(string memory _API1, string memory _API2) public {
      require(keccak256(abi.encodePacked(_API1)) == keccak256(abi.encodePacked(_API2)), "You can't use the same API. Please change");
      requestVolumeData(_API1);
      requestVolumeData(_API2);
    }

    function compareGHG() public returns(uint256){
      require(volume[0] != 0 && volume[1] != 0, "Wait for Oracle to answer");
      if(volume[0] < volume[1]){
        //company1 wins
        balances[stakers[0]] += balanceOf(0x9B38A28C1BfCC5B41D510E336cDbed35a46f0beb);
        balances[0x9B38A28C1BfCC5B41D510E336cDbed35a46f0beb] -= balanceOf(0x9B38A28C1BfCC5B41D510E336cDbed35a46f0beb);
        return balances[stakers[0]];
      } else if(volume[0] > volume[1]){
        //company2 wins
        balances[stakers[1]] += balanceOf(0x9B38A28C1BfCC5B41D510E336cDbed35a46f0beb);
        balances[0x9B38A28C1BfCC5B41D510E336cDbed35a46f0beb] -= balanceOf(0x9B38A28C1BfCC5B41D510E336cDbed35a46f0beb);
        return balances[stakers[1]];
      } else {
        //do nothing
        return balances[0x9B38A28C1BfCC5B41D510E336cDbed35a46f0beb];
      }
    }
}