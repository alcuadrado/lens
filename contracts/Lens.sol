// SPDX-License-Identifier: MIT
// solhint-disable-next-line compiler-version
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "usingtellor/contracts/UsingTellor.sol";
import "hardhat/console.sol";

interface TellorMaster {
    function getUintVar(bytes32 _data) external view returns (uint256);

    function getNewValueCountbyRequestId(uint256 _requestId)
        external
        view
        returns (uint256);

    function getTimestampbyRequestIDandIndex(uint256 _requestID, uint256 _index)
        external
        view
        returns (uint256);

    function retrieveData(uint256 _requestId, uint256 _timestamp)
        external
        view
        returns (uint256);

    function getAddressVars(bytes32 _data) external view returns (address);

    function getRequestUintVars(uint256 _requestId, bytes32 _data)
        external
        view
        returns (uint256);
}

/**
 * @title Tellor Lens
 * @dev A contract to aggregate and simplify calls to the Tellor oracle.
 **/
contract Lens is UsingTellor {
    TellorMaster public master;

    struct DataID {
        uint256 id;
        string name;
        uint256 granularity;
    }

    struct Value {
        uint256 id;
        string name;
        uint256 timestamp;
        uint256 value;
    }

    address private admin;

    DataID[] public dataIDs;

    constructor(address payable _master, DataID[] memory _dataIDs)
        UsingTellor(_master)
    {
        master = TellorMaster(_master);
        admin = msg.sender;

        for (uint256 i = 0; i < _dataIDs.length; i++) {
            dataIDs.push(_dataIDs[i]);
        }
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "not an admin");
        _;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function replaceDataIDs(DataID[] memory _dataIDs) external onlyAdmin {
        delete dataIDs;
        for (uint256 i = 0; i < _dataIDs.length; i++) {
            dataIDs.push(_dataIDs[i]);
        }
    }

    function setDataID(uint256 _id, DataID memory _dataID) external onlyAdmin {
        dataIDs[_id] = _dataID;
    }

    function pushDataID(DataID memory _dataID) external onlyAdmin {
        dataIDs.push(_dataID);
    }

    function dataIDS() external view returns (DataID[] memory) {
        return dataIDs;
    }

    /**
     * @return Returns the current reward amount.
     */
    function currentReward() external view returns (uint256) {
        uint256 timeDiff =
            block.timestamp -
                master.getUintVar(keccak256("timeOfLastNewValue"));
        uint256 rewardAmount = 1e18;

        uint256 rewardAccumulated = (timeDiff * rewardAmount) / 300; // 1TRB every 6 minutes.

        uint256 tip = master.getUintVar(keccak256("currentTotalTips")) / 10; // Half of the tips are burnt.
        return rewardAccumulated + tip;
    }

    /**
     * @param _dataID is the ID for which the function returns the values for. When dataID is negative it returns the values for all dataIDs.
     * @param _count is the number of last values to return.
     * @return Returns the last N values for a request ID.
     */
    function getLastValues(uint256 _dataID, uint256 _count)
        public
        view
        returns (Value[] memory)
    {
        uint256 totalCount = master.getNewValueCountbyRequestId(_dataID);
        if (_count > totalCount) {
            _count = totalCount;
        }
        Value[] memory values = new Value[](_count);
        for (uint256 i = 0; i < _count; i++) {
            uint256 ts =
                master.getTimestampbyRequestIDandIndex(
                    _dataID,
                    totalCount - i - 1
                );
            uint256 v = master.retrieveData(_dataID, ts);
            values[i] = Value({
                id: _dataID,
                name: dataIDs[_dataID].name,
                timestamp: ts,
                value: v
            });
        }

        return values;
    }

    /**
     * @param count is the number of last values to return.
     * @return Returns the last N values for a data IDs.
     */
    function getAllLastValues(uint256 count)
        external
        view
        returns (Value[] memory)
    {
        Value[] memory values = new Value[](count * dataIDs.length);
        for (uint256 i = 0; i < dataIDs.length; i++) {
            Value[] memory v = getLastValues(dataIDs[i].id, count);
            for (uint256 ii = 0; ii < v.length; ii++) {
                values[i + ii] = v[ii];
            }
        }

        return values;
    }

    /**
     * @return Returns the contract deity that can do things at will.
     */
    function _deity() external view returns (address) {
        return master.getAddressVars(keccak256("_deity"));
    }

    /**
     * @return Returns the contract owner address.
     */
    function _owner() external view returns (address) {
        return master.getAddressVars(keccak256("_owner"));
    }

    /**
     * @return Returns the contract pending owner.
     */
    function pendingOwner() external view returns (address) {
        return master.getAddressVars(keccak256("pending_owner"));
    }

    /**
     * @return Returns the contract address that executes all proxy calls.
     */
    function tellorContract() external view returns (address) {
        return master.getAddressVars(keccak256("tellorContract"));
    }

    /**
     * @param _dataID is the ID for which the function returns the total tips.
     * @return Returns the current tips for a give request ID.
     */
    function totalTip(uint256 _dataID) external view returns (uint256) {
        return master.getRequestUintVars(_dataID, keccak256("totalTip"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks the last time when a value was submitted.
     */
    function timeOfLastNewValue() external view returns (uint256) {
        return master.getUintVar(keccak256("timeOfLastNewValue"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks the total number of requests from user thorugh the addTip function.
     */
    function requestCount() external view returns (uint256) {
        return master.getUintVar(keccak256("requestCount"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks the total oracle blocks.
     */
    function _tBlock() external view returns (uint256) {
        return master.getUintVar(keccak256("_tBlock"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks the current block difficulty.
     *
     */
    function difficulty() external view returns (uint256) {
        return master.getUintVar(keccak256("difficulty"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable is used to calculate the block difficulty based on
     * the time diff since the last oracle block.
     */
    function timeTarget() external view returns (uint256) {
        return master.getUintVar(keccak256("timeTarget"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks the highest api/timestamp PayoutPool.
     */
    function currentTotalTips() external view returns (uint256) {
        return master.getUintVar(keccak256("currentTotalTips"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks the number of miners who have mined this value so far.
     */
    function slotProgress() external view returns (uint256) {
        return master.getUintVar(keccak256("slotProgress"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks the cost to dispute a mined value.
     */
    function disputeFee() external view returns (uint256) {
        return master.getUintVar(keccak256("disputeFee"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     */
    function disputeCount() external view returns (uint256) {
        return master.getUintVar(keccak256("disputeCount"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks stake amount required to become a miner.
     */
    function stakeAmount() external view returns (uint256) {
        return master.getUintVar(keccak256("stakeAmount"));
    }

    /**
     * @return Returns the getUintVar variable named after the function name.
     * This variable tracks the number of parties currently staked.
     */
    function stakerCount() external view returns (uint256) {
        return master.getUintVar(keccak256("stakerCount"));
    }
}
