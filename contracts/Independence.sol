// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;


import "@chainlink/contracts/src/v0.7/ChainlinkClient.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Independence is ChainlinkClient {
    
    event ActivistRegistrationBegin(string user_id);
    event ActivistRegistrationFinish(string user_id);
    event ActivistUpdate(string user_id);
    event ActivistLost(string user_id);
    event ActivistWon(string user_id);

    struct VkUser {
        address payable user_address;
        uint balance;
        uint challenge_endtime;
        uint last_seen;
        bool participating;
        bool exists;
    }

    using Chainlink for Chainlink.Request;
    using SafeMath for uint;

    address private oracle;
    bytes32 private jobId;
    string private url_api = "https://api.vk.com/method/users.get?fields=last_seen&v=5.89&access_token=";
    uint private fee;


    mapping (bytes32 => string) private requests; // requestId => user_id
    mapping (string => VkUser) private activists; // user_id => struct VkUser
    string[] public user_ids;
    uint public number_of_activists = 0;

    modifier activistNotExists(string memory user_id) {
        require(!activists[user_id].exists);
        _ ;
    }

    modifier activistExists(string memory user_id) {
        require(activists[user_id].exists);
        _ ;
    }

    // for Kovan Network

    constructor(string memory access_token) public {
        setPublicChainlinkToken();
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10 ** 18;
        url_api = appendAccessToken(url_api, access_token);

    }

    function registerNewActivist(string memory user_id) public payable activistNotExists(user_id) returns (bytes32 requestId) {
        require(msg.value > 0);

        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.finishRegistration.selector);

        string memory full_api_url = append(url_api, user_id);
        
        request.add("get", full_api_url);
        request.add("path", "response.0.last_seen.time");

        activists[user_id] = VkUser(msg.sender, msg.value, 0, 0, false, true);

        requestId = sendChainlinkRequestTo(oracle, request, fee);

        requests[requestId] = user_id;

        emit ActivistRegistrationBegin(user_id);
    }


    function finishRegistration(bytes32 _requestId, uint last_seen) public recordChainlinkFulfillment(_requestId) {
        string memory user_id = requests[_requestId];

        VkUser storage user = activists[user_id];

        delete(requests[_requestId]);

        user.challenge_endtime = block.timestamp.add(5 minutes);
        user.last_seen = last_seen;
        user.participating = true;
        number_of_activists++;
        user_ids.push(user_id);

        emit ActivistRegistrationFinish(user_id);
    }

    function updateStatistics(string memory user_id) public activistExists(user_id) returns (bytes32 requestId) {
        require(activists[user_id].participating);

        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.getUpdate.selector);

        string memory full_api_url = append(url_api, user_id);

        request.add("get", full_api_url);
        request.add("path", "response.0.last_seen.time");

        requestId = sendChainlinkRequestTo(oracle, request, fee);

        requests[requestId] = user_id;

        emit ActivistUpdate(user_id);
    }

    function getUpdate(bytes32 _requestId, uint last_seen) public recordChainlinkFulfillment(_requestId) {
        string memory user_id = requests[_requestId];

        VkUser storage activist = activists[user_id];

        delete(requests[_requestId]);

        if (last_seen > activist.last_seen) {
            require(number_of_activists != 1);

            number_of_activists--;
            
            uint partForOthers = activist.balance / number_of_activists;

            activist.participating = false;
            activist.balance = 0;

            for (uint i = 0; i < user_ids.length; i++) {
                if (activists[user_ids[i]].participating) {
                    activists[user_ids[i]].balance += partForOthers;
                }
            }

            emit ActivistLost(user_id);

        } else if (block.timestamp >= activist.challenge_endtime) {
            activist.user_address.transfer(activist.balance);
            delete activists[user_id];
            number_of_activists--;

            emit ActivistWon(user_id);
        }
    }

    function appendAccessToken(string memory s1, string memory s2) internal pure returns (string memory) {
        return string(abi.encodePacked(s1, s2, "&user_ids="));
    }

    function append(string memory s1, string memory s2) internal pure returns (string memory) {
        return string(abi.encodePacked(s1, s2));
    }

}